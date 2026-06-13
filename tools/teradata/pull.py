"""Generic Teradata data-pull tool — self-contained, no project dependencies.

Run a SQL query (file or inline) against Teradata and preview it or save it to
CSV / Parquet. Usable as a CLI or imported (`from pull import run_query`).

Credentials live in a JSON file (default: ./credentials.json) whose keys are
passed straight to `teradatasql.connect()`:

    { "host": "...", "user": "...", "password": "...", "logmech": "TDNEGO",
      "database": "PRODVM", "tmode": "ANSI", "encryptdata": "true" }

Parameters: use `?` for positional binds, or `?1` / `?2` to reference a value by
1-based position (a number used N times is bound N times). Markers inside SQL
comments are ignored.

CLI examples:
    python pull.py --sql-text "SELECT TOP 50 * FROM prodvm.account_enquiry"
    python pull.py --sql query.sql --param 2026-06-02 --param 14 --out data/out.parquet
    python pull.py --sql q.sql --creds ../somewhere/credentials.json --out out.csv

Import example:
    from pull import run_query
    df = run_query("SELECT * FROM prodvm.account_enquiry WHERE date_of_enquiry = ?",
                   params=("2026-06-02",))
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import pandas as pd

DEFAULT_CREDS = Path(__file__).resolve().parent / 'credentials.json'


def load_creds(creds_path) -> dict:
    """Read the credentials JSON (host/user/password/logmech/…)."""
    p = Path(creds_path)
    if not p.exists():
        raise FileNotFoundError(
            f'Credentials file not found: {p}. Copy credentials.example.json to '
            f'credentials.json and fill in your Teradata details.')
    return json.loads(p.read_text())


def _strip_sql_comments(sql: str) -> str:
    """Remove /* … */ block and -- line comments so markers inside them are not
    counted or bound."""
    sql = re.sub(r'/\*.*?\*/', '', sql, flags=re.S)
    sql = re.sub(r'--[^\n]*', '', sql)
    return sql


def _expand_numbered_params(sql: str, params) -> tuple[str, list]:
    """Translate `?1`/`?2` numbered placeholders into plain `?`, expanding
    `params` positionally. Plain-`?` SQL is returned unchanged."""
    sql = _strip_sql_comments(sql)
    params = list(params)
    if not re.search(r'\?\d', sql):
        return sql, params
    expanded: list = []

    def _sub(m: re.Match) -> str:
        expanded.append(params[int(m.group(1)) - 1])
        return '?'

    return re.sub(r'\?(\d+)', _sub, sql), expanded


def run_query(sql: str, creds_path=DEFAULT_CREDS, params=None) -> pd.DataFrame:
    """Execute `sql` against Teradata and return a pandas DataFrame.

    Args:
        sql:        SQL text. `?` positional, or `?1`/`?2` numbered placeholders.
        creds_path: path to the credentials JSON (default: ./credentials.json).
        params:     iterable of values bound onto the placeholders.

    Returns:
        DataFrame, one row per result row; columns named from the cursor.
    """
    import teradatasql  # lazy import so --help works without the driver installed
    creds = load_creds(creds_path)
    con = teradatasql.connect(**creds)
    try:
        cur = con.cursor()
        if params:
            sql, binds = _expand_numbered_params(sql, params)
            cur.execute(sql, binds)
        else:
            cur.execute(sql)
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
    finally:
        con.close()
    return pd.DataFrame(rows, columns=cols)


def save(df: pd.DataFrame, out_path) -> Path:
    """Write `df` to `.csv` or `.parquet` (inferred from the extension)."""
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    suffix = out.suffix.lower()
    if suffix == '.parquet':
        df.to_parquet(out, index=False)
    elif suffix in ('.csv', ''):
        out = out.with_suffix('.csv')
        df.to_csv(out, index=False)
    else:
        raise ValueError(f'Unsupported output extension {suffix!r} — use .csv or .parquet')
    return out


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description='Run a SQL query against Teradata.')
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument('--sql', help='Path to a .sql file')
    src.add_argument('--sql-text', help='Inline SQL string')
    p.add_argument('--creds', default=str(DEFAULT_CREDS),
                   help='Path to credentials JSON (default: ./credentials.json)')
    p.add_argument('--param', action='append', default=None, dest='params',
                   help='Positional parameter, repeatable (bound left-to-right onto ?/?N)')
    p.add_argument('--out', default=None, help='Save result to a .csv or .parquet file')
    p.add_argument('--limit', type=int, default=20,
                   help='Rows to preview when not saving (default 20; 0 = all)')
    return p.parse_args()


def main() -> int:
    args = parse_args()
    sql = Path(args.sql).read_text() if args.sql else args.sql_text
    df = run_query(sql, creds_path=args.creds, params=args.params)
    print(f'returned {len(df):,} rows x {len(df.columns)} cols')
    if args.out:
        print(f'wrote -> {save(df, args.out)}')
    else:
        n = None if args.limit == 0 else args.limit
        with pd.option_context('display.max_columns', None, 'display.width', 200):
            print(df.head(n).to_string())
    return 0


if __name__ == '__main__':
    sys.exit(main())
