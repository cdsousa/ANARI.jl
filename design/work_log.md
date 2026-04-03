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

### Entry 9
- *Summary*: Added external `Library(name, callback::Function)` constructor to install user-provided status logging callbacks with safe callback-reference retention.
- *Files*: `src/status.jl`, `src/handles.jl`, `test/status_test.jl`, `design/work_log.md`
- *Notes*: User callback supports either `(message)` or `(severity, code, source_type, message)` signatures; callback exceptions are caught and forwarded to Julia logging, then ANARI status is still logged.

### Entry 10
- *Summary*: Added a full throwaway rendering sample that generates three 1920x1080 PNG images (90-degree rotation per image) with side-by-side triangles; documented wrapper API gaps exposed by the sample and renamed the throwaway workspace folder from `examples/` to `experiments/`.
- *Files*: `experiments/triangle_gallery/run.jl`, `experiments/triangle_gallery/Project.toml`, `experiments/triangle_gallery/Manifest.toml`, `experiments/triangle_gallery/README.md`, `experiments/triangle_gallery/gap.md`, `experiments/triangle_gallery/output/triangles_01_0deg.png`, `experiments/triangle_gallery/output/triangles_02_90deg.png`, `experiments/triangle_gallery/output/triangles_03_180deg.png`, `design/work_log.md`
- *Notes*: Gap analysis confirms current wrapper limitations around scene-object wrappers and broader parameter marshalling; generated PNGs were validated after background-color handling adjustments for this backend.

### Entry 11
- *Summary*: Parameterized `Array1D` on element type to preserve payload typing through wrappers; updated array mapping helpers to return typed pointers for `Array1D{T}` and keep a compatibility fallback for unknown element type handles.
- *Files*: `src/handles.jl`, `src/arrays.jl`, `test/handles_test.jl`, `design/work_log.md`
- *Notes*: `new_array1d` now returns `Array1D{T}` based on input vector element type; raw-handle constructor remains available and produces `Array1D{Any}` for externally sourced arrays; full test suite passes with `Pkg.test()`.

### Entry 12
- *Summary*: Added stored element-count metadata on `Array1D` and updated typed mapping to return `Vector{T}` directly using this length, enabling more transparent map usage.
- *Files*: `src/handles.jl`, `src/arrays.jl`, `test/handles_test.jl`, `design/work_plan.md`, `design/work_log.md`
- *Notes*: `Array1D` constructors now capture `length`; typed `map_array` returns wrapped vectors while `Array1D{Any}` mapping remains pointer-based fallback; full test suite passes with `Pkg.test()`.

### Entry 13
- *Summary*: Added first-class scene object wrappers `Geometry`, `Material`, `Surface`, `Group`, `Instance`, and `Light` with constructor guards, finalizers, and idempotent release behavior; added scene-chain tests and expanded object-array support in `new_array1d` for vectors of wrapper handles.
- *Files*: `src/handles.jl`, `src/parameters.jl`, `src/arrays.jl`, `src/anari_type.jl`, `test/handles_test.jl`, `test/anari_type_test.jl`, `design/work_log.md`
- *Notes*: Extended object dtype handling to include scene objects and `ANARI_ARRAY1D`; added `anari_type(::Type{<:Array1D})` for inferred array parameter typing; full test suite passes with `Pkg.test()`.

### Entry 14
- *Summary*: Refactored repeated handle boilerplate in `handles.jl` by centralizing finalizer attachment and live-handle guards, and by generating repeated object-wrapper and device-constructor patterns with macros.
- *Files*: `src/handles.jl`, `design/work_log.md`
- *Notes*: Public API and lifecycle semantics were preserved while reducing duplication; validated with a full passing `Pkg.test()` run.

### Entry 15
- *Summary*: Added first-class object wrappers `Sampler`, `SpatialField`, and `Volume` (subtype constructors, finalizers, idempotent `release!`); extended `setparam!` object dtypes and `anari_type` dispatch; added helide-backed constructor/commit tests and trait tests.
- *Files*: `src/handles.jl`, `src/parameters.jl`, `src/anari_type.jl`, `test/handles_test.jl`, `test/anari_type_test.jl`, `design/work_log.md`
- *Notes*: Helide subtypes used in tests: `transform` (sampler), `structuredRegular` (spatial field), `transferFunction1D` (volume). Run `Pkg.test()` where `ANARI_SDK_jll` resolves (local manifest or registered env).

### Entry 16
- *Summary*: Made `Array1D` a non-parametric concrete type again (aligned with ANARI’s runtime array typing); store Julia-side element interpretation in field `eltype::Type` (default `Any`); `Base.eltype` forwards to that field; unified `map_array` on `eltype === Any` vs concrete type; `anari_type(::Type{Array1D})` for inferred parameters; updated design docs and sample.
- *Files*: `src/handles.jl`, `src/arrays.jl`, `src/anari_type.jl`, `test/handles_test.jl`, `test/anari_type_test.jl`, `design/work_plan.md`, `design/work_log.md`, `design/work_plan_sample.jl`
- *Notes*: Supersedes the `Array1D{T}` / `Array1D{Any}` split described in Entries 11–12; Entry 13’s `anari_type` hook is now `Type{Array1D}` only. Field was named `element_type` briefly, then `eltype`.

### Entry 17
- *Summary*: Added `Array2D` and `Array3D` handle wrappers with stored extents and `eltype`; implemented `new_array2d` / `new_array3d` copy helpers (primitives and matrices/volumes of object handles), plus `map_array` / `unmap_array` overloads; extended `anari_type`, inferred `setparam!` object dtypes, and helide-backed tests for 2D/3D round-trips and raw-pointer fallbacks.
- *Files*: `src/handles.jl`, `src/arrays.jl`, `src/parameters.jl`, `src/anari_type.jl`, `test/handles_test.jl`, `test/anari_type_test.jl`, `design/work_log.md`
- *Notes*: Host copy order follows Julia column-major layout (`vec(data)`), aligned with ANARI `(numElements1, …)` fastest-varying first dimension; full test suite passes with `Pkg.test()`.
