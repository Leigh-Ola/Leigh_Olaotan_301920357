"""Capture one benchmark phase through Docker/psql; Python 3 standard library only.
Run before adding the candidate index, then after, into different fresh output dirs.
No DDL/data mutations are performed. Preserve the original before evidence.
"""
import argparse,csv,datetime,hashlib,json,pathlib,re,statistics,subprocess
P='Leigh_Olaotan_301920357_P2_'
parser=argparse.ArgumentParser()
parser.add_argument('phase',choices=['before','after'])
parser.add_argument('--output-dir',type=pathlib.Path,required=True)
parser.add_argument('--docker',default='docker')
parser.add_argument('--container',default='mit8103-postgres')
parser.add_argument('--database',default='mit8103_benchmark')
parser.add_argument('--user',default='mit8103_admin')
a=parser.parse_args()
if a.database=='mit8103_portfolio': raise SystemExit('Use the separate benchmark database')
a.output_dir.mkdir(parents=True,exist_ok=True)
phase=a.phase.title()
paths={s:a.output_dir/(P+phase+s) for s in ['Plans.txt','Plans.json','Timings.csv','Metadata.json']}
if any(p.exists() for p in paths.values()): raise SystemExit('Refusing to overwrite saved phase evidence')
cmd=[a.docker,'exec','-i',a.container,'psql','-XAtq','-v','ON_ERROR_STOP=1','-U',a.user,'-d',a.database]
settings="SET TIME ZONE 'UTC'; SET max_parallel_workers_per_gather=0; SET jit=off; SET statement_timeout='60s';"
def sql(s):
    r=subprocess.run(cmd,input=settings+'\n'+s,text=True,capture_output=True,timeout=90)
    if r.returncode: raise RuntimeError(r.stderr)
    return r.stdout.strip()
def obj(s): return json.loads(sql(s))
source=pathlib.Path(__file__).with_name(P+'BenchmarkQueries.sql')
queries=dict(re.findall(r'-- QUERY (\w+)\n(.*?)-- END \w+',source.read_text(),re.S))
index='idx_sales_order_customer_history'
exists=sql("SELECT to_regclass('public."+index+"') IS NOT NULL;")=='t'
if exists!=(a.phase=='after'): raise SystemExit('Candidate index presence does not match phase')
counts=obj("SELECT json_build_object('customer',(SELECT count(*) FROM customer),'product',(SELECT count(*) FROM product),'sales_order',(SELECT count(*) FROM sales_order),'order_item',(SELECT count(*) FROM order_item),'payment',(SELECT count(*) FROM payment));")
assert counts==dict(customer=10000,product=100,sales_order=300000,order_item=600000,payment=120000),counts
metadata={'phase':a.phase,'executed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'database':a.database,'version':sql('SELECT version();'),'counts':counts,'query_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'warmups':1,'measured_runs':5,
'settings':obj("SELECT json_object_agg(name,setting) FROM pg_settings WHERE name IN ('shared_buffers','work_mem','effective_cache_size','random_page_cost','seq_page_cost','max_parallel_workers_per_gather','jit','server_version','block_size');"),
'indexes':obj("SELECT json_agg(t ORDER BY tablename,indexname) FROM (SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public') t;"),
'index_bytes':int(sql("SELECT coalesce(pg_relation_size(to_regclass('public."+index+"')),0);")),
'order_table_bytes':int(sql("SELECT pg_relation_size('public.sales_order');")), 'results':{}}
plans={}; rows=[]; text=[]
for name,query in queries.items():
    query=query.strip().rstrip(';')
    result=obj('SELECT coalesce(json_agg(t),\'[]\'::json) FROM ('+query+') t;')
    metadata['results'][name]={'rows':result,'sha256':hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest()}
    if name=='broad_status': assert result==[{'placed_orders':270000}],result
    else:
        # Derived from g=42+k*10000, minute g-1; newest ten within the date window.
        expected=list(range(260042,160042,-10000))
        assert [r['order_number'] for r in result]==['BO'+str(g) for g in expected],result
    plans[name]=[]
    for run in range(6):
        plan=obj('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+query+';')[0]
        plans[name].append({'run':run,'warmup':run==0,'explain':plan})
        if run:
            top=plan['Plan']; rows.append({'query':name,'run':run,'planning_ms':plan['Planning Time'],'execution_ms':plan['Execution Time'],'shared_hit_blocks':top.get('Shared Hit Blocks',0),'shared_read_blocks':top.get('Shared Read Blocks',0),'result_sha256':metadata['results'][name]['sha256']})
    text.append(name+' representative text plan (extra diagnostic execution, not a measured sample):\n'+sql('EXPLAIN (ANALYZE,BUFFERS) '+query+';'))
metadata['median_ms']={name:statistics.median(r['execution_ms'] for r in rows if r['query']==name) for name in queries}
paths['Plans.txt'].write_text('\n\n'.join(text)+'\n')
paths['Plans.json'].write_text(json.dumps(plans,indent=2)+'\n')
with paths['Timings.csv'].open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
paths['Metadata.json'].write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps({'phase':a.phase,'median_ms':metadata['median_ms'],'index_bytes':metadata['index_bytes'],'exact_results_checked':True},indent=2))
