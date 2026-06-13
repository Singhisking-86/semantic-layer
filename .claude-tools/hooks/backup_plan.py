#!/usr/bin/env python3
"""Plan-backup hook.

Registered as a PostToolUse hook on the ExitPlanMode tool. Every time a plan is
approved (i.e. you exit plan mode), Claude Code runs this script and pipes the
hook payload as JSON on stdin. We persist the plan to a durable, timestamped
markdown file under this workspace so an interrupted task can always be recovered
later — the plan is never lost just because a run got killed mid-way.

Backups live under  anil/.claude-tools/plan-backups/  (workspace-local, persists).
An INDEX.md is maintained as a one-line-per-plan table of contents.

The hook is intentionally defensive: any error is swallowed and it always exits 0
so it can never block plan approval.
"""
from __future__ import annotations

import datetime as _dt
import json
import pathlib
import re
import sys

BACKUP_DIR = pathlib.Path(__file__).resolve().parent.parent / "plan-backups"
INDEX = BACKUP_DIR / "INDEX.md"


def _slug(text: str, n: int = 6) -> str:
    """First line of the plan -> short kebab slug for the filename."""
    first = next((ln.strip() for ln in text.splitlines() if ln.strip()), "plan")
    first = re.sub(r"^#+\s*", "", first)                 # drop leading markdown heading marks
    words = re.sub(r"[^a-z0-9\s-]", "", first.lower()).split()
    return "-".join(words[:n]) or "plan"


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return  # nothing usable on stdin; never block

    tool_input = payload.get("tool_input", {}) or {}
    plan = tool_input.get("plan") or ""
    if not plan.strip():
        return

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    now = _dt.datetime.now()
    ts = now.strftime("%Y%m%d-%H%M%S")
    session = str(payload.get("session_id", "unknown"))[:8]
    cwd = payload.get("cwd", "")
    slug = _slug(plan)
    fname = f"{ts}_{slug}.md"
    fpath = BACKUP_DIR / fname

    frontmatter = (
        f"<!-- plan backup — auto-saved by backup_plan.py hook on ExitPlanMode -->\n"
        f"<!-- saved: {now.isoformat(timespec='seconds')} | session: {session} | cwd: {cwd} -->\n\n"
    )
    fpath.write_text(frontmatter + plan, encoding="utf-8")

    # Maintain a human-readable index (newest first).
    title = _slug(plan, n=12).replace("-", " ")
    line = f"- {now.strftime('%Y-%m-%d %H:%M')} · [{title}]({fname}) · session `{session}` · `{cwd}`\n"
    if not INDEX.exists():
        INDEX.write_text("# Plan backups (auto-saved on plan approval)\n\n", encoding="utf-8")
    body = INDEX.read_text(encoding="utf-8")
    head, _, rest = body.partition("\n\n")
    INDEX.write_text(head + "\n\n" + line + rest, encoding="utf-8")

    # Surface a confirmation in the transcript (PostToolUse stdout is shown in verbose/debug).
    print(f"[plan-backup] saved {fpath}")


if __name__ == "__main__":
    main()
