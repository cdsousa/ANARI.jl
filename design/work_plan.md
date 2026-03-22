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
- Update: Allow targeted parameterization where it materially improves safety/ergonomics; specifically `Array1D{T}` preserves element type for Julia-created arrays.
- Reason: Clear dispatch boundaries and idiomatic Julia type structure.

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
  - Implement helper constructors for 1D (and optionally 2D/3D) arrays that accept Julia arrays, create ANARI array objects, and copy payload.
  - Preserve element type in wrapper handles for Julia-originated arrays via `Array1D{T}`.
  - Store array element count on `Array1D` handles to support safe/ergonomic mapping.
  - Keep compatibility constructor for externally sourced/unknown-typed handles via `Array1D{Any}`.
  - Provide typed map behavior: `map_array(device, ::Array1D{T}) -> Vector{T}` using stored length metadata, with fallback `Ptr{Cvoid}` for `Array1D{Any}`.
- Reason: Keeps the initial simple/safe copy model while improving type safety and dispatch for mapping helpers.

8. Rendering/frame API
- Chosen: Synchronous helper.
- Plan: Implement `render!`, blocking wait helper using `ANARI_WAIT`, and frame mapping helper for channels like `"color"`.
- Reason: Minimal predictable baseline; async can be layered later.

## Rejected Alternatives (Brief)

1. Handle representation alternatives
- Rejected: Single parametric `Handle{T}`.
- Why rejected: Less readable API and weaker semantic type identities for end users.
- Clarification: Selective handle parameterization (for example `Array1D{T}`) is acceptable when it carries meaningful payload typing without replacing semantic handle names.

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
