# Original software first — mandatory engineering policy

1. Preserve original program source, native language, compiler/XC, interpreter, runtime, DATA, graphics and control flow wherever available. Original software is the priority, regardless of implementation difficulty.
2. Build complete original-style programs through original loading and compilation mechanisms. For TERSE, source blocks/LOAD, dictionaries, word boundaries, source order and target allocation belong to original TERSE and DNA XC.
3. Node.js/JavaScript, Python and shell may launch original tools, move unchanged source, package their output and independently verify. They may NOT interpret/restructure original source, parse TERSE definitions, invent dictionaries, assign per-word compilation addresses, replace gameplay/graphics or rewrite compiled execution tokens.
4. Native Z80 or other machine-code adaptations are for actual target hardware interfaces, documented as distinct from unchanged original behavior. Do not invent new behavior when original code exists.
5. If original mechanisms are blocked, STOP, investigate, explain the exact obstacle and obtain explicit user approval BEFORE any alternate compiler, parser, translation, source rewrite, workaround or substitute implementation. Tests passing do not grant permission.
6. Distinguish source inspection, real native compilation, byte integrity, emulator execution and physical hardware evidence; never report unexecuted checks as passed.
7. Keep README project/build-oriented, plans in docs/SPRINT-PLAN.md, risks/deviations in docs/TECHNICAL-DEBT.md, preserving existing history and content.
8. Block PRs that violate this architecture; each PR must document native source/toolchain, justification for adaptations, approval, executed tests and remaining work. No assistant may grant itself an exception.
