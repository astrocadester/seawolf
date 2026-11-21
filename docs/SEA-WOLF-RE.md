# Sea Wolf (1976) — reverse-engineering record

Version: v20261121-0001

## Source authority and method

- The four original ROMs (`sw0041.h`, `sw0042.g`, `sw0043.f`, `sw0044.e`) are byte authority. The original `roms/original/seawolf.zip` stays unchanged.
- Original native Intel 8080 instructions remain assembled with the bundled zmac v1.3. No custom decoder, substitute compiler, or runtime implementation has been introduced.
- Source classification follows actual code references and observable byte patterns. Names inferred from a single call site require continued verification; no undocumented DNA-era symbol names are claimed.
- Checksums provided in the unchanged build script: `b538277d…`, `cc2a99b1…`, `38519843…`, `bd345dd7…`. These remain build targets, not a claim that this PR's build has already passed.

## Native interpreter and interpreted scripts

The interpreter at `$045E` reads the command pointed to by the little-endian script cursor in RAM `$2000`. A zero command enters frame-control processing. A nonzero command indexes the table at `$09E8`, where 12 little-endian 16-bit values identify native handlers:

| Command | Handler address | Source interpretation |
| --- | --- | --- |
| $01 | $08C7 | Native input/control service |
| $02 | $0B7C | Store following byte in RAM $2011 |
| $03 | $0B72 | Store following byte in RAM $2010 |
| $04 | $08A2 | Initialize game state |
| $05 | $0B22 | Native drawing/text service |
| $06 | $0AED | Native drawing/text service |
| $07 | $0B86 | Read inline 16-bit target and replace script pointer |
| $08 | $0AE1 | Native drawing/text service |
| $09 | $0A9F | Native drawing/text service |
| $0A | $0ABC | Native drawing/text service |
| $0B | $0A53 | Native graphics service |
| $0C | $086D | Native game service |

The addresses are read directly from ROM bytes `$09E8–$09FF`. Handler purpose descriptions beyond the explicitly inspected `$0B72`, `$0B7C`, and `$0B86` entry points should be refined by full register-flow analysis before using them as authoritative handler names.

The script/data region begins at `$0929`. This is not assembly code; inline values may be command bytes, lengths, coordinates, or addresses consumed by a specific handler. A disassembler must not freely decode this region into 8080 instructions.

## Graphics organization

- `$0B8F` is referenced by the character rendering routine at `$0B49`. First glyph rows are `3C 7E 66 66 66 66 66 66 7E 3C`, recognizable as a ten-row digit silhouette. The inline ASCII pixel chart is attached directly to the data in `src/seawolf.asm`.
- `$0C00–$0D3F` includes a graphic header followed by recognizable alphanumeric raster patterns. The original data is retained verbatim rather than reinterpreted as executable opcodes.
- `$0D40–$0EB7` contains packed graphic/mask patterns. Exact per-frame boundaries still need confirmation through drawing callers.
- `$0EB8–$0F53` includes display phrases and control bytes. The original `$40` bytes within phrases are retained as encoded spacing/control data rather than silently converted to ASCII.
- `$0F78–$0FE4` includes object descriptors; code points to `$0F7E` as `SHIP_TABLE`. Do not assume the enclosing data begins with a ship record at `$0F78`.

## RE inventory

| ID | Status | Verification criterion |
| --- | --- | --- |
| SW-RE-001 | Partial | Named 53 existing native entries and classified 114 existing DB lines; continue to determine exact internal branch roles for 111 remaining address labels |
| SW-RE-002 | Partial | Fully decode command $01–$0C operand formats and each handler's register/stack contract, including control command $00 |
| SW-RE-003 | Partial | Identify each graphics asset's record length and meaning from actual render callers and compare frames against original running ROM |
| SW-RE-004 | Open | Rework character graphic rows into verified per-character boundaries with literal inline bit visualizations |
| SW-RE-005 | Open | Separate object descriptor records and annotate complete fields/stride with call-site evidence |
| SW-RE-006 | Open | Build with `./build.sh` using bundled zmac v1.3; confirm the 4096-byte image and all four SHA-1 hashes |
| SW-RE-007 | Open | Run `mame seawolf -rompath roms -window -skip_gameinfo`, verify input, sound, score, sprites and game progression |
| SW-RE-008 | Open | Recover verified hardware I/O bit definitions from the actual program and board documentation |

## Verification record

**Performed:** Repository source inspection, classification of indexed interpreter data and bitmap rows, mechanical source-label edits, README and memory-map source update.

**Not performed:** Native zmac invocation, checksum verification of newly assembled output, MAME execution, physical cabinet execution.

No ROM payload, build toolchain, interpreter, XC, original reference images or hardware interface has been deliberately changed. The ROM checksum gate remains mandatory before merge.
