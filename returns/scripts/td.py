"""Teradata connection helper with project guardrails.

Usage:
    from scripts.td import query
    df = query("SEL TOP 5 * FROM PRODVM.ZZ_RETURN_REQUESTED WHERE DATETIMEREQUESTED GE DATE - 7")

Credentials come from .env (see .env.example). This module enforces the project's
READ-ONLY rule: any statement that is not SELECT/SEL/HELP/SHOW/EXPLAIN is refused.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import pandas as pd
import teradatasql

ROOT = Path(__file__).resolve().parents[1]

_ALLOWED = re.compile(r"^\s*(sel(ect)?|help|show|explain|with)\b", re.IGNORECASE)
_FORBIDDEN = re.compile(
    r"\b(insert|update|delete|merge|create|drop|alter|replace|grant|revoke|"
    r"collect\s+stats|call|exec)\b",
    re.IGNORECASE,
)


def _load_env() -> None:
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                os.environ.setdefault(k.strip(), v.strip())


def connect() -> teradatasql.TeradataConnection:
    _load_env()
    host = os.environ.get("TD_HOST", "teradata2690")
    user = os.environ.get("TD_USER")
    password = os.environ.get("TD_PASSWORD")
    logmech = os.environ.get("TD_LOGMECH", "TD2")  # often LDAP in corp setups
    if not user or not password:
        raise RuntimeError("Set TD_USER and TD_PASSWORD in .env (copy .env.example)")
    return teradatasql.connect(host=host, user=user, password=password, logmech=logmech)


def guard(sql: str) -> None:
    """Refuse anything that is not a read."""
    body = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    body = "\n".join(l for l in body.splitlines() if not l.strip().startswith("--"))
    if not _ALLOWED.match(body):
        raise PermissionError(f"Blocked (not a read statement): {body[:80]!r}")
    if _FORBIDDEN.search(body):
        raise PermissionError(f"Blocked (write/DDL keyword found): {body[:80]!r}")


def query(sql: str, conn: teradatasql.TeradataConnection | None = None) -> pd.DataFrame:
    guard(sql)
    own = conn is None
    conn = conn or connect()
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            cols = [d[0] for d in cur.description] if cur.description else []
            rows = cur.fetchall() if cur.description else []
        return pd.DataFrame(rows, columns=cols)
    finally:
        if own:
            conn.close()
