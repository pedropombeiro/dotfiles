#!/usr/bin/env python3
"""Search previous OpenCode sessions for a keyword or sentence.

Reads the local OpenCode SQLite database in read-only mode and prints matching
sessions as JSON or text, newest match first.
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
    query = (sys.stdin.read() if args.stdin else args.query or "").strip()
    if not query:
        sys.exit("search.py: query is empty")

    include = set(args.include.split(",")) if args.include else set()
    unknown = include - set(SOURCES)
    if unknown:
        sys.exit(f"search.py: unknown --include value(s): {', '.join(sorted(unknown))}")

    db = connect(args.db)
    session_table = find_session_table(db)
    sessions = load_sessions(db, session_table, args)

    searches = []
    results = []
    for words, sources in attempts(query, args.words, include, args.no_fallback):
        results = search(db, sessions, query, words, sources, args)
        searches.append(
            {"mode": "words" if words else "phrase", "include": sorted(sources), "total_sessions": len(results)}
        )
        if results:
            break

    output = {
        "query": query,
        "mode": searches[-1]["mode"],
        "include": searches[-1]["include"],
        "searches": searches,
        "total_sessions": len(results),
        "sessions": results[: args.limit],
    }
    if args.format == "text":
        print_text(output)
    else:
        json.dump(output, sys.stdout, ensure_ascii=False, indent=2)
        print()


def parse_args():
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("query", nargs="?", help="Keyword or sentence to find (case-insensitive literal match)")
    parser.add_argument("--stdin", action="store_true", help="Read the query from standard input")
    parser.add_argument("--words", action="store_true", help="Match sessions containing every word, in any message")
    parser.add_argument(
        "--include",
        help=f"Extra sources to search, comma-separated: {','.join(SOURCES)}. "
        "User messages, assistant replies, compaction summaries, and titles are always searched.",
    )
    parser.add_argument(
        "--no-fallback",
        action="store_true",
        help="Run only the requested search. By default, a search that finds nothing is retried "
        "with --words, then with tools included.",
    )
    parser.add_argument("--session", help="Only this session ID, for example to read more of its matches")
    parser.add_argument("--directory", help="Only sessions whose directory starts with this path")
    parser.add_argument(
        "--current-project",
        action="store_true",
        help="Only sessions of the current project: the project of $OPENCODE_SESSION_ID, "
        "or of the working directory when it is unset",
    )
    parser.add_argument("--since", type=parse_date, help="Only matches on or after this date (YYYY-MM-DD)")
    parser.add_argument("--until", type=parse_date, help="Only matches before this date (YYYY-MM-DD)")
    parser.add_argument("--limit", type=int, default=10, help="Maximum sessions to return (default: 10)")
    parser.add_argument("--excerpts", type=int, default=3, help="Maximum excerpts per session (default: 3)")
    parser.add_argument("--context", type=int, default=100, help="Characters of context around a match (default: 100)")
    parser.add_argument("--format", choices=("json", "text"), default="json", help="Output format (default: json)")
    parser.add_argument(
        "--include-current",
        action="store_true",
        help="Also search the session in $OPENCODE_SESSION_ID, which is excluded by default",
    )
    parser.add_argument("--db", default=os.path.join(data_home, "opencode", "opencode.db"), help="Database path")
    args = parser.parse_args()
    if args.stdin and args.query:
        parser.error("pass the query as an argument or with --stdin, not both")
    return args


def parse_date(value):
    try:
        day = datetime.datetime.strptime(value, "%Y-%m-%d").astimezone()
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid date {value!r}, expected YYYY-MM-DD")
    return int(day.timestamp() * 1000)


def attempts(query, words, include, no_fallback):
    """Yield the (words, sources) searches to try, in order, until one finds a session."""
    yield words, include
    if no_fallback:
        return
    multiword = len(query.split()) > 1
    if multiword and not words:
        yield True, include
    if "tools" not in include:
        yield words or multiword, include | {"tools"}


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
    project = "project_id" if "project_id" in columns else "NULL"
    query = (
        f"SELECT id, title, directory, parent_id, {project} AS project_id, time_created, time_updated, "
        f"{archived} AS time_archived FROM {table}"
    )
    conditions = []
    params = []
    if args.session:
        conditions.append("id = ?")
        params.append(args.session)
    if args.directory:
        conditions.append("(directory = ? OR directory LIKE ? ESCAPE '\\')")
        directory = args.directory.rstrip("/")
        params += [directory, like_escape(directory) + "/%"]
    if conditions:
        query += " WHERE " + " AND ".join(conditions)
    current_id = os.environ.get("OPENCODE_SESSION_ID")
    excluded = None if args.include_current or args.session else current_id
    if current_id:
        current = db.execute(f"SELECT {project} AS project_id, directory FROM {table} WHERE id = ?", [current_id]).fetchone()
    else:
        current = project_of_cwd(db) if project != "NULL" else None
    if args.current_project and (current is None or current["project_id"] is None):
        sys.exit("search.py: --current-project needs a database with project IDs")
    sessions = {}
    for row in db.execute(query, params):
        if row["id"] == excluded:
            continue
        same = same_project(row, current)
        if args.current_project and not same:
            continue
        sessions[row["id"]] = {
            "id": row["id"],
            "title": row["title"] or "",
            "directory": row["directory"],
            "parent_id": row["parent_id"],
            "project_id": row["project_id"],
            "same_project": same,
            "archived": row["time_archived"] is not None,
            "created": iso(row["time_created"]),
            "created_ms": row["time_created"],
            "updated": iso(row["time_updated"]),
        }
    # Restrict the message scan to these sessions only when a filter removed
    # some; otherwise the full scan is cheaper than an ID lookup per session.
    args.session_filter = bool(args.session or args.directory or args.current_project)
    return sessions


def project_of_cwd(db):
    """The project of the working directory, for runs without $OPENCODE_SESSION_ID.

    OpenCode command shell blocks run in the session's directory but don't
    export the session ID. The project is the one whose worktree or sandbox
    contains the directory; directories outside every project use "global".
    """
    cwd = os.path.realpath(os.getcwd())
    best = None
    try:
        rows = db.execute("SELECT id, worktree, sandboxes FROM project").fetchall()
    except sqlite3.Error:
        return None
    for row in rows:
        try:
            sandboxes = json.loads(row["sandboxes"] or "[]")
        except json.JSONDecodeError:
            sandboxes = []
        for path in [row["worktree"], *sandboxes]:
            if not isinstance(path, str) or path in ("", "/"):
                continue
            root = os.path.realpath(path)
            if (cwd == root or cwd.startswith(root + "/")) and (best is None or len(root) > len(best[1])):
                best = (row["id"], root)
    return {"project_id": best[0] if best else "global", "directory": cwd}


def same_project(row, current):
    """Whether a session shares the current session's project, or None when unknown."""
    if current is None or current["project_id"] is None or row["project_id"] is None:
        return None
    if row["project_id"] != current["project_id"]:
        return False
    # Every directory outside a repository shares the "global" project ID.
    if row["project_id"] != "global":
        return True
    return resolve(row["directory"]) == resolve(current["directory"])


def resolve(path):
    return os.path.realpath(path) if path else path


def search(db, sessions, query, words, include, args):
    terms = [t for t in (query.split() if words else [query]) if t]
    # Each hit is (time_ms, message_id, source, term, text, start, end). The
    # excerpt is built only for the hits that are printed.
    hits = {}
    for row in candidate_messages(db, sessions, terms, include, args):
        for source, text in extract(row["type"], row["data"], include):
            for term in terms:
                for match in re.finditer(re.escape(term), text, re.IGNORECASE):
                    hits.setdefault(row["session_id"], []).append(
                        (row["time_created"], row["id"], source, term, text, match.start(), match.end())
                    )

    for session_id, session in sessions.items():
        for term in terms:
            if contains(session["title"], term):
                hits.setdefault(session_id, []).append(
                    (session["created_ms"], None, "title", term, session["title"], None, None)
                )

    results = []
    for session_id, matches in hits.items():
        if {m[3] for m in matches} != set(terms):
            continue
        matches.sort(key=lambda m: m[0], reverse=True)
        session = sessions[session_id]
        results.append(
            {
                **{k: v for k, v in session.items() if not k.endswith("_ms")},
                "match_count": len(matches),
                "last_match": iso(matches[0][0]),
                "last_match_ms": matches[0][0],
                "matches": [render_match(m, words, args.context) for m in matches[: args.excerpts]],
            }
        )

    # Forked sessions share copied messages, so break ties on the session ID
    # to keep the order stable.
    results.sort(key=lambda r: (r["last_match_ms"], r["id"]), reverse=True)
    for result in results:
        del result["last_match_ms"]
    return results


def render_match(match, words, context):
    time_ms, message_id, source, term, text, start, end = match
    rendered = {
        "term": term,
        "time": iso(time_ms),
        "message_id": message_id,
        "source": source,
        "excerpt": text if start is None else excerpt(text, start, end, context),
    }
    if not words:
        del rendered["term"]
    return rendered


def candidate_messages(db, sessions, terms, include, args):
    # Prefilter on the raw JSON with the JSON-escaped term. LIKE folds case for
    # ASCII only, so non-ASCII case variants are not matched. It is much faster
    # than instr(lower(data)), which copies every row.
    types = ["user", "assistant", "compaction"]
    if "tools" in include:
        types += ["shell", "synthetic"]
    if "system" in include:
        types.append("system")
    if "tools" in include:
        data = "data"
    else:
        # Tool calls hold most of the stored text. Keep only the text and
        # reasoning parts of assistant messages, so Python decodes far less.
        parts = ["text"] + (["reasoning"] if "reasoning" in include else [])
        data = (
            "CASE WHEN type = 'assistant' THEN json_object('content', ("
            "SELECT json_group_array(json(j.value)) FROM json_each(data, '$.content') AS j "
            f"WHERE j.value ->> 'type' IN ({','.join('?' * len(parts))}))) ELSE data END"
        )
    params = [] if "tools" in include else list(parts)
    clauses = " OR ".join("data LIKE ? ESCAPE '\\'" for _ in terms)
    query = (
        f"SELECT id, session_id, type, time_created, {data} AS data FROM session_message "
        f"WHERE type IN ({','.join('?' * len(types))}) AND ({clauses})"
    )
    params += types
    params += ["%" + like_escape(json.dumps(t, ensure_ascii=False)[1:-1]) + "%" for t in terms]
    if args.session_filter:
        query += " AND session_id IN (SELECT value FROM json_each(?))"
        params.append(json.dumps(list(sessions)))
    if args.since:
        query += " AND time_created >= ?"
        params.append(args.since)
    if args.until:
        query += " AND time_created < ?"
        params.append(args.until)
    for row in db.execute(query, params):
        if row["session_id"] not in sessions:
            continue
        try:
            data = json.loads(row["data"])
        except (json.JSONDecodeError, TypeError):
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


def excerpt(text, start, end, context):
    first = max(0, start - context)
    last = min(len(text), end + context)
    snippet = " ".join(text[first:last].split())
    return ("…" if first > 0 else "") + snippet + ("…" if last < len(text) else "")


def print_text(output):
    tried = " → ".join(f"{s['mode']}{' +' + ','.join(s['include']) if s['include'] else ''}" for s in output["searches"])
    shown = len(output["sessions"])
    print(f"Query: {json.dumps(output['query'], ensure_ascii=False)}")
    print(f"Searches: {tried}")
    print(f"Sessions: {output['total_sessions']} found, {shown} shown")
    for index, session in enumerate(output["sessions"], 1):
        same = {True: "yes", False: "no", None: "unknown"}[session["same_project"]]
        flags = " (archived)" if session["archived"] else ""
        flags += " (subagent)" if session["parent_id"] else ""
        print()
        print(f"{index}. {session['title'] or '(untitled)'}{flags}")
        print(
            f"   id: {session['id']} | same project: {same} | last match: {session['last_match']}"
            f" | matches: {session['match_count']}"
        )
        print(f"   directory: {session['directory']}")
        for match in session["matches"]:
            term = f" [{match['term']}]" if "term" in match else ""
            print(f"   - {match['source']}{term} {match['time']}: {match['excerpt']}")


def contains(text, term):
    return term.casefold() in text.casefold()


def like_escape(value):
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def iso(ms):
    if ms is None:
        return None
    return datetime.datetime.fromtimestamp(ms / 1000).astimezone().isoformat(timespec="seconds")


if __name__ == "__main__":
    main()
