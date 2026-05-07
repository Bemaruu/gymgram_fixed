# GymGram - Claude Code Rules

## Project
- Flutter app for GymGram Beta.
- Work in small, scoped changes.
- Do not refactor unrelated files.
- Do not change visual style unless requested.
- Prefer simple, maintainable Dart code.

## Token discipline
- Be terse.
- No long explanations unless asked.
- Before reading many files, list max 5 needed files.
- Read only necessary files.
- Summarize command output; do not paste huge logs.
- After each task, report only:
  - files changed
  - what changed
  - test/build result
  - next blocker if any

## Flutter rules
- Keep widgets modular.
- Avoid over-engineering.
- Use existing project patterns.
- Do not add packages without asking.
- Run flutter analyze after meaningful changes when possible.

## Supabase rules
- Never expose secrets.
- Use anon key only on client.
- Respect RLS assumptions.
- Do not modify database schema unless explicitly requested.

## Compact instructions
When compacting, preserve:
- files changed
- current bug/error
- commands run
- pending TODOs
- architectural decisions
Remove:
- conversation filler
- repeated explanations
- discarded alternatives