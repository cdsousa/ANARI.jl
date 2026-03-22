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

### Entry 3
- *Summary*: Implemented `anari_type` dispatch trait mapping Julia scalar, tuple-vector, and handle types to `ANARIDataType` constants; extended `_prepare_parameter_ref` with `Float32` vec2/3/4 cases; added inferred `setparam!(device, object, name, value)` overload that derives dtype via `anari_type`.
- *Files*: `src/anari_type.jl` (new), `src/handles.jl`, `src/ANARI.jl`, `test/anari_type_test.jl` (new), `test/runtests.jl`
- *Notes*: All 46 tests pass with `Pkg.test()`; `anari_type` is extensible by downstream packages via additional dispatch methods.

### Entry 4
- *Summary*: Added synchronous frame helpers `render!`, `wait_frame!`, and `render_and_wait!` with released-handle guards; added an end-to-end wrapper render/wait test using the `helide` backend.
- *Files*: `src/handles.jl`, `test/handles_test.jl`, `design/work_log.md`
- *Notes*: Corrected wait-mask keyword default to `ANARIWaitMask(ANARI_WAIT)` to match binding signatures; full test suite passes with `Pkg.test()`.

### Entry 5
- *Summary*: Added frame buffer mapping wrappers `map_frame` and `unmap_frame` with released-handle guards and tuple return `(pixels, width, height, pixel_type)`; added an end-to-end map/unmap test after synchronous rendering.
- *Files*: `src/handles.jl`, `test/handles_test.jl`, `design/work_log.md`
- *Notes*: In this environment, mapping the color channel requires explicit `"channel.color"`; some runs report `ANARI_UNKNOWN` pixel type, so tests validate pointer and dimensions without assuming backend metadata.

### Entry 6
- *Summary*: Refactored rendering/frame-mapping APIs and parameter marshaling/commit APIs into dedicated module files without changing behavior or external API.
- *Files*: `src/render.jl` (new), `src/parameters.jl` (new), `src/handles.jl`, `src/ANARI.jl`, `design/work_log.md`
- *Notes*: Kept exports and method signatures stable while separating concerns across handle lifecycle, parameter, and render/frame modules; preserved public API (`setparam!`, `commit!`, inferred `setparam!`) and validated with a full passing `Pkg.test()` run.

### Entry 7
- *Summary*: Added first array wrapper milestone with `Array1D` handle type and `new_array1d` copy helper; added `map_array`/`unmap_array` wrappers and tests validating copy correctness.
- *Files*: `src/handles.jl`, `src/arrays.jl` (new), `src/ANARI.jl`, `test/handles_test.jl`, `design/work_log.md`
- *Notes*: `new_array1d` currently targets 1D arrays and copies from Julia memory into ANARI-managed memory via map/unmap; full test suite passes with `Pkg.test()`.

### Entry 8
- *Summary*: Added status callback logging bridge and `Library(...; status_logging=true)` constructor path; mapped ANARI severities to Julia logging levels and added tests for level routing.
- *Files*: `src/status.jl` (new), `src/ANARI.jl`, `src/handles.jl`, `test/status_test.jl` (new), `test/runtests.jl`, `Project.toml`, `design/work_log.md`
- *Notes*: Callback is installed via `anariLoadLibrary` using a stable `@cfunction` pointer; library now stores callback metadata and clears it on `release!`; full test suite passes with `Pkg.test()`.
