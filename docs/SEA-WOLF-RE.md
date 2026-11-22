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

## ROM data and graphics findings

### Game-command data and handler vectors

`$0929–$09E7` is 191 bytes, divided at code-referenced boundaries `$0929`, `$0963`, `$09A6`, `$09BA`, `$09C2`, `$09CA`, and `$09DA` (the first table currently begins at `$09B9`; the `$09BA` reference enters one byte into it). The labels delimit selected streams, input masks and lookup segments; their full operand grammars are not yet asserted. `$09E8–$09FF` comprises 12 little-endian handler vectors, now expressed as native zmac `DW` words. They are not an additional executable program stream.

### Character graphics and prefixes

`$0B8F–$0BF2`: ten numeric glyphs, 10 bytes each, each row illustrated in source.

`$0BF3–$0BFF`: thirteen trailing bytes, now shown individually with eight-bit patterns. These are outside the ten complete numeric glyphs; no invented eleventh character label is assigned.

`$0C00–$0C38`: 57 bytes between numeric and alphabetic fonts. Their byte patterns are illustrated individually; their exact rendering/control interpretation is not yet established.

`$0C39–$0D3C`: 26 uppercase glyphs, 10 rows each.

### Eleven width/height graphic records

A record consists of **one byte width (bytes per scanline), one byte height (scanlines), then width × height raster bytes**. The end of each record coincides exactly with the next header. Graphics addresses for the first six occur in the twelve ROM object descriptors.

| Record | Address range | Header | Raster payload |
| --- | --- | --- | --- |
| 0 | `$0D3D–$0D7A` | 5 × 12 | 60 bytes |
| 1 | `$0D7B–$0DAC` | 4 × 12 | 48 bytes |
| 2 | `$0DAD–$0DEA` | 5 × 12 | 60 bytes |
| 3 | `$0DEB–$0E18` | 4 × 11 | 44 bytes |
| 4 | `$0E19–$0E46` | 4 × 11 | 44 bytes |
| 5 | `$0E47–$0E54` | 2 × 6 | 12 bytes |
| 6 | `$0E55–$0E74` | 2 × 15 | 30 bytes |
| 7 | `$0E75–$0E87` | 1 × 17 | 17 bytes |
| 8 | `$0E88–$0E97` | 1 × 14 | 14 bytes |
| 9 | `$0E98–$0EA2` | 1 × 9 | 9 bytes |
| 10 | `$0EA3–$0EB4` | 1 × 16 | 16 bytes |

The source now renders each record as a two-byte header followed by one labeled `DB` line per raster row, with pixel bits alongside the data. Row/record byte boundaries are established. **Precise onscreen identities, orientation and collision purposes still require target-side confirmation.**

### Encoded text

`$0EC3–$0F03` stores text using `$40` for spacing, including `GAME OVER`, `HIGH SCORE`, `YOUR SCORE`, `INSERT COIN`, `PUSH BUTTONS`, and `SEA WOLF`. A shared `S` at `$0EFC` is both the last character of `PUSH BUTTONS` and the first of `SEA WOLF`. Each supported text start has a source label; source bytes stay unchanged.

The following `$0F04–$0F23` holds a repeated `$3A–$3C` display-symbol sequence, distinct from the `$0F24–$0F53` display legend and control bytes.

### Object record table and EOF fill

`$0F78–$0FD7` holds twelve eight-byte descriptor records. Their first two bytes encode a **high-byte-first graphic pointer**, e.g. bytes `0D 3D` refer to `$0D3D`. Normal 8080 `DW` would reverse this byte order and is therefore inappropriate for those fields. The existing `$0F7E` reference points into record zero rather than to the table's beginning; this matters when naming field offsets. Remaining descriptor field meanings and object identities need caller analysis.

`$0FD8–$0FE4` contains thirteen trailing object-control bytes.

`$0FE5–$0FFF` is exactly 27 consecutive `$FF` bytes. The earlier linear disassembly expressed each as `RST $38` because Intel 8080 opcode `$FF` is `RST 7`; execution would jump to `$0038`. There is no verified code path into this region, so it is documented as ROM fill with 27 explicit `DB $FF` bytes, not active reset instructions. Its original programming rationale is unverified.

### Integrity method

The data edits were independently checked by expanding literal `DB` values before and after rewriting: script/lookup data 191 bytes, numeric trailer 13 bytes, pre-alphabet data 57 bytes, graphic/text block 487 bytes, legend data 48 bytes, final lookup/descriptors 145 bytes. Handler vectors were converted into twelve `DW` values with the same low-byte-first addresses. The 27-byte tail remains all `$FF`.

These are **source-level byte checks**, not a zmac-assembled ROM comparison. The original four ROM hashes and MAME execution remain mandatory validation gates.

## RE inventory

| ID | Status | Verification criterion |
| --- | --- | --- |
| SW-RE-001 | Partial | Replaced all 111 remaining address-only branch labels with context names; labels and branch roles remain reviewable against execution tracing |
| SW-RE-002 | Partial | Fully decode command $01–$0C operand formats and each handler's register/stack contract, including control command $00 |
| SW-RE-003 | Partial | Eleven graphic record widths/heights and per-row byte boundaries resolved; on-screen identities and caller usage remain to verify |
| SW-RE-004 | Partial | All 36 glyphs plus thirteen trailer and 57 pre-alphabet bytes shown inline; verify interpretation of non-glyph data |
| SW-RE-005 | Partial | Twelve eight-byte descriptor records split and graphic pointer byte-order verified; decode remaining fields against callers |
| SW-RE-006 | Open | Build with `./build.sh` using bundled zmac v1.3; confirm the 4096-byte image and all four SHA-1 hashes |
| SW-RE-007 | Open | Run `mame seawolf -rompath roms -window -skip_gameinfo`, verify input, sound, score, sprites and game progression |
| SW-RE-008 | Open | Recover verified hardware I/O bit definitions from the actual program and board documentation |

## Verification record

**Performed:** Direct Checkmate source-style comparison, source-label naming pass (no remaining `Lxxxx` labels), 36 inline 8×10 font glyphs, eleven inline graphic records, twelve object descriptors, named scripts/lookup boundaries, twelve `DW` handler vectors and 27 explicit `$FF` fill bytes. Source-level checks compared every rewritten data byte and found no mismatch in the verified regions; static named CALL/JP checks found no missing label references. Memory-map SVG and build destinations were revised.

**Not performed:** Native zmac invocation, checksum verification of newly assembled output, MAME execution, physical cabinet execution. The updated build writes to `build/` and creates ignored `roms/seawolf.zip`.

No ROM payload, build toolchain, interpreter, XC, original reference images or hardware interface has been deliberately changed. The ROM checksum gate remains mandatory before merge.
