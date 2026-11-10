"""Run the saved A/B blocks on persistent independent psql sessions.
A third administrative observer reads actual blocking PIDs and final invariants.
No fixed sleep is used to decide when to release a lock: poll observed blocking.
Python 3 standard library; Docker/psql required.
Use a fresh database after running the P1 schema/seed and P3 workflows/transactions.
The P3 README gives the full setup sequence and required starting state.
"""

import argparse
import datetime
import json
import pathlib
import queue
import re
import subprocess
import threading
import time
import uuid
import hashlib

P = "Leigh_Olaotan_301920357_P3_"
arg = argparse.ArgumentParser()
arg.add_argument("--docker", default="docker")
arg.add_argument("--container", default="mit8103-postgres")
arg.add_argument("--database", default="mit8103_transactions")
arg.add_argument("--user", default="mit8103_admin")
arg.add_argument("--output", type=pathlib.Path, required=True)
a = arg.parse_args()
if a.database in ("mit8103_portfolio", "mit8103_benchmark"):
    raise SystemExit("Use a separate transaction database")
a.output.parent.mkdir(parents=True, exist_ok=True)
# Exclusive creation prevents accidental replacement of historical evidence.
logfile = a.output.open("x")


def log(s):
    logfile.write(
        datetime.datetime.now(datetime.timezone.utc).isoformat() + " " + s + "\n"
    )
    logfile.flush()


base = [
    a.docker,
    "exec",
    "-i",
    a.container,
    "psql",
    "-XAtq",
    "-P",
    "pager=off",
    "-v",
    "ON_ERROR_STOP=0",
    "-v",
    "VERBOSITY=verbose",
    "-U",
    a.user,
    "-d",
    a.database,
]


class Session:
    def __init__(self, name):
        self.name = name
        self.pending = None
        self.lines = queue.Queue()
        self.proc = subprocess.Popen(
            base,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        def pump():
            for line in self.proc.stdout:
                self.lines.put(line.rstrip("\n"))
            self.lines.put(None)

        threading.Thread(target=pump, daemon=True).start()
        self.query(
            (
                "SET TIME ZONE 'UTC'; SET statement_timeout='20s'; SET "
                "lock_timeout='15s'; SET application_name='mit8103_p3_"
            )
            + name
            + "';"
        )
        self.pid = int(self.query("SELECT pg_backend_pid();").strip())
        log(f"[{name}] backend_pid={self.pid}")

    def send(self, sql):
        if self.pending:
            raise RuntimeError("Session already has a pending command")
        self.pending = uuid.uuid4().hex
        log(f"[{self.name}] SQL:\n{sql}")
        self.proc.stdin.write(
            sql
            + "\n\\echo __STATE_"
            + self.pending
            + " :SQLSTATE\n\\echo __DONE_"
            + self.pending
            + "\n"
        )
        self.proc.stdin.flush()

    def collect(self, expected="00000", timeout=25):
        token = self.pending
        out = []
        state = None
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(self.name + " did not finish")
            line = self.lines.get(timeout=remaining)
            if line is None:
                raise RuntimeError(self.name + " connection exited: " + "\n".join(out))
            if line == "__DONE_" + token:
                break
            if line.startswith("__STATE_" + token + " "):
                state = line.split(" ", 1)[1]
            else:
                out.append(line)
        self.pending = None
        value = "\n".join(out)
        log(f"[{self.name}] OUTPUT:\n{value}\nSQLSTATE={state}")
        if state != expected:
            raise AssertionError((self.name, expected, state, value))
        if expected == "00000" and any(
            re.match(r"ERROR:|FATAL:", line) for line in out
        ):
            raise AssertionError(value)
        return value

    def query(self, sql, expected="00000"):
        self.send(sql)
        return self.collect(expected)

    def obj(self, sql):
        return json.loads(self.query(sql))

    def close(self):
        if self.proc.poll() is None:
            # Session termination always rolls back an unfinished transaction.
            try:
                self.proc.stdin.write("\nROLLBACK;\n\\q\n")
                self.proc.stdin.flush()
                self.proc.wait(timeout=3)
            except (BrokenPipeError, subprocess.TimeoutExpired):
                self.proc.terminate()
                try:
                    self.proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.proc.kill()
        log(f"[{self.name}] client closed")


files = [
    pathlib.Path(__file__).with_name(P + "Session" + letter + ".sql")
    for letter in ["A", "B"]
]
blocks = {}
for file in files:
    log(
        "SOURCE "
        + file.name
        + " SHA256 "
        + hashlib.sha256(file.read_bytes()).hexdigest()
    )
    blocks.update(
        dict(re.findall(r"-- BLOCK (\w+)\n(.*?)-- END \w+", file.read_text(), re.S))
    )
sessions = []
try:
    for name in ["a", "b", "observer"]:
        sessions.append(Session(name))
    A, B, O = sessions
    assert len({s.pid for s in sessions}) == 3
    log("DATABASE " + a.database + " VERSION " + O.query("SELECT version();"))
    initial = O.obj(
        (
            "SELECT json_build_object('marker',(SELECT stock_quantity FROM "
            "public.product WHERE sku='MRK01'),'pen',(SELECT stock_quantity "
            "FROM public.product WHERE sku='PEN01'),'folder',(SELECT "
            "stock_quantity FROM public.product WHERE sku='FLD01'),'cc_orders',"
            "(SELECT count(*) FROM public.sales_order WHERE order_number LIKE "
            "'CC-%'),'tx_orders',(SELECT count(*) FROM public.sales_order "
            "WHERE order_number IN ('TX-COMMIT','TX-CANCEL')));"
        )
    )
    assert initial == dict(marker=1, pen=18, folder=30, cc_orders=0, tx_orders=2), (
        initial
    )

    def run(session, name, expected="00000"):
        return session.query(blocks[name], expected)

    def wait_blocked():
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            row = O.obj(
                f"SELECT json_build_object('pid',pid,'application_name',application_name,'wait_event_type',wait_event_type,'wait_event',wait_event,'blockers',pg_blocking_pids(pid)) FROM pg_stat_activity WHERE pid={B.pid};"
            )
            if row and row["wait_event_type"] == "Lock" and A.pid in row["blockers"]:
                log("PASS: observed B waiting on a lock held by A: " + json.dumps(row))
                return
            time.sleep(0.05)
        raise AssertionError("Did not observe actual B-to-A blocking")

    log("SCENARIO 1: last available marker")
    run(A, "STOCK_A_BEGIN")
    visible = json.loads(run(B, "STOCK_B_BEGIN"))
    assert visible == dict(isolation="read committed", stock=1, visible_a_orders=0), (
        visible
    )
    B.send(blocks["STOCK_B_ATTEMPT"])
    wait_blocked()
    run(A, "STOCK_A_COMMIT")
    B.collect("P3002")
    run(B, "B_ROLLBACK")
    result = O.obj(
        (
            "SELECT json_build_object('stock',(SELECT stock_quantity FROM "
            "public.product WHERE sku='MRK01'),'a_orders',(SELECT count(*) "
            "FROM public.sales_order WHERE order_number='CC-STOCK-A'),"
            "'b_orders',(SELECT count(*) FROM public.sales_order WHERE "
            "order_number='CC-STOCK-B'),'reserved_units',(SELECT "
            "coalesce(sum(i.quantity),0) FROM public.order_item i JOIN "
            "public.sales_order o USING(order_id) WHERE o.order_number IN "
            "('CC-STOCK-A','CC-STOCK-B')));"
        )
    )
    assert result == dict(stock=0, a_orders=1, b_orders=0, reserved_units=1), result
    log("PASS: one last unit reserved by A; B left no header, line or stock deduction.")
    log("SCENARIO 2: payment obtains the order lock before cancellation")
    run(A, "PAY_PREPARE")
    run(A, "PAY_A_BEGIN")
    run(B, "PAY_B_BEGIN")
    B.send(blocks["PAY_B_ATTEMPT"])
    wait_blocked()
    run(A, "PAY_A_COMMIT")
    B.collect("P3005")
    run(B, "B_ROLLBACK")
    result = O.obj(
        (
            "SELECT json_build_object('status',o.order_status,'payments',"
            "(SELECT count(*) FROM public.payment p WHERE "
            "p.order_id=o.order_id),'folder_stock',(SELECT stock_quantity FROM "
            "public.product WHERE sku='FLD01')) FROM public.sales_order o "
            "WHERE order_number='CC-PAY-FIRST';"
        )
    )
    assert result == dict(status="placed", payments=1, folder_stock=29), result
    log("PASS: payment wins; cancellation rejected without restoring reserved stock.")
    log("SCENARIO 3: cancellation obtains the same order lock before payment")
    run(A, "CANCEL_PREPARE")
    run(A, "CANCEL_A_BEGIN")
    run(B, "CANCEL_B_BEGIN")
    B.send(blocks["CANCEL_B_ATTEMPT"])
    wait_blocked()
    run(A, "CANCEL_A_COMMIT")
    B.collect("P3004")
    run(B, "B_ROLLBACK")
    result = O.obj(
        (
            "SELECT json_build_object('status',o.order_status,'payments',"
            "(SELECT count(*) FROM public.payment p WHERE "
            "p.order_id=o.order_id),'folder_stock',(SELECT stock_quantity FROM "
            "public.product WHERE sku='FLD01')) FROM public.sales_order o "
            "WHERE order_number='CC-CANCEL-FIRST';"
        )
    )
    assert result == dict(status="cancelled", payments=0, folder_stock=29), result
    log("PASS: cancellation wins; payment rejected and stock restored once.")
    log(
        (
            "SCENARIO 4: READ COMMITTED hides uncommitted writes but allows a "
            "later statement to see a commit"
        )
    )
    run(B, "VIS_B_BEGIN")
    before = json.loads(run(B, "VIS_B_READ"))
    run(A, "VIS_A_BEGIN")
    during = json.loads(run(B, "VIS_B_READ"))
    run(A, "VIS_A_COMMIT")
    after = json.loads(run(B, "VIS_B_READ"))
    run(B, "VIS_B_COMMIT")
    assert (
        before["transaction_id"] == during["transaction_id"] == after["transaction_id"]
    )
    assert (
        before["stock"] == during["stock"] == 18
        and before["visible_a_orders"] == during["visible_a_orders"] == 0
    )
    assert after["stock"] == 17 and after["visible_a_orders"] == 1
    assert all(x["isolation"] == "read committed" for x in [before, during, after])
    log(
        (
            "PASS: same B transaction/PID reads 18 before commit and 17 after; "
            "no dirty read, nonrepeatable read observed."
        )
    )
    final = O.obj("""SELECT json_build_object(
     'orders',(SELECT count(*) FROM public.sales_order),
     'lines',(SELECT count(*) FROM public.order_item),
     'payments',(SELECT count(*) FROM public.payment),
     'invalid_payments',(SELECT count(*) FROM public.payment p JOIN public.sales_order o USING(order_id)
        WHERE o.order_status<>'placed' OR p.paid_at<o.ordered_at OR p.amount<>(SELECT sum(quantity*unit_price_at_order) FROM public.order_item WHERE order_id=o.order_id)),
     'empty_orders',(SELECT count(*) FROM public.sales_order o WHERE NOT EXISTS(SELECT 1 FROM public.order_item i WHERE i.order_id=o.order_id)),
     'stock_mismatches',(SELECT count(*) FROM (VALUES('PEN01',23),('PAP01',12),('NTB01',17),('STP01',6),('ENV01',2),('MRK01',2),('CAL01',4),('FLD01',30)) opening(sku,qty)
        JOIN public.product p USING(sku) WHERE p.stock_quantity<>opening.qty-coalesce((SELECT sum(i.quantity) FROM public.order_item i JOIN public.sales_order o USING(order_id) WHERE i.product_id=p.product_id AND o.order_status='placed'),0)));
    """)
    assert final == dict(
        orders=14,
        lines=20,
        payments=6,
        invalid_payments=0,
        empty_orders=0,
        stock_mismatches=0,
    ), final
    idle = O.obj(
        f"SELECT json_agg(json_build_object('pid',pid,'state',state,'transaction_open',xact_start IS NOT NULL) ORDER BY pid) FROM pg_stat_activity WHERE pid IN ({A.pid},{B.pid});"
    )
    assert all(x["state"] == "idle" and not x["transaction_open"] for x in idle), idle
    log(
        (
            "PASS: four scenarios; three observed lock waits; payment, line "
            "and stock invariants hold; no worker transaction left open."
        )
    )
except BaseException as e:
    log("FAILED: " + repr(e))
    raise
finally:
    # Closing A first also releases any lock B may be awaiting on a failed run.
    for s in sessions:
        s.close()
    logfile.close()
print("PASS: concurrency/isolation evidence saved to " + str(a.output))
