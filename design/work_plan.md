# ANARI.jl Idiomatic Wrapper Work Plan

This document captures agreed design decisions and a practical implementation path for adding idiomatic Julia wrappers on top of `LibANARI`.

## Scope

- Keep `src/LibANARI.jl` as the generated low-level FFI layer.
- Add Julia-idiomatic wrappers in `src/ANARI.jl` (or files included by it).
- Do not remove low-level access; expose raw bindings through `LibANARI`.

## Final Design Decisions

1. Handle type representation
- Chosen: Abstract type hierarchy + concrete subtypes.
- Plan: Define `abstract type ANARIHandle end` and concrete mutable wrapper types like `Library`, `Device`, `World`, `Frame`, etc.
- Update: Semantic handles stay non-parametric; `Array1D` is a single concrete type aligned with ANARI (element datatype and length are runtime). Julia-side interpretation of mapped memory is recorded in an `eltype::Type` field (default `Any` when unknown), exposed also via `Base.eltype`.
- Reason: Clear dispatch boundaries; array payload typing matches ANARI’s runtime model instead of Julia type parameters.

2. Memory management
- Chosen: Mutable handle types with finalizer attached in inner constructor.
- Plan: Each wrapper stores native pointer and relevant owner context (for release). Inner constructor registers `finalizer` that releases only when pointer is non-null.
- Manual release: Provide explicit `release!(obj)` API. It must check for null and become a no-op on already released handles.
- Reason: Avoid manual-only lifecycle and avoid mandatory `do` blocks; still allow deterministic release.

3. Parameter-setting API
- Chosen: Implement explicit type-tag API first (C-like).
- Plan: Add `setparam!(device, object, name::AbstractString, dtype::ANARIDataType, value)` wrappers that marshal supported Julia values.
- Future: Keep room for higher-level inferred typing and property sugar later.

4. Julia <-> ANARIDataType mapping
- Chosen: Trait-like `anari_type` function.
- Plan: Implement `anari_type(::Type{T})` methods for supported scalar/vector/matrix cases used by current wrappers.
- Reason: Extensible by downstream packages and future APIs.

5. Naming convention
- Chosen: Julia-idiomatic names in `ANARI`; low-level names stay in `LibANARI`.
- Plan: High-level API uses constructor-style names such as `Device(...)`, `World(...)`, `Frame(...)` and mutating verbs like `setparam!`, `commit!`, `render!`, `map_frame`.
- Reason: Keeps a clean user API without hiding raw functions.

6. Error and status handling
- Chosen: Null-check constructor failures + status callback integration.
- Plan:
  - Constructors throw Julia exceptions when native pointer is null.
  - Provide status callback bridge that maps ANARI severities to Julia `Logging` macros.
- Reason: Fail fast on hard errors; provide useful runtime diagnostics.

7. Array API
- Chosen: Thin helper that copies memory to ANARI-owned side.
- Plan:
  - Implement helper `new_array1d` for 1D (and optionally 2D/3D later) arrays that accept Julia vectors, create ANARI array objects, and copy payload.
  - `Array1D` is not parameterized: it stores `length::UInt64` and `eltype::Type` (Julia element type used for `unsafe_wrap` when mapping, or `Any` if unknown).
  - `new_array1d` sets `eltype` from the vector’s element type for primitive data, and to `LibANARI.ANARIObject` for vectors of object handles.
  - Raw-pointer constructor `Array1D(ptr, device, length=0, eltype=Any)` wraps arrays created outside the helper (unknown layout → `eltype` stays `Any`).
  - `map_array(device, array)` returns `Vector{array.eltype}` when `eltype !== Any`, otherwise `Ptr{Cvoid}`; length comes from the stored `length` field.
  - `Base.eltype(::Array1D)` forwards to the `eltype` field. Inferred `setparam!` uses `anari_type(Array1D)` for `ANARI_ARRAY1D`.
- Reason: Keeps the simple copy model while reflecting ANARI’s runtime typing and still supporting ergonomic typed views when `eltype` is known.

8. Rendering/frame API
- Chosen: Synchronous helper.
- Plan: Implement `render!`, blocking wait helper using `ANARI_WAIT`, and frame mapping helper for channels like `"color"`.
- Reason: Minimal predictable baseline; async can be layered later.

## Rejected Alternatives (Brief)

1. Handle representation alternatives
- Rejected: Single parametric `Handle{T}`.
- Why rejected: Less readable API and weaker semantic type identities for end users.
- Note: `Array1D` also avoids type-parameter payload typing; optional Julia-side element typing lives in the `eltype` field instead.

2. Memory management alternatives
- Rejected: Manual release only.
- Why rejected: Too easy to leak resources.
- Rejected: `do`-block-first lifecycle.
- Why rejected: Unwanted usage style for this package.

3. Parameter API alternatives
- Rejected for now: Type-inferred `setparam!` as primary API.
- Why rejected: Explicit dtype path is lower risk for first implementation.
- Rejected for now: `setproperty!` syntax.
- Why rejected: Requires additional object/device coupling and more magic.

4. Type mapping alternative
- Rejected: Global `Dict{Type,ANARIDataType}` as primary mechanism.
- Why rejected: Less extensible and less idiomatic than dispatch-based trait methods.

5. Naming alternative
- Rejected: Expose C-style names as primary high-level API.
- Why rejected: Not idiomatic for Julia users.

6. Error handling alternatives
- Rejected: Silent/null return handling only.
- Why rejected: Fails late and is hard to debug.

7. Array API alternatives
- Rejected for now: Full managed shared-memory mapping API as default.
- Why rejected: Higher complexity and lifetime hazards for initial release.

8. Rendering alternatives
- Rejected for now: Async-first Task/Channel and callback-first APIs.
- Why rejected: More moving parts than needed for initial stable surface.

## Implementation Notes For Future Work

- Keep generated bindings untouched; extend wrappers in separate files included from `src/ANARI.jl`.
- Centralize pointer checks in small internal helpers:
  - `isnull(ptr)`
  - `require_nonnull(ptr, what)`
- Make release operations idempotent:
  - If pointer is null: return immediately.
  - If not null: call native release then set pointer to null.
- Ensure finalizers never throw; wrap release path in `try/catch` and log on failure.
- Keep status callback references alive to avoid GC invalidation while ANARI may call them.
- Add tests for:
  - Constructor null failure paths.
  - Double-release safety.
  - Basic `setparam!` with explicit dtype.
  - Array copy helper correctness.
  - Synchronous render wait/map flow.

## Suggested Delivery Order

1. Define core handle hierarchy and pointer safety helpers.
2. Implement constructors + exceptions + release/finalizer behavior.
3. Implement explicit `setparam!` and `commit!` wrappers.
4. Add `anari_type` trait methods for needed value types.
5. Add array copy helpers.
6. Add synchronous frame/render helpers.
7. Add status callback logging bridge.
8. Add tests and minimal usage examples.
