# Technical debt — architecture audit baseline

Starting investigations, not assertions that this repository contains defects. Preserve existing project-specific debt.

| ID | Status | Evidence |
| --- | --- | --- |
| ENG-001 | Audit required | Identify host-language source parsers/definition extractors, synthetic dictionary/word maps and token rewrites; move to native mechanisms. |
| ENG-002 | Audit required | Prove complete native source-loading and XC/compiler/runtime path. |
| ENG-003 | Audit required | Justify hardware adaptations from original source; obtain approval before deviations. |
| ENG-004 | Audit required | Separate source audits, compiler builds, ROM integrity, MAME and real-hardware tests. |

Close only with project evidence/commits. See ENGINEERING-RULES.md.

## Sea Wolf reverse-engineering verification — 2026-11-21

| ID | Status | Evidence / gate |
| --- | --- | --- |
| SW-RE-006 | Awaiting execution | Reassemble PR #3 with bundled `tools/zmac` v1.3 and verify four original SHA-1 values, using unmodified `build.sh`. |
| SW-RE-007 | Awaiting execution | Exercise startup, input, gameplay, character and sprite drawing, scoring and sound in MAME. |
| SW-RE-002 | Partial | Native table addresses established; handler-specific inline operand contracts require register tracing. |
| SW-RE-003–005 | Partial / open | Resolve per-glyph, per-frame and per-descriptor graphic boundaries from native consumers. |

These are evidence gates, not substitutes for original software. The inherited ENG items remain as originally recorded.

Style/layout follow-up: all original `Lxxxx` labels have been replaced with contextual identifiers. Their precise control-flow interpretation remains subject to emulator tracing; naming alone is not verification. Build output is now isolated under ignored `build/` and `roms/seawolf.zip`.

### SW-RE byte and source validation status — 2026-11-21

- Data classification is now evidence-based: eleven graphics with width/height/raster row consistency; 12 object records whose first two bytes are a high-byte-first graphic pointer; and 27 `$FF` bytes at ROM end. Exact graphic IDs and remaining descriptor fields remain unverified.
- Native assembler execution, original ROM checksums and MAME runtime remain outstanding. Source-level comparisons of rewritten literal DB ranges were performed and matched; they do not replace compilation verification.
- `$0BF3–$0BFF` and `$0C00–$0C38` are bounded raster/control data; no invented glyph purpose is assigned beyond what the bytes establish.
