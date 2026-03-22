# Work Log

This file tracks implementation progress in short, chronological entries.

## Entry Format

- *Summary*: one or two lines on what changed
- *Files*: list of touched files
- *Notes*: optional follow-ups, caveats, or decisions

---

## Entries

### Entry 1
- *Summary*: Added first idiomatic wrapper scaffold with `Library` and `Device` handle types, pointer safety helpers, finalizers, and idempotent `release!` behavior; added unit tests for null-handle constructor failure, idempotent `release!`, and released-library guard for device creation.
- *Files*: `src/handles.jl`, `src/ANARI.jl`, `test/handles_test.jl`, `test/runtests.jl`, `Project.toml`
- *Notes*: Package load check succeeded with `julia --project -e 'using ANARI'`; tests are organized under the Julia-standard `test/` folder and pass with `Pkg.test()`.

### Entry 2
- *Summary*: Implemented object wrappers for `World`, `Frame`, `Camera`, and `Renderer`; added explicit `setparam!` and `commit!` APIs with strict data-type handling for scalar values, object handles, and `UInt32` vec2 parameters.
- *Files*: `src/handles.jl`, `test/handles_test.jl`, `design/work_log.md`
- *Notes*: Added an end-to-end parameter/commit test flow against `helide` and validated all tests with `Pkg.test()`.
