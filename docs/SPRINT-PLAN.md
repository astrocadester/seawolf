# Sprint plan — original software architecture gate

Baseline only; preserve any project-specific plans elsewhere. For each sprint: identify authentic source/language/interpreter/XC/runtime; establish complete original-style source loading and native compilation; retain original gameplay/DATA/control; add only approved hardware adapters; run actual compiler, ROM byte integrity and target execution tests as separate gates; track blockers and deviations in TECHNICAL-DEBT.md. No unapproved substitutes. See ENGINEERING-RULES.md.

## Sea Wolf hard RE — 2026-11-21

Active PR: [#3](https://github.com/lizard43/seawolf/pull/3). Track individual RE tasks in [SEA-WOLF-RE.md](SEA-WOLF-RE.md), IDs SW-RE-001 through SW-RE-008. The source/comment/data classification pass is committed. Merge gate: execute native `./build.sh`, compare all four source-built ROM SHA-1 values, and run Sea Wolf under MAME. Continue verified handler operand decoding, internal label recovery and graphics descriptor decomposition; no speculative native opcodes or altered image bytes.

Checkmate source style aligned in the active branch: header, section spacing, native labels, 36 inline font glyphs; build outputs in ignored `build/`, MAME ZIP in ignored `roms/`. Live checksum and MAME gates remain open.
