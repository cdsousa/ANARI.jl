# Essential Steps to Wrap a C API like ANARI in Julia

Below is the distilled list of conceptually distinct problems any "good Julia wrapper" for an API like ANARI must solve, regardless of which specific library or design choices end up being used. The sections are grouped so the dependencies between them are visible.

---

## 1. Bind the C ABI

The foundation: get every C function, type, enum, and constant callable from Julia.

- Decide whether to hand-write `ccall`s or generate them (e.g. with `Clang.jl`'s `Generators`, as ANARI.jl does in `gen/`).
- Pin the binary: depend on a `_jll` package so the shared library and headers come from the same artifact and version.
- Treat the generated layer as **read-only** so re-running the generator is safe — a second, idiomatic layer is built on top.

---

## 2. Map Julia types ↔ ANARI types

ANARI carries explicit dtype tags (`ANARI_FLOAT32`, `ANARI_FLOAT32_VEC3`, `ANARI_ARRAY1D`, `ANARI_DEVICE`, …). The wrapper needs a bidirectional, extensible mapping:

- **Julia → ANARI**: a trait function (e.g. `anari_type(::Type{T})`) so users (and downstream packages) can register new conversions without monkey-patching.
- **ANARI → Julia**: a way to interpret bytes coming out of `anariMapFrame` / `anariMapArray` as a typed Julia view.
- Cover scalars, fixed-size vectors/matrices, strings, opaque object handles, and "unknown" (raw `Ptr{Cvoid}`).
- Decide a marshalling representation per dtype (`Ref{T}`, `Ref{NTuple{N,T}}`, `Ref{Cstring}`, …) and ensure the bytes match the C layout exactly.

---

## 3. Wrap opaque handles as first-class Julia types

The C API is "everything is an `ANARIObject*`". Julia users want types they can dispatch on.

- Define an abstract type hierarchy (`ANARIHandle` → `ANARIObjectHandle` → `World`, `Frame`, …) so you get:
  - readable signatures,
  - method dispatch (e.g. `setparam!(::Device, ::Frame, …)`),
  - safe-by-construction conversions (a `Frame` can only marshal as `ANARI_FRAME`).
- Use mutable structs so the pointer can be nulled on release and finalizers can attach.
- Store back-references to owning parents (`Device → Library`, `Object → Device`) so the GC reference graph alone enforces correct teardown order.

---

## 4. Handle lifetime / ownership / safety

The hardest part of any C-wrapping project. Several distinct sub-problems:

- **Construction**: every `anariNew*` can return `NULL`; the wrapper must check and throw.
- **Destruction policy**: pick a model — finalizer-only, manual-only, `do`-block scope, or hybrid. ANARI.jl uses *idempotent `release!` + finalizer*, which gives both deterministic and best-effort cleanup.
- **Idempotence**: `release!` must be safe to call twice, after GC, in any order.
- **Use-after-free protection**: every public function should reject a null/released handle with a clear `ArgumentError` instead of crashing the runtime.
- **No-throw across the FFI boundary**: finalizers and C-callable trampolines must `try/catch` everything; throwing into C is undefined behaviour.
- **GC pinning during calls**: any Julia-owned buffer or `Ref` whose address is passed to C must be kept alive across the call (`GC.@preserve`).
- **Reference counting**: ANARI uses `anariRetain`/`anariRelease`. If you ever expose retain semantics, decide where the Julia side participates.

---

## 5. Bridge callbacks from C back into Julia

ANARI's status callback is the canonical example, but the pattern recurs (deleter callbacks for shared memory, etc.).

- Use `@cfunction` trampolines stored in module-level `const`s so the function pointer never moves or gets collected.
- Use the C `userPtr` slot to carry a pinned Julia object (typically a `Ref{Any}` wrapping a closure) via `unsafe_pointer_to_objref`.
- Ensure the closure's lifetime is tied to a Julia owner (e.g. the `Library`) so it outlives every possible C-side invocation.
- Catch every exception inside the trampoline, log it, and never let it propagate into C code.

---

## 6. Translate the configure/commit/execute model

ANARI is a "set parameters → commit → execute" API. The wrapper must expose this faithfully:

- A `setparam!` / `commit!` / `release!` verb set with `!` mutating-naming.
- Avoid auto-committing on `setparam!` — losing the explicit commit boundary breaks performance assumptions and deferred-parameter semantics.
- Provide an inferred-dtype overload (`setparam!(dev, obj, name, value)`) for ergonomics and an explicit-dtype overload (`setparam!(dev, obj, name, dtype, value)`) for control.

---

## 7. Bulk-data API

Renderers consume vertex buffers, indices, textures, volumes, etc. The wrapper must offer at least one model, ideally with a clear evolution path:

- **Copy model** (simplest): user passes a Julia array → wrapper allocates an ANARI-owned buffer, maps it, copies, unmaps.
- **Shared-memory model**: pass `appMemory` non-null with a deleter callback so ANARI reads directly from Julia memory (requires careful lifetime management — see §4 and §5).
- **Mapped-write model**: `anariMapParameterArray*` for streaming updates.
- Pick column-major orientation that matches both Julia's `Array` layout and ANARI's "first dimension varies fastest" rule.
- Respect that ANARI arrays are runtime-typed: don't try to make them `Array1D{T}` parametric unless you accept a type explosion.

---

## 8. Asynchronous rendering and synchronization

ANARI's render is async (`anariRenderFrame` + `anariFrameReady`):

- Provide synchronous helpers as the baseline (`render!`, `wait_frame!`, `render_and_wait!`).
- Decide whether to layer `Task`/`Channel`-based async on top, exploit Julia's cooperative scheduling, or stay sync-only.
- Map `anariMapFrame` / `anariUnmapFrame` to a safe Julia idiom — the returned pointer aliases device memory and must be unmapped before reuse, so the API should make that lifecycle explicit (or wrap it in a `do`-block / context manager).
- Document the threading rules: ANARI is "thread-safe with external synchronization" by default. If you expose multi-threading, you own that contract.

---

## 9. Errors and diagnostics

Two distinct channels:

- **Hard errors** (null returns, illegal dtypes, use-after-release): map to Julia exceptions (`ErrorException`, `ArgumentError`, `MethodError`).
- **Runtime diagnostics** (status callback severities → fatal/error/warning/perf-warning/info/debug): map to Julia `Logging` macros so users can route them through any `AbstractLogger`.
- Be explicit about which condition raises what; users will rely on exception types for control flow.

---

## 10. Introspection and extensions

ANARI is an extension-driven API: device subtypes, object subtypes, parameter metadata, KHR/vendor extensions.

- Wrap `anariGetDeviceSubtypes`, `anariGetDeviceExtensions`, `anariGetObjectSubtypes`, `anariGetObjectInfo`, `anariGetParameterInfo`, `anariGetProperty`.
- Provide Julia-friendly forms — usually `Vector{String}`, `NamedTuple`, or `Dict` — built on top of the raw C arrays of C-strings.
- Consider an extension-capability check API that returns a typed `Bool` so users can branch on capabilities portably.

---

## 11. Naming and API surface conventions

- High-level uses Julia idioms: `Device(...)`, `World(...)`, `setparam!`, `commit!`, `render!`, `Base.eltype`, `Base.size`.
- Low-level keeps the C names unchanged so users who need the raw API don't have to fight a translation table.
- Re-export only the high-level names; reach for `ANARI.LibANARI.X` for raw constants and entry points.
- Define overloads of `Base` functions (`size`, `length`, `eltype`, possibly `show`) so wrapped objects behave like first-class Julia values in the REPL.

---

## 12. Packaging, testing, and reproducibility

- `Project.toml` declares `_jll` and any runtime deps (`Logging`, `CEnum`, …); `compat` bounds keep the package buildable.
- A regeneration script (`gen/`) lets you bump the SDK version without manual edits.
- Tests should cover:
  - constructor-failure paths (null returns),
  - idempotent release / double-release,
  - explicit and inferred `setparam!`,
  - array round-trip (allocate, map, compare, unmap),
  - synchronous render + map/unmap,
  - status-callback dispatch,
  - any thread-safety guarantees you advertise.
- An end-to-end example (e.g. a small triangle rendered to PNG) doubles as documentation and a regression smoke test.

---

## 13. Future-proofing hooks

Things worth designing in early, even if not implemented in the first cut:

- A property/keyword-style sugar layer (`obj.position = (0,0,3)`) on top of `setparam!` — possible by overloading `Base.setproperty!`.
- Higher-rank `mapAsArray` views (`reshape`, `transpose`, GPU array compatibility).
- Integration with Julia's array ecosystem: `AbstractArray` interfaces for `Array1D/2D/3D`, `Tables.jl` adapters for vertex buffers, `ColorTypes`/`Images` for color channels.
- An async layer that exposes `Task`-based futures for `anariRenderFrame`.
- Distributed/MPI extension support (KHR extensions) once the synchronous core is stable.

---

## TL;DR — the irreducible cores

If you only remember six concerns, they are:

1. **Bind the ABI** (and keep the binding regenerable).
2. **Map types both directions** (Julia ↔ ANARI dtypes).
3. **Wrap handles** as a Julia type hierarchy.
4. **Manage lifetimes** safely (idempotent release + finalizers + null-checks + GC pinning + no-throw-into-C).
5. **Bridge callbacks** with `@cfunction` and pinned closures.
6. **Expose the API idiomatically** (mutating verbs, inferred + explicit overloads, `Base` integration, errors via exceptions, diagnostics via `Logging`).

Everything else — array models, async, introspection, extensions, packaging — is a refinement of these.
