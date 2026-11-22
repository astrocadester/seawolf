# Sprint plan — original software architecture gate

Baseline only; preserve any project-specific plans elsewhere. For each sprint: identify authentic source/language/interpreter/XC/runtime; establish complete original-style source loading and native compilation; retain original gameplay/DATA/control; add only approved hardware adapters; run actual compiler, ROM byte integrity and target execution tests as separate gates; track blockers and deviations in TECHNICAL-DEBT.md. No unapproved substitutes. See ENGINEERING-RULES.md.

## Sea Wolf hard RE — 2026-11-21

Active PR: [#3](https://github.com/lizard43/seawolf/pull/3). Track individual RE tasks in [SEA-WOLF-RE.md](SEA-WOLF-RE.md), IDs SW-RE-001 through SW-RE-008. The source/comment/data classification pass is committed. Merge gate: execute native `./build.sh`, compare all four source-built ROM SHA-1 values, and run Sea Wolf under MAME. Continue verified handler operand decoding, internal label recovery and graphics descriptor decomposition; no speculative native opcodes or altered image bytes.

Checkmate source style aligned in the active branch: header, section spacing, native labels, 36 inline font glyphs; build outputs in ignored `build/`, MAME ZIP in ignored `roms/`. Live checksum and MAME gates remain open.

### SW-RE graphics and data milestone — 2026-11-21

- Redesigned `images/seawolf-memory-map.svg` in the Checkmate address-space card style; four ROM chips, 1 KB work RAM, 7 KB video RAM and a self-contained Sea Wolf-themed upper-right emblem.
- Resolved script/lookup region boundaries, twelve little-endian handler vectors, eleven measured width×height graphics, twelve correctly aligned eight-byte descriptor records beginning at `$0F7E`, overlapping packed text and 27 bytes of ROM EOF fill. The misaligned `$0F78` descriptor grouping has been repaired, and text is now represented as byte-exact string expressions.
- Remaining gates: inspect actual object rendering and command parameter contracts; run original zmac build, four chip SHA-1 comparisons, MAME display/input/score/sound checks before merge. No claim of emulator validation in this milestone.

Latest source cleanup: the `$09CA–$09E7` bytes resolve to fifteen native address entries (`DW`), replacing erroneous input-edge/debounce annotations; graphics record names no longer assert ship identity. Original byte ordering retained.

## SW-RE ship graphics and handlers — 2026-11-21

- All 12 `GAME_COMMAND_HANDLER_TABLE` entries now use actual native entry labels and have command number/effect inline; `$01` is the `RET` at `$08C7`.
- Verified that `$0F7E` and `$0FAE` select two directional groups of six ships. The alternate path sets flag `$10` and uses reversed MB14241 output at `$01B8`, while the normal path at `$0192` reads port `$03`.
- New `images/seawolf-graphics-re.svg` shows all eleven original graphics records in normal and reversed bit orientation at shift zero. Follow-up: verify every shift/placement value with MAME execution, not standalone render assumptions.

## SW-RE interpreted scripts and hit-path labels — 2026-11-21

- Verified the indexed dispatcher uses `RLCA` before indexing `$09E8`, making the first word the reserved `$00` return-vector slot. The actual eleven indexed handlers run from `$01` through `$0B`. Fixed source and master command-table documentation.
- Decoded `$0929–$09B8`: 34 command records (13 initial, 14 secondary, 7 auxiliary) across 144 original bytes. Named opcodes, `DB` scalar operands and `DW` pointer fields now preserve the exact original byte image, verified against the original `main` assembly source byte-for-byte.
- Renamed `OBJECT_RESOLVE_SCAN_ENTRY` to `RENDER_HIT_EFFECT` and 23 additional generic object/control labels to hit-detection, score/BCD, video clear, ship record and template-selection names. Descriptive source comments aligned with caller evidence.
- Merge gates remain bundled zmac v1.3, four original ROM SHA-1 hashes and MAME runtime. Byte-level source comparison is a separate static check.
