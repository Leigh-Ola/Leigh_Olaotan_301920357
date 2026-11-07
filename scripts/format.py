"""Format authored sources without rewriting raw evidence or downloaded material."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "temp/tools/formatting"
PRETTIER = ROOT / "node_modules/prettier/bin/prettier.cjs"
RUFF = TOOLS / "venv/bin/ruff"
PG_FORMAT = TOOLS / "pgFormatter-5.11/pg_format"
WEB_SUFFIXES = {".md", ".js", ".mjs", ".cjs", ".json", ".yaml", ".yml", ".html", ".css"}
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv"}
# psql commands must remain on separate lines. pgFormatter can merge or alter
# them, so pass only the SQL between commands to it. Inline \gset is valid too.
PSQL_COMMAND = re.compile(r"(?m)^[ \t]*\\[^\n]*|[ \t]+\\gset\b[^\n]*")


def authored_files():
    """Include ignored working notes deliberately; never traverse temp/runtime."""
    for directory, dirs, names in os.walk(ROOT):
        relative = Path(directory).relative_to(ROOT)
        dirs[:] = [
            d
            for d in dirs
            if d not in SKIP_DIRS and (not d.startswith(".") or d == ".github")
        ]
        if relative == Path("."):
            dirs[:] = [d for d in dirs if d != "temp"]
        for name in names:
            path = Path(directory) / name
            if not path.is_symlink():
                yield path

    for directory in (ROOT / "temp/plans", ROOT / "temp/work"):
        for parent, dirs, names in os.walk(directory):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for name in names:
                path = Path(parent) / name
                if not path.is_symlink():
                    yield path

    # Top-level review notes are ours; nested snapshots belong to their authors.
    yield from (ROOT / "temp/sources").glob("*.md")


def format_sql(source):
    command = [
        "perl",
        str(PG_FORMAT),
        "-X",
        "-L",
        "-k",
        "-s",
        "4",
        "-u",
        "0",
        "-U",
        "0",
        "--redundant-parenthesis",
    ]
    output = []
    position = 0
    for match in [*PSQL_COMMAND.finditer(source), None]:
        end = match.start() if match else len(source)
        sql = source[position:end].strip()
        if sql:
            result = subprocess.run(
                command, input=sql, text=True, capture_output=True, check=True
            )
            output.append(result.stdout.rstrip() + "\n")
        if match:
            output.append(match.group().strip() + "\n")
            position = match.end()
    return "".join(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    os.chdir(ROOT)
    for tool in (PRETTIER, RUFF, PG_FORMAT):
        if not tool.exists():
            parser.error(f"Missing {tool.relative_to(ROOT)}; see scripts/README.md")
    versions = [
        (["node", str(PRETTIER), "--version"], "3.9.10"),
        ([str(RUFF), "--version"], "ruff 0.17.4"),
        (["perl", str(PG_FORMAT), "--version"], "pg_format version 5.11"),
    ]
    for command, expected in versions:
        actual = subprocess.check_output(command, text=True).strip()
        if actual != expected:
            parser.error(f"Expected {expected}, found {actual}")

    files = sorted(set(authored_files()))
    web = [str(p.relative_to(ROOT)) for p in files if p.suffix in WEB_SUFFIXES]
    python = [str(p.relative_to(ROOT)) for p in files if p.suffix == ".py"]
    sql = [p for p in files if p.suffix == ".sql"]
    failed = False
    if web:
        result = subprocess.run(
            [
                "node",
                str(PRETTIER),
                "--ignore-path",
                ".prettierignore",
                "--write" if args.write else "--check",
                *web,
            ]
        )
        failed |= result.returncode != 0
    if python:
        for options in (
            ["check", "--fix"] if args.write else ["check"],
            ["format"] if args.write else ["format", "--check"],
        ):
            result = subprocess.run([str(RUFF), *options, *python])
            failed |= result.returncode != 0
    changed = 0
    for path in sql:
        source = path.read_text()
        formatted = format_sql(source)
        if source != formatted:
            changed += 1
            if args.write:
                path.write_text(formatted)
            else:
                print(f"Needs SQL formatting: {path.relative_to(ROOT)}")
                failed = True
    print(
        f"SQL: {len(sql)} files checked; {changed} {'formatted' if args.write else 'need formatting'}."
    )
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
