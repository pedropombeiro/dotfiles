#!/usr/bin/env python3
"""Search previous OpenCode sessions for a keyword or sentence.

Reads the local OpenCode SQLite database in read-only mode and prints matching
sessions as JSON, newest match first.
"""

import argparse
import datetime
import json
import os
import re
import sqlite3
import sys

SOURCES = ("tools", "reasoning", "system")


def main():
    args = parse_args()
    db = connect(args.db)
    session_table = find_session_table(db)
    terms = [args.query] if not args.words else args.query.split()
    terms = [t for t in terms if t]
    if not terms:
        sys.exit("search.py: query is empty")

    include = set(args.include.split(",")) if args.include else set()
    unknown = include - set(SOURCES)
    if unknown:
        sys.exit(f"search.py: unknown --include value(s): {', '.join(sorted(unknown))}")

    sessions = load_sessions(db, session_table, args)
    hits = {}
    for row in candidate_messages(db, terms, args):
        session = sessions.get(row["session_id"])
        if session is None:
            continue
        for source, text in extract(row["type"], row["data"], include):
            for term in terms:
                for excerpt in excerpts(text, term, args.context):
                    hits.setdefault(row["session_id"], []).append(
                        {
                            "term": term,
                            "time": iso(row["time_created"]),
                            "time_ms": row["time_created"],
                            "message_id": row["id"],
                            "source": source,
                            "excerpt": excerpt,
                        }
                    )

    for session_id, session in sessions.items():
        for term in terms:
            if contains(session["title"], term):
                hits.setdefault(session_id, []).append(
                    {
                        "term": term,
                        "time": session["created"],
                        "time_ms": session["created_ms"],
                        "message_id": None,
                        "source": "title",
                        "excerpt": session["title"],
                    }
                )

    results = []
    for session_id, matches in hits.items():
        if {m["term"] for m in matches} != set(terms):
            continue
        matches.sort(key=lambda m: m["time_ms"], reverse=True)
        session = sessions[session_id]
        results.append(
            {
                **{k: v for k, v in session.items() if not k.endswith("_ms")},
                "match_count": len(matches),
                "last_match": matches[0]["time"],
                "last_match_ms": matches[0]["time_ms"],
                "matches": [
                    {k: v for k, v in m.items() if k != "time_ms" and (k != "term" or args.words)}
                    for m in matches[: args.excerpts]
                ],
            }
        )

    results.sort(key=lambda r: r["last_match_ms"], reverse=True)
    for result in results:
        del result["last_match_ms"]
    json.dump(
        {
            "query": args.query,
            "mode": "words" if args.words else "phrase",
            "total_sessions": len(results),
            "sessions": results[: args.limit],
        },
        sys.stdout,
        ensure_ascii=False,
        indent=2,
    )
    print()


def parse_args():
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("query", help="Keyword or sentence to find (case-insensitive literal match)")
    parser.add_argument("--words", action="store_true", help="Match sessions containing every word, in any message")
    parser.add_argument(
        "--include",
        help=f"Extra sources to search, comma-separated: {','.join(SOURCES)}. "
        "User messages, assistant replies, compaction summaries, and titles are always searched.",
    )
    parser.add_argument("--directory", help="Only sessions whose directory starts with this path")
    parser.add_argument("--since", type=parse_date, help="Only matches on or after this date (YYYY-MM-DD)")
    parser.add_argument("--until", type=parse_date, help="Only matches before this date (YYYY-MM-DD)")
    parser.add_argument("--limit", type=int, default=10, help="Maximum sessions to return (default: 10)")
    parser.add_argument("--excerpts", type=int, default=3, help="Maximum excerpts per session (default: 3)")
    parser.add_argument("--context", type=int, default=100, help="Characters of context around a match (default: 100)")
    parser.add_argument(
        "--include-current",
        action="store_true",
        help="Also search the session in $OPENCODE_SESSION_ID, which is excluded by default",
    )
    parser.add_argument("--db", default=os.path.join(data_home, "opencode", "opencode.db"), help="Database path")
    return parser.parse_args()


def parse_date(value):
    try:
        day = datetime.datetime.strptime(value, "%Y-%m-%d").astimezone()
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid date {value!r}, expected YYYY-MM-DD")
    return int(day.timestamp() * 1000)


def connect(path):
    if not os.path.exists(path):
        sys.exit(f"search.py: database not found: {path}")
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA query_only = 1")
    return db


def find_session_table(db):
    tables = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    if "session_message" not in tables:
        sys.exit("search.py: unsupported database schema: no session_message table")
    # OpenCode 2.x keeps V2 sessions in session_v2; older builds use session.
    for name in ("session_v2", "session"):
        if name in tables:
            return name
    sys.exit("search.py: unsupported database schema: no session table")


def load_sessions(db, table, args):
    columns = {r[1] for r in db.execute(f"PRAGMA table_info({table})")}
    archived = "time_archived" if "time_archived" in columns else "NULL"
    query = f"SELECT id, title, directory, parent_id, time_created, time_updated, {archived} AS time_archived FROM {table}"
    params = []
    if args.directory:
        query += " WHERE directory = ? OR directory LIKE ? ESCAPE '\\'"
        directory = args.directory.rstrip("/")
        params = [directory, like_escape(directory) + "/%"]
    current = None if args.include_current else os.environ.get("OPENCODE_SESSION_ID")
    sessions = {}
    for row in db.execute(query, params):
        if row["id"] == current:
            continue
        sessions[row["id"]] = {
            "id": row["id"],
            "title": row["title"] or "",
            "directory": row["directory"],
            "parent_id": row["parent_id"],
            "archived": row["time_archived"] is not None,
            "created": iso(row["time_created"]),
            "created_ms": row["time_created"],
            "updated": iso(row["time_updated"]),
        }
    return sessions


def candidate_messages(db, terms, args):
    # Prefilter on the raw JSON with the JSON-escaped term. SQLite lower() folds
    # ASCII only, so non-ASCII case variants are not matched.
    clauses = " OR ".join("instr(lower(data), ?) > 0" for _ in terms)
    params = [ascii_lower(json.dumps(t, ensure_ascii=False)[1:-1]) for t in terms]
    query = f"SELECT id, session_id, type, time_created, data FROM session_message WHERE ({clauses})"
    if args.since:
        query += " AND time_created >= ?"
        params.append(args.since)
    if args.until:
        query += " AND time_created < ?"
        params.append(args.until)
    for row in db.execute(query, params):
        try:
            data = json.loads(row["data"])
        except json.JSONDecodeError:
            continue
        yield {**dict(row), "data": data}


def extract(kind, data, include):
    """Yield (source, text) pairs for the searchable parts of a message."""
    if kind == "user":
        yield "user", data.get("text") or ""
    elif kind == "assistant":
        for part in data.get("content") or []:
            ptype = part.get("type")
            if ptype == "text":
                yield "assistant", part.get("text") or ""
            elif ptype == "reasoning" and "reasoning" in include:
                yield "reasoning", part.get("text") or ""
            elif ptype == "tool" and "tools" in include:
                source = f"tool:{part.get('name')}"
                state = part.get("state") or {}
                if state.get("input") is not None:
                    yield source + ":input", json.dumps(state["input"], ensure_ascii=False)
                for content in state.get("content") or []:
                    if content.get("type") == "text":
                        yield source + ":output", content.get("text") or ""
                error = state.get("error")
                if isinstance(error, dict):
                    yield source + ":error", error.get("message") or ""
                elif isinstance(error, str):
                    yield source + ":error", error
    elif kind == "compaction":
        yield "compaction", data.get("summary") or ""
    elif kind == "shell" and "tools" in include:
        yield "shell:command", data.get("command") or ""
        yield "shell:output", (data.get("output") or {}).get("output") or ""
    elif kind == "synthetic" and "tools" in include:
        yield "synthetic", data.get("text") or ""
    elif kind == "system" and "system" in include:
        yield "system", data.get("text") or ""


def excerpts(text, term, context):
    for match in re.finditer(re.escape(term), text, re.IGNORECASE):
        start = max(0, match.start() - context)
        end = min(len(text), match.end() + context)
        snippet = " ".join(text[start:end].split())
        yield ("…" if start > 0 else "") + snippet + ("…" if end < len(text) else "")


def contains(text, term):
    return term.casefold() in text.casefold()


def ascii_lower(value):
    return "".join(c.lower() if c.isascii() else c for c in value)


def like_escape(value):
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def iso(ms):
    if ms is None:
        return None
    return datetime.datetime.fromtimestamp(ms / 1000).astimezone().isoformat(timespec="seconds")


if __name__ == "__main__":
    main()
