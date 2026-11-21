#!/usr/bin/env bash
# Sea Wolf original Intel 8080 ROM build — bundled zmac v1.3.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
fail() { echo "ERROR: $*" >&2; exit 1; }
for cmd in dd sha1sum zip stat; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"
done
[[ -x tools/zmac ]] || fail "Bundled tools/zmac v1.3 is unavailable"
[[ -f src/seawolf.asm ]] || fail "Missing src/seawolf.asm"
[[ -f roms/original/seawolf.zip ]] || fail "Missing original ROM reference"

rom_names=(sw0041.h sw0042.g sw0043.f sw0044.e)
rom_sha1=(
    b538277d3a633dd8a3179cff202f18d322e6fe17
    cc2a99b18695f61e0540c9f6bf8fe3b391dde4a0
    385198434b08fe4651ad2c920d44fb49cfe0bc33
    bd345dd72fed8ce15da76c381782b025f71b006f
)
mkdir -p build roms
rm -f build/seawolf.bin build/seawolf.lst roms/seawolf.zip
for name in "${rom_names[@]}"; do rm -f "build/$name"; done
echo 'Sea Wolf (1976) original ROM build'
echo '[1/3] Assemble with bundled zmac v1.3'
./tools/zmac -c -o build/seawolf.bin -x build/seawolf.lst src/seawolf.asm
[[ -s build/seawolf.bin ]] || fail 'Missing assembled image'
(( $(stat -c %s build/seawolf.bin) == 4096 )) || fail 'ROM image is not 4096 bytes'
echo '[2/3] Split ROM chips and verify original SHA-1'
for i in 0 1 2 3; do
    name=${rom_names[i]}
    dd if=build/seawolf.bin of="build/$name" bs=1024 skip="$i" count=1 status=none
    (( $(stat -c %s "build/$name") == 1024 )) || fail "$name is not 1024 bytes"
    actual=$(sha1sum "build/$name")
    actual=${actual%% *}
    [[ "$actual" == "${rom_sha1[i]}" ]] || fail "$name: expected ${rom_sha1[i]}, got $actual"
    echo "  $name PASS $actual"
done
echo '[3/3] Package MAME roms/seawolf.zip'
(cd build && zip -q -X ../roms/seawolf.zip "${rom_names[@]}")
[[ -s roms/seawolf.zip ]] || fail 'MAME ROM archive missing'
echo 'PASS: original 4096 bytes, all four SHA-1 hashes; roms/seawolf.zip'
