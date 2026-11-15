#!/bin/sh
#
# File access helper for the widget's Import / Export page.
#
# QML has no portable file-writing API, so the page runs this script through the
# Plasma5Support "executable" data engine. Arguments arrive as separate argv
# entries (the QML side quotes them), which keeps paths with spaces and quotes safe.
#
#   backup-io.sh read <path>
#   backup-io.sh write <path> <base64> [<base64> ...]
#   backup-io.sh write-start <path>          (prints the temporary file path)
#   backup-io.sh write-chunk <temp> <base64> [<base64> ...]
#   backup-io.sh write-end <temp> <path>
#   backup-io.sh write-abort <temp>
#
# "read" writes the file to stdout, capped at MAX_READ bytes. "write" is the
# single-shot form; "write-start"/"write-chunk"/"write-end" let the QML side send a
# large backup in chunks, so the base64 payload is never one huge argv entry (the
# kernel rejects an argument above ~128 KiB). The chunks go into a private mktemp
# directory next to the target, and "write-end" renames the file into place, so a
# failed export does not truncate an existing backup. Every operation exits non-zero
# on failure so the QML side can show an error instead of silently claiming success.

set -eu

MAX_READ=8388608

# Prints the path of a fresh empty file inside a private directory next to <path>.
# mktemp -d creates the directory with mode 0700, so another user cannot replace the
# file between chunks even when the target directory is shared.
new_temp() {
    dir=$(mktemp -d -- "$1.tmp.XXXXXX") || return 1
    tmp="$dir/data"
    (umask 077; : > "$tmp") || { rmdir -- "$dir"; return 1; }
    printf '%s' "$tmp"
}

# Removes the file and its private directory; harmless if either is already gone.
remove_temp() {
    [ -n "${1:-}" ] || return 0
    rm -f -- "$1" 2>/dev/null || true
    rmdir -- "$(dirname -- "$1")" 2>/dev/null || true
}

operation=$1
case "$operation" in
    read)
        path=$2
        # The size of a regular file is known up front; for anything else (a FIFO,
        # /dev/zero) head's byte limit is the bound. Either way the widget never
        # buffers an unbounded file.
        if [ -f "$path" ]; then
            size=$(wc -c < "$path" 2>/dev/null | tr -d '[:space:]')
            if [ -n "$size" ] && [ "$size" -gt "$MAX_READ" ] 2>/dev/null; then
                echo "file is too large (limit $MAX_READ bytes)" >&2
                exit 3
            fi
        fi
        head -c "$MAX_READ" -- "$path"
        ;;
    write)
        path=$2
        shift 2
        tmp=$(new_temp "$path")
        if printf '%s' "$@" | base64 -d > "$tmp"; then
            mv -- "$tmp" "$path" || { remove_temp "$tmp"; exit 1; }
            remove_temp "$tmp"
        else
            remove_temp "$tmp"
            exit 1
        fi
        ;;
    write-start)
        path=$2
        new_temp "$path"
        ;;
    write-chunk)
        tmp=$2
        shift 2
        printf '%s' "$@" | base64 -d >> "$tmp"
        ;;
    write-end)
        tmp=$2
        path=$3
        mv -- "$tmp" "$path"
        remove_temp "$tmp"
        ;;
    write-abort)
        remove_temp "$2"
        ;;
    *)
        echo "Unknown operation: $operation" >&2
        exit 2
        ;;
esac
