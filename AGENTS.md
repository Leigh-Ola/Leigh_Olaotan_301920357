# Working rules

## Submission language

Use Simplified Technical English for all submission documentation. This includes READMEs, design explanations, discussions, summaries and figure captions. Use short active sentences and consistent technical names. Use at most 20 words in instructions and 25 words in descriptions. Preserve code identifiers, commands, source titles and captured database output. Do not change historical evidence to simplify its language.

Record AI assistance accurately. Do not invent the student's personal experience or claim that the student performed checks without their confirmation.

Keep internal roadmap numbers, progress checklists and instructions addressed to the student out of submission prose. Refer to the assessed portfolio or name the technical activity. Reproduction instructions must explain their prerequisites without relying on the internal plan. Keep planning status under ignored `temp/plans/`.

## Formatting is required

The user explicitly requires readable, consistently formatted files, including every future file created or updated. Run `npm run format` after edits, then `npm run format:check` before reporting completion or committing. Fix failures. These commands cover portfolio sources, repository tooling, and authored plans and helpers under `temp/`. Review the diff as well: a passing formatter does not make dense SQL strings or unclear prose readable by itself.

- Prettier handles Markdown, JavaScript (including MongoDB scripts), JSON, YAML, HTML and CSS. It fixes layout; ESLint is not needed for spacing.
- Keep each Markdown prose paragraph on one source line. Use Prettier's `proseWrap: "never"`; do not insert line breaks to meet a character limit. Preserve paragraph boundaries, headings, lists, tables and code blocks.
- Ruff formats Python and separates multiple imports onto their own lines.
- pgFormatter formats PostgreSQL and PL/pgSQL. Preserve psql commands and named QUERY/BLOCK delimiters used by the runners. Recheck execution when SQL changes.
- Keep historical terminal output, timings, plan JSON, source manifests and captured evidence byte-for-byte. Record a new verification when source hashes change; never rewrite an old measurement to look current.
- Do not format downloaded reference repositories, dependencies, credentials, database files, PDFs, images or generated SVG exports. Format their authored source instead. For a new unsupported format, choose its proper formatter or document why automatic formatting is inappropriate.

See [formatter setup](scripts/README.md) for pinned tools and commands.

## Workspace and publication

- Put plans in `temp/plans/*.md`; put other drafts, task helpers, logs and source downloads in structured subdirectories of ignored `temp/`.
- Keep assessed deliverables in `Leigh_Olaotan_301920357/`, using the required `Leigh_Olaotan_301920357_` filename prefix. Root configuration and `scripts/` are repository maintenance tools, not uploaded assessment documents.
- Never push unless the user explicitly authorizes that push. Previous push permission does not authorize subsequent pushes.
