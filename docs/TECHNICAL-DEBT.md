# Technical debt — architecture audit baseline

Starting investigations, not assertions that this repository contains defects. Preserve existing project-specific debt.

| ID | Status | Evidence |
| --- | --- | --- |
| ENG-001 | Audit required | Identify host-language source parsers/definition extractors, synthetic dictionary/word maps and token rewrites; move to native mechanisms. |
| ENG-002 | Audit required | Prove complete native source-loading and XC/compiler/runtime path. |
| ENG-003 | Audit required | Justify hardware adaptations from original source; obtain approval before deviations. |
| ENG-004 | Audit required | Separate source audits, compiler builds, ROM integrity, MAME and real-hardware tests. |

Close only with project evidence/commits. See ENGINEERING-RULES.md.
