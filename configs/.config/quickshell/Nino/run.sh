#!/usr/bin/env bash
#
# run.sh — the agent script.
#
# Every command Claude runs more than once lives here as a named function, so a
# permission prompt reads "./run.sh verify_shell 5" instead of a wall of pipes,
# and so the reasoning survives in a comment. Rules: docs/rulebook.md, R24.
#
#   ./run.sh                  list the functions
#   ./run.sh <function> [..]  run one
#
# Nothing privileged or destructive belongs in here — no sudo, no recursive
# delete, nothing that pushes or publishes. Those stay bare in the prompt where
# they are visible.

# Not -e: several functions below use grep as a test, and grep exits 1 when it
# finds nothing, which is a normal result here rather than a failure.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

DOCS=docs

#: verify_shell [seconds]   launch the shell briefly, report warnings and errors
# Quickshell reads the QML directly, so this is the whole build-and-test loop.
# It puts real overlay windows on the live Wayland session, hence the timeout —
# and the log goes to a file first because piping quickshell straight into grep
# swallows the output when the timeout fires (lore).
verify_shell() {
    local secs="${1:-5}" log=/tmp/nino.log
    timeout "$secs" quickshell -p shell.qml >"$log" 2>&1

    if grep -aiE "warn|error" "$log"; then
        echo "-- warnings or errors above; full log: $log" >&2
        return 1
    fi
    echo "clean log after ${secs}s (a clean log is not proof it looks right)"
}

#: check_tags               report tags used but not in a document's vocabulary
# The vocabularies are deliberately fixed (D13): free-form tags drift into
# synonyms and stop working as an index. So this only ever reports — adding a
# tag to a list stays a human act.
check_tags() {
    local doc vocab used unknown status=0

    for doc in "$DOCS"/rulebook.md "$DOCS"/architecture.md \
               "$DOCS"/decisions.md "$DOCS"/lore.md; do
        [ -f "$doc" ] || continue

        # The vocabulary is the backticked tags under the "## Tags" heading; the
        # body is everything after "## Index", so the vocabulary and the index
        # rows never count as usage.
        vocab=$(sed -n '/^## Tags/,/^## Index/p' "$doc" |
                grep -o '#[a-z][a-z0-9-]*' | sort -u)
        used=$(sed -n '/^## Index/,$p' "$doc" |
               grep -o '#[a-z][a-z0-9-]*' | sort -u)

        unknown=$(comm -13 <(echo "$vocab") <(echo "$used"))
        if [ -n "$unknown" ]; then
            echo "$doc: not in its vocabulary:"
            echo "$unknown" | sed 's/^/    /'
            status=1
        fi
    done

    [ "$status" -eq 0 ] && echo "all tags listed"
    return "$status"
}

#: check_index              report entries missing from a document's index, or vice versa
# The indexes exist for the author's navigation, so a stale one is worse than
# none. Entry headings carry their ID as "## D13 —" or "**R1 —"; index rows as
# "| D13 | ... |".
check_index() {
    local doc entries rows missing extra status=0

    for doc in "$DOCS"/rulebook.md "$DOCS"/architecture.md \
               "$DOCS"/decisions.md "$DOCS"/lore.md; do
        [ -f "$doc" ] || continue

        entries=$(grep -oE '^(#+ |\*\*)[ADLR][0-9]+ ' "$doc" |
                  grep -oE '[ADLR][0-9]+' | sort -u -V)
        rows=$(grep -oE '^\| *[ADLR][0-9]+ *\|' "$doc" |
               grep -oE '[ADLR][0-9]+' | sort -u -V)

        missing=$(comm -23 <(echo "$entries") <(echo "$rows") | tr '\n' ' ')
        extra=$(comm -13 <(echo "$entries") <(echo "$rows") | tr '\n' ' ')

        [ -n "${missing// /}" ] && { echo "$doc: not in the index: $missing"; status=1; }
        [ -n "${extra// /}" ]   && { echo "$doc: indexed but no entry: $extra"; status=1; }
    done

    [ "$status" -eq 0 ] && echo "indexes match"
    return "$status"
}

#: check_docs               check_tags + check_index
check_docs() {
    check_tags
    check_index
}

usage() {
    echo "usage: ./run.sh <function> [args...]"
    echo
    grep '^#: ' "${BASH_SOURCE[0]}" | sed 's/^#: /  /'
}

# Dispatch: first argument names a function, the rest are its arguments. Only
# functions documented with a "#:" line are callable, so an internal helper can
# never be invoked from the command line by accident.
main() {
    local fn="${1:-}"
    [ -z "$fn" ] && { usage; exit 0; }

    if ! grep -q "^#: $fn\b" "${BASH_SOURCE[0]}"; then
        echo "no such function: $fn" >&2
        echo >&2
        usage >&2
        exit 1
    fi

    shift
    "$fn" "$@"
}

main "$@"
