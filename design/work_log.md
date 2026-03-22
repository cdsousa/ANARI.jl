# Work Log

This file tracks implementation progress in short, chronological entries.

## Entry Format

- Area: short scope label (e.g., `handles`, `params`, `tests`)
- Status: `done` | `in-progress` | `blocked`
- Summary: one or two lines on what changed
- Files: list of touched files
- Notes: optional follow-ups, caveats, or decisions

---

## Entries

### Entry 1
- Area: `core handles, tests`
- Status: `done`
- Summary: Added first idiomatic wrapper scaffold with `Library` and `Device` handle types, pointer safety helpers, finalizers, and idempotent `release!` behavior; added unit tests for null-handle constructor failure, idempotent `release!`, and released-library guard for device creation.
- Files: `src/handles.jl`, `src/ANARI.jl`, `test/handles_test.jl`, `test/runtests.jl`, `Project.toml`
- Notes: Package load check succeeded with `julia --project -e 'using ANARI'`; tests are organized under the Julia-standard `test/` folder and pass with `Pkg.test()`.
