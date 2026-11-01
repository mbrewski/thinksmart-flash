#!/bin/bash
# Inspect/repair images/thinksmart-flash.img pmOS_boot (p1).
# The public MEGA Plasma 6 image has been observed with an empty boot payload
# (GitHub issue #3). We copy a known-good kernel/extlinux/DTB set from
# the bootstrap image's pmOS_boot if vmlinuz or extlinux.conf is missing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEBUGFS=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
E2LS=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
IMG="${1:-$ROOT/images/thinksmart-flash.img}"
BOOTSTRAP_P1="$ROOT/images/thinksmart-flash-bootstrap-boot.img"
WORKDIR="$ROOT/work"
mkdir -p "$WORKDIR"

if [ ! -f "$IMG" ]; then
    echo "ERROR: ubuntu image not found: $IMG" >&2
    exit 1
fi

python3 - <<PY
import struct, os, json
img = os.environ.get("IMG") or "$IMG"
with open(img, "rb") as f:
    mbr = f.read(512)
parts = []
for i in range(4):
    e = mbr[446+i*16:446+(i+1)*16]
    ptype = e[4]
    start = struct.unpack_from("<I", e, 8)[0]
    nsec = struct.unpack_from("<I", e, 12)[0]
    if nsec:
        parts.append({"n": i+1, "type": f"{ptype:02x}", "start": start, "sectors": nsec, "bytes": nsec*512})
open("$WORKDIR/parts.json","w").write(json.dumps(parts, indent=2))
print("parsed", parts)
PY

P1_START=$(python3 -c 'import json; print(json.load(open("'"$WORKDIR"'/parts.json"))[0]["start"])')
P1_SECS=$(python3 -c 'import json; print(json.load(open("'"$WORKDIR"'/parts.json"))[0]["sectors"])')
P1="$WORKDIR/ubuntu-pmOS_boot.img"

echo "Extracting ubuntu p1 (start=$P1_START sectors=$P1_SECS)"
dd if="$IMG" of="$P1" bs=512 skip="$P1_START" count="$P1_SECS" status=progress

echo "=== ubuntu p1 listing ==="
$DEBUGFS -R 'ls -l /' "$P1" | tee "$WORKDIR/ubuntu-p1-ls.txt"

has_vmlinuz=0
has_extlinux=0
grep -q ' vmlinuz$' "$WORKDIR/ubuntu-p1-ls.txt" && has_vmlinuz=1 || true
grep -q ' extlinux$' "$WORKDIR/ubuntu-p1-ls.txt" && has_extlinux=1 || true

echo "has_vmlinuz=$has_vmlinuz has_extlinux=$has_extlinux"

if [ "$has_vmlinuz" = "1" ] && [ "$has_extlinux" = "1" ]; then
    echo "ubuntu pmOS_boot looks complete; no splice needed"
    exit 0
fi

if [ ! -f "$BOOTSTRAP_P1" ]; then
    echo "ERROR: bootstrap p1 extract missing: $BOOTSTRAP_P1" >&2
    exit 1
fi

echo "Splicing bootstrap pmOS_boot over empty/corrupt ubuntu p1"
# Preserve a copy of the broken p1 for forensics
cp "$P1" "$WORKDIR/ubuntu-pmOS_boot.BROKEN.img"
dd if="$BOOTSTRAP_P1" of="$IMG" bs=512 seek="$P1_START" conv=notrunc status=progress
echo "Spliced. Re-extracting to verify."
dd if="$IMG" of="$P1" bs=512 skip="$P1_START" count="$P1_SECS" status=none
$DEBUGFS -R 'ls -l /' "$P1"
$DEBUGFS -R 'cat /extlinux/extlinux.conf' "$P1"
echo "REPAIR_OK"
