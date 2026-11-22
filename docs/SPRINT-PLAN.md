# Sprint plan — original software architecture gate

Baseline only; preserve any project-specific plans elsewhere. For each sprint: identify authentic source/language/interpreter/XC/runtime; establish complete original-style source loading and native compilation; retain original gameplay/DATA/control; add only approved hardware adapters; run actual compiler, ROM byte integrity and target execution tests as separate gates; track blockers and deviations in TECHNICAL-DEBT.md. No unapproved substitutes. See ENGINEERING-RULES.md.

## Sea Wolf hard RE — 2026-11-21

Active PR: [#3](https://github.com/lizard43/seawolf/pull/3). Track individual RE tasks in [SEA-WOLF-RE.md](SEA-WOLF-RE.md), IDs SW-RE-001 through SW-RE-008. The source/comment/data classification pass is committed. Merge gate: execute native `./build.sh`, compare all four source-built ROM SHA-1 values, and run Sea Wolf under MAME. Continue verified handler operand decoding, internal label recovery and graphics descriptor decomposition; no speculative native opcodes or altered image bytes.

Checkmate source style aligned in the active branch: header, section spacing, native labels, 36 inline font glyphs; build outputs in ignored `build/`, MAME ZIP in ignored `roms/`. Live checksum and MAME gates remain open.

### SW-RE graphics and data milestone — 2026-11-21

- Redesigned `images/seawolf-memory-map.svg` in the Checkmate address-space card style; four ROM chips, 1 KB work RAM, 7 KB video RAM and a self-contained Sea Wolf-themed upper-right emblem.
- Resolved script/lookup region boundaries, twelve little-endian handler vectors, eleven measured width×height graphics, twelve eight-byte descriptor records, overlapping packed text and 27 bytes of ROM EOF fill.
- Remaining gates: inspect actual object rendering and command parameter contracts; run original zmac build, four chip SHA-1 comparisons, MAME display/input/score/sound checks before merge. No claim of emulator validation in this milestone.
