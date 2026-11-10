# Repository formatting

Run these commands from the repository root after creating or updating files:

```sh
npm run format
npm run format:check
```

The runner includes assessed source files, repository tooling, authored `temp/plans/` and `temp/work/` files, and top-level source review notes. Prettier's ignore file protects evidence and downloaded metadata. SQL psql commands are preserved while pgFormatter processes the SQL between them. Review SQL diffs and rerun relevant database checks; formatting is not a correctness test.

## Install pinned tools once

Requires Node/npm, Python 3.9 or newer, Perl, curl and tar. Dependencies stay in ignored directories. These are formatting dependencies only; the submitted Python database runners still use the standard library.

```sh
npm ci --ignore-scripts
mkdir -p temp/tools/formatting
python3 -m venv temp/tools/formatting/venv
temp/tools/formatting/venv/bin/python -m pip install ruff==0.17.4
curl -fL https://codeload.github.com/darold/pgFormatter/tar.gz/refs/tags/v5.11 \
  -o temp/tools/formatting/pgFormatter-5.11.tar.gz
```

Before extracting, check the downloaded archive:

```sh
shasum -a 256 temp/tools/formatting/pgFormatter-5.11.tar.gz
```

Expected SHA256: `563619e13294b3db55d7a98a761786024ea3609d007fa94654a69a7346b8fd67`. Extract only if it matches:

```sh
tar -xzf temp/tools/formatting/pgFormatter-5.11.tar.gz -C temp/tools/formatting
npm run format:check
```

Versions: Prettier 3.9.10, Ruff 0.17.4, pgFormatter 5.11. The runner refuses other versions to avoid accidental style churn. It does not stage, commit or push.

## Scope

Prettier formats documents, JavaScript and supported configuration files. Ruff formats Python and splits combined imports. pgFormatter handles SQL/PLpgSQL. EditorConfig supplies consistent whitespace defaults for other text files.

Markdown uses `proseWrap: "never"`. Each prose paragraph stays on one source line, including paragraphs within list items. Editors can use visual word wrap. Keep separate paragraphs, headings, list items, table rows and code lines separate.

Raw `.txt` output, `.csv` measurements, benchmark plan/metadata JSON, dependency lockfiles, generated SVGs and downloaded source material retain their original bytes. They are evidence or generated artifacts, not hand-maintained source. Keep runtime files and credentials under ignored `temp/runtime/`.

Official references: [Prettier configuration](https://prettier.io/docs/configuration), [Ruff formatter](https://docs.astral.sh/ruff/formatter/), [pgFormatter](https://github.com/darold/pgFormatter/tree/v5.11).
