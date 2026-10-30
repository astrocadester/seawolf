#!/usr/bin/env bash
# build.sh - v20261030-0001
set -euo pipefail
cd "$(dirname "$0")"
echo "Sea Wolf (1976) - original 8080 ROM build"
mkdir -p roms
./tools/zmac -o src/seawolf.bin src/seawolf.asm
test "$(wc -c < src/seawolf.bin)" -eq 4096 || { echo "ERROR: ROM image must be 4096 bytes"; exit 1; }
for i in 1 2 3 4; do
  case "$i" in
    1) n=sw0041.h ;;
    2) n=sw0042.g ;;
    3) n=sw0043.f ;;
    4) n=sw0044.e ;;
  esac
  dd if=src/seawolf.bin of="roms/$n" bs=1024 skip=$((i-1)) count=1 status=none
done
echo "Verifying original MAME ROM checksums"
sha1sum -c <<'SHA1'
b538277d3a633dd8a3179cff202f18d322e6fe17  roms/sw0041.h
cc2a99b18695f61e0540c9f6bf8fe3b391dde4a0  roms/sw0042.g
385198434b08fe4651ad2c920d44fb49cfe0bc33  roms/sw0043.f
bd345dd72fed8ce15da76c381782b025f71b006f  roms/sw0044.e
SHA1
zip -jqFS roms/seawolf.zip roms/sw0041.h roms/sw0042.g roms/sw0043.f roms/sw0044.e
echo "PASS: 4096-byte reconstruction matches all four original ROMs"
