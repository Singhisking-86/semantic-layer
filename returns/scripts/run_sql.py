"""Run every statement in a .sql file and save one CSV per statement.

Usage:
    python scripts/run_sql.py sql/open/P15_P17_next_batch.sql

Statements are split on ';'. Each statement may be preceded by a marker comment
`/* @name P15a_key_formats */` (or `-- @name ...`) which names the output CSV;
otherwise files are numbered. Results land in data/profiling_results/.
All statements pass through the read-only guard in scripts/td.py.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.td import connect, query  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "profiling_results"

NAME_RE = re.compile(r"@name\s+([A-Za-z0-9_\-]+)")


def split_statements(text: str) -> list[tuple[str, str]]:
    parts = [p.strip() for p in text.split(";")]
    out: list[tuple[str, str]] = []
    for i, p in enumerate(parts, 1):
        if not p or not re.search(r"\b(sel|select|help|show|with)\b", p, re.I):
            continue
        m = NAME_RE.search(p)
        out.append((m.group(1) if m else f"stmt_{i:02d}", p))
    return out


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: python scripts/run_sql.py <file.sql>")
    sql_file = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    conn = connect()
    try:
        for name, stmt in split_statements(sql_file.read_text()):
            print(f"-- running {name} ...", flush=True)
            try:
                df = query(stmt, conn)
                dest = OUT / f"{name}.csv"
                df.to_csv(dest, index=False)
                print(f"   {len(df):,} rows -> {dest.relative_to(ROOT)}")
            except Exception as exc:  # keep going; record the failure
                print(f"   FAILED: {exc}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
