#!/bin/sh
#
# Exercise contents/code/backup-io.sh without Qt: the read cap, the single-shot
# write, the chunked write used for large backups, and the abort path.
#
#   ./tests/backup-io.sh
#
# Needs the usual coreutils (mktemp, head, base64, cut, cmp) and nothing else.

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HELPER="$DIR/../contents/code/backup-io.sh"
MAX=8388608

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

ok() {
    echo "ok - $*"
}

printf '{"hello":"world"}\n' > "$TMP/input.json"

# read
[ "$(sh "$HELPER" read "$TMP/input.json")" = '{"hello":"world"}' ] \
    || fail "read returned the wrong content"
ok "read"

# read cap on a regular file
if command -v truncate >/dev/null 2>&1; then
    truncate -s $((MAX + 1)) "$TMP/too-big.json"
else
    head -c $((MAX + 1)) /dev/zero > "$TMP/too-big.json"
fi
if sh "$HELPER" read "$TMP/too-big.json" > "$TMP/too-big.out" 2> "$TMP/too-big.err"; then
    fail "read of an oversized file should fail"
fi
[ ! -s "$TMP/too-big.out" ] || fail "read emitted data from an oversized file"
grep -q 'too large' "$TMP/too-big.err" || fail "read did not explain the size limit"
ok "read cap"

# read cap on a stream (no size to stat): head's byte limit must stop it
bytes=$(sh "$HELPER" read /dev/zero | wc -c | tr -d '[:space:]')
[ "$bytes" -eq "$MAX" ] || fail "read /dev/zero returned $bytes bytes, expected $MAX"
ok "read cap on a stream"

# single-shot write, including a path with a space and a quote
b64=$(base64 < "$TMP/input.json" | tr -d '\n')
weird="$TMP/with space'quote.json"
sh "$HELPER" write "$weird" "$b64"
cmp "$TMP/input.json" "$weird" || fail "single-shot write content differs"
ok "single-shot write"

# chunked write: a payload larger than one 64 KiB chunk
head -c 350000 /dev/urandom > "$TMP/payload.bin"
base64 < "$TMP/payload.bin" | tr -d '\n' > "$TMP/payload.b64"
len=$(wc -c < "$TMP/payload.b64" | tr -d '[:space:]')
[ "$len" -gt 65536 ] || fail "test payload is not large enough"

temp=$(sh "$HELPER" write-start "$TMP/chunked.bin")
[ -n "$temp" ] || fail "write-start returned no temp path"
off=1
while [ "$off" -le "$len" ]; do
    end=$((off + 65535))
    [ "$end" -le "$len" ] || end=$len
    chunk=$(cut -c "${off}-${end}" "$TMP/payload.b64")
    sh "$HELPER" write-chunk "$temp" "$chunk"
    off=$((off + 65536))
done
sh "$HELPER" write-end "$temp" "$TMP/chunked.bin"
cmp "$TMP/payload.bin" "$TMP/chunked.bin" || fail "chunked write content differs"
[ ! -e "$(dirname -- "$temp")" ] || fail "chunked write left its temporary directory"
ok "chunked write"

# abort removes both the file and its private directory
temp=$(sh "$HELPER" write-start "$TMP/abort.bin")
dir=$(dirname -- "$temp")
sh "$HELPER" write-abort "$temp"
[ ! -e "$temp" ] || fail "write-abort left the temporary file"
[ ! -e "$dir" ] || fail "write-abort left the temporary directory"
ok "abort"

echo "backup-io: all checks passed"
