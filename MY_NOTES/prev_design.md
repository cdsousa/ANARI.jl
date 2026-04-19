# ANARI.jl

This document describes the architectural and detailed design of the
`ANARI.jl` Julia package. It covers the package layout, the responsibilities
of each module, the type hierarchy, the lifetime/ownership model, the
parameter and rendering APIs, the data marshalling rules, and the diagnostics
bridge.

For a primer on the underlying ANARI API, see [about_ANARI.md](about_ANARI.md).

---

## Layers architecture

The package is organized in two cleanly separated layers, a low-level FFI layer and a high-level idiomatic layer.
They depend on an external JLL package, `ANARI_SDK_jll`, for the C header and shared library.

###  Low-level FFI layer: `LibANARI`

A single file `src/LibANARI.jl` which is auto-generated from the C99 header `anari/anari.h` shipped by
`ANARI_SDK_jll` using *Clang.jl*'s `Generators` interface. It contains low-level bindings for
every C function, every opaque handle typedef, every enum, and every constant.
This file MUST NOT be hand-edited. All idiomatic behavior lives strictly in the higher layer.

### High-level idiomatic layer: `ANARI`

Entry point is file `src/ANARI.jl` that loads the low-level layer and
  includes source files for the various wrapper aspects.


---

## ANARI Object hierarchy

```
ANARIHandle (abstract)
├── Library
├── Device
└── ANARIObjectHandle (abstract)
    ├── World
    ├── Frame
    ├── Camera
    ├── Renderer
    ├── Geometry
    ├── Material
    ├── Surface
    ├── Group
    ├── Instance
    ├── Light
    ├── Sampler
    ├── SpatialField
    ├── Volume
    ├── Array1D
    ├── Array2D
    └── Array3D
```

Design notes:

- `ANARIHandle` is the package-wide root abstract type. It expresses
  "anything that owns an ANARI native pointer".
- `Library` and `Device` are siblings (not under `ANARIObjectHandle`) because
  their lifecycle and creation API differ from object handles: a `Library`
  has no owning device, and a `Device` is owned by a `Library` rather than by
  another `Device`.
- `ANARIObjectHandle` groups every object that is created on a `Device` and
  that is destroyed via `anariRelease(device, object)`. Concrete subtypes
  share an identical `(ptr, device)` shape and identical `release!`
  semantics, so the type itself acts as a dispatch trait used both by
  `release!(::ANARIObjectHandle)` and by `setparam!` argument typing.
- Concrete handle types are mutable `struct`s so that `release!` can null
  the `ptr` field and so that finalizers can be attached. They are not
  parametric: `Array1D` aligns with ANARI's runtime model where the element
  datatype and length are runtime values, not compile-time parameters.
- Each native handle has a typed pointer field so the compiler/IDE can show
  the underlying ANARI type (e.g. `Frame.ptr::LibANARI.ANARIFrame`).

### 2.1 `Library`

```
mutable struct Library <: ANARIHandle
    ptr::LibANARI.ANARILibrary
    status_callback::LibANARI.ANARIStatusCallback
    status_user_data::Ptr{Cvoid}
    status_user_data_ref::Any
end
```

Holds, in addition to the native `ANARILibrary` handle, the raw status
callback function pointer that was registered with the library and a Julia
`Ref` keeping any user-supplied closure alive (`status_user_data_ref`). This
prevents the GC from reclaiming a callback object that the C runtime may
invoke at any time.

### 2.2 `Device`

```
mutable struct Device <: ANARIHandle
    ptr::LibANARI.ANARIDevice
    library::Library
end
```

Stores a back-reference to the `Library` it was created from. The reference
keeps the library alive at least as long as the device, satisfying the
shutdown invariant that devices must be released before their library is
unloaded.

### 2.3 Generic object handles

`World`, `Frame`, `Camera`, `Renderer`, `Geometry`, `Material`, `Surface`,
`Group`, `Instance`, `Light`, `Sampler`, `SpatialField`, `Volume` are all
defined by the `@define_object_handle` macro in `handles.jl`:

```
mutable struct <Name> <: ANARIObjectHandle
    ptr::<NativePtrType>
    device::Device
    function <Name>(ptr::<NativePtrType>, device::Device)
        _require_nonnull(ptr, "<creator name>")
        obj = new(ptr, device)
        return _attach_release_finalizer!(obj)
    end
end
```

The macro guarantees:
- A null-checking inner constructor that throws `ErrorException` on failure.
- A finalizer that calls `release!`.
- A back-reference to the owning `Device`, used both for native release and
  to satisfy ANARI's "device must outlive its objects" rule.

### 2.4 Array handles

`Array1D`, `Array2D`, `Array3D` extend `ANARIObjectHandle` but add fields to
record the runtime size and the Julia element type used to interpret mapped
memory:

- `Array1D`: `length::UInt64`, `eltype::Type`.
- `Array2D`: `dims::NTuple{2,UInt64}`, `eltype::Type`. `Base.size` returns
  the dims as `Int` tuple.
- `Array3D`: `dims::NTuple{3,UInt64}`, `eltype::Type`. `Base.size` returns
  the dims as `Int` tuple.

`eltype` defaults to `Any` (raw-pointer constructors) and is set to the
source vector/matrix element type by the `new_arrayND` helpers. Vectors of
object handles store `LibANARI.ANARIObject` as `eltype`. `Base.eltype` is
specialised in `arrays.jl` to return that field, so `eltype(array)` works as
in idiomatic Julia.

The dimension order follows ANARI: `dims[1]` varies fastest in linear
memory, matching Julia's column-major layout, so a Julia `Matrix` flattened
with `vec(data)` corresponds 1:1 with the bytes ANARI sees.

---

## 3. Lifetime, ownership, and safety model

### 3.1 Pointer-safety helpers (private)

`handles.jl` defines two internal helpers used everywhere:

- `_isnull(ptr::Ptr) = ptr == C_NULL`
- `_require_nonnull(ptr::Ptr, what::AbstractString)` — throws
  `ErrorException("\$what returned a null handle")` if the pointer is null;
  used by every constructor right after the matching `anariNew*` call.

Two more helpers guard against use-after-release on the long-lived handles:

- `_require_live_library(library::Library)` — throws `ArgumentError` if
  `library.ptr == C_NULL`.
- `_require_live_device(device::Device)` — throws `ArgumentError` if
  `device.ptr == C_NULL`.

The same null-pointer check is repeated inline in the `setparam!`,
`commit!`, `render!`, `wait_frame!`, `map_frame`, `unmap_frame`,
`map_array`, `unmap_array`, and `new_arrayND` entry points so that any
operation against a released handle fails predictably with `ArgumentError`
rather than crashing the runtime.

### 3.2 Construction protocol

Every handle type has a uniform construction protocol:

1. Call the corresponding `anariNew*` (or `anariLoadLibrary` /
   `anariNewDevice`) entry point.
2. Pass the returned native pointer through the wrapper's inner
   constructor, which:
   - Calls `_require_nonnull(ptr, "<C function name>")`. The C function
     name is propagated into the error message so that diagnostics point at
     the actual failing creator (`"anariNewWorld returned a null handle"`,
     etc.).
   - Stores the pointer plus contextual fields (`device`, `library`,
     `length`, `dims`, `eltype`, status-callback bookkeeping for
     `Library`).
   - Calls `_attach_release_finalizer!(obj)`.

User-facing convenience constructors layer on top:

- `Library(name::AbstractString; status_logging::Bool=false)` — when
  `status_logging` is `true`, registers the built-in C-trampoline that
  bridges to `Logging`.
- `Library(name::AbstractString, status_callback::Function)` — registers
  the user-callback C-trampoline; the closure is wrapped in a `Ref{Any}`,
  pinned in `status_user_data_ref`, and its address passed as `userPtr`.
- `Device(library::Library, subtype::AbstractString)`.
- `World(device)`, `Frame(device)`, `Surface(device)`, `Group(device)` —
  parameterless constructors generated by `@define_device_handle_constructor`.
- `Camera(device, subtype)`, `Renderer(device, subtype)`,
  `Geometry(device, subtype)`, `Material(device, subtype)`,
  `Instance(device, subtype)`, `Light(device, subtype)`,
  `Sampler(device, subtype)`, `SpatialField(device, subtype)`,
  `Volume(device, subtype)` — generated by
  `@define_subtyped_device_handle_constructor`. Each calls
  `_require_live_device(device)` first.

### 3.3 Release protocol

A single mutating verb, `release!`, owns deallocation. Three method shapes
exist, one per handle category:

- `release!(library::Library)` → calls `LibANARI.anariUnloadLibrary` and
  resets all four `Library` fields (pointer, callback, user data, ref).
- `release!(device::Device)` → calls `LibANARI.anariRelease(device.ptr,
  device.ptr)` (devices release themselves) and nulls `device.ptr`.
- `release!(object::ANARIObjectHandle)` → if the owning device is still
  alive, calls `LibANARI.anariRelease(device.ptr, object.ptr)`; then nulls
  `object.ptr`. The device-alive guard prevents calling release on a freed
  device, which would be undefined behaviour.

Invariants enforced by every `release!` method:

- **Idempotent**: an already-released handle returns immediately. The tests
  exercise this by calling `release!` twice (`handles_test.jl`).
- **Null after release**: `obj.ptr == C_NULL` always holds after a
  successful `release!`. This is the precondition every later operation
  checks against.
- **No throw**: the finalizer wraps `release!` in a `try/catch` so that
  garbage-collection time exceptions cannot crash the Julia process.

### 3.4 Finalizer wiring

`_attach_release_finalizer!(obj)` registers a finalizer that simply calls
`release!(handle)` inside `try/catch`. Combined with the idempotent
`release!`, this gives:

- Deterministic release when the user wants it (`release!(obj)`), and
- Best-effort release when the wrapper is collected without explicit
  cleanup (typical for short scripts and REPL exploration).

Lifetime ordering is enforced by Julia's reference graph: each object
handle holds a strong reference to its `Device`, and the device holds a
strong reference to its `Library`. Therefore, even if the user drops their
own references in the wrong order, the GC still releases child objects
before their parent device, and the device before its library.

### 3.5 Why mutable structs

Mutability is required because `release!` writes a new pointer
(`Ptr{Cvoid}(C_NULL)`) into the `ptr` field, and finalizers attach to
mutable objects. The cost (one heap allocation per handle) is negligible
compared to the cost of the underlying ANARI call.

---

## 4. Parameter API

`parameters.jl` implements the explicit-dtype API; `anari_type.jl` adds a
second, type-inferred overload built on top of it.

### 4.1 Explicit form

```
setparam!(device::Device,
          object::Union{Device, ANARIObjectHandle},
          name::AbstractString,
          dtype::LibANARI.ANARIDataType,
          value)
```

Steps:
1. Validate that `device.ptr` and `object.ptr` are non-null (otherwise
   `ArgumentError`).
2. Convert `object` to its native `ANARIObject` pointer via
   `_as_anari_object(object)`. This helper is defined for both `Device` (so
   a device may be the target of `setparam!`) and `ANARIObjectHandle`
   subtypes.
3. Marshal `value` into a stack-allocated `Ref` of the correct C
   representation through `_prepare_parameter_ref(dtype, value)`.
4. Wrap the call to `LibANARI.anariSetParameter` inside `GC.@preserve value
   value_ref` so neither the Julia value nor the temporary Ref can be moved
   or collected while ANARI is reading the bytes via the raw pointer.
5. Return `object` to enable a fluent style.

### 4.2 Marshalling rules in `_prepare_parameter_ref`

Supported `ANARIDataType` → Julia mapping:

| ANARI dtype           | Julia argument                  | Native form                       |
| --------------------- | ------------------------------- | --------------------------------- |
| `ANARI_STRING`        | `AbstractString`                | `Ref{Cstring}` (via `String`)     |
| `ANARI_BOOL`          | `Bool`-like                     | `Ref{UInt32}` (1/0)               |
| `ANARI_INT32`         | integer                         | `Ref{Int32}`                      |
| `ANARI_UINT32`        | unsigned integer                | `Ref{UInt32}`                     |
| `ANARI_FLOAT32`       | real                            | `Ref{Float32}`                    |
| `ANARI_FLOAT64`       | real                            | `Ref{Float64}`                    |
| `ANARI_UINT32_VEC2/3` | `NTuple{N, UInt32}`             | `Ref{NTuple{N, UInt32}}`          |
| `ANARI_FLOAT32_VEC2/3/4` | `NTuple{N, Float32}`         | `Ref{NTuple{N, Float32}}`         |
| `ANARI_DATA_TYPE`     | `ANARIDataType` (or convertible)| `Ref{ANARIDataType}`              |
| Object dtypes         | `ANARIHandle`                   | `Ref{ANARIObject}` of `_as_anari_object(value)` |

"Object dtypes" are the set checked by `_check_object_dtype`:
`ANARI_ARRAY1D/2D/3D`, `ANARI_DEVICE`, `ANARI_OBJECT`, `ANARI_CAMERA`,
`ANARI_FRAME`, `ANARI_GEOMETRY`, `ANARI_GROUP`, `ANARI_INSTANCE`,
`ANARI_LIGHT`, `ANARI_MATERIAL`, `ANARI_RENDERER`, `ANARI_SAMPLER`,
`ANARI_SPATIAL_FIELD`, `ANARI_SURFACE`, `ANARI_VOLUME`, `ANARI_WORLD`.
For these dtypes, the value MUST be an `ANARIHandle`, otherwise
`ArgumentError` is thrown.

Any unsupported dtype raises `ArgumentError("unsupported ANARIDataType in
setparam!: …")`. The set is intentionally narrow: it covers the parameter
shapes used by the wrappers and the example, and is meant to grow
in step with the high-level API rather than ahead of it.

### 4.3 Inferred form (built on the trait)

```
setparam!(device, object, name::AbstractString, value)
```

calls

```
setparam!(device, object, name, anari_type(typeof(value)), value)
```

If `typeof(value)` has no `anari_type` method, Julia raises a `MethodError`
at the dispatch site, which is the desired "fail fast" outcome; the test
suite locks this in (`@test_throws MethodError ANARI.setparam!(…, (32, 32))`).

### 4.4 Commit

```
commit!(device::Device, object::Union{Device, ANARIObjectHandle})
```

Same null-check protocol as `setparam!`, then forwards to
`LibANARI.anariCommitParameters`. ANARI's "set then commit" contract is
preserved verbatim — the wrapper does not auto-commit on `setparam!`, so
the user retains full control of the commit boundary.

---

## 5. `anari_type` trait

`anari_type` is a `function`-defined trait (Julia method dispatch) rather
than a `Dict`, so downstream packages can extend it without modifying
`ANARI.jl`:

```
function anari_type end
anari_type(::Type{T}) -> ANARIDataType
```

Built-in methods (in `anari_type.jl`):

- Strings: `AbstractString` → `ANARI_STRING`.
- Scalars: `Bool`, `Int32`, `UInt32`, `Float32`, `Float64`.
- Tuples used for vector dtypes: `NTuple{2,UInt32}`, `NTuple{3,UInt32}`,
  `NTuple{2,Float32}`, `NTuple{3,Float32}`, `NTuple{4,Float32}`.
- Every wrapper handle type maps to its corresponding object dtype, e.g.
  `anari_type(Device) == ANARI_DEVICE`,
  `anari_type(World)  == ANARI_WORLD`,
  `anari_type(Array1D) == ANARI_ARRAY1D`, …

The trait is also consumed by `new_arrayND` to derive the per-element
ANARI dtype from the source vector's `eltype`, so users do not have to
state the dtype twice.

Extension contract for downstream packages: defining
`anari_type(::Type{MyVec3}) = LibANARI.ANARI_FLOAT32_VEC3` together with a
`Base.convert(NTuple{3,Float32}, ::MyVec3)` is enough to make the inferred
`setparam!` accept that type without further changes.

---

## 6. Array API

`arrays.jl` implements the "thin copy" model selected in the work plan:
ANARI owns the storage, and the helpers copy Julia data into it under a
short-lived `anariMapArray` / `anariUnmapArray` window.

### 6.1 Construction helpers

- `new_array1d(device, data::AbstractVector{T})`
- `new_array2d(device, data::AbstractMatrix{T})`
- `new_array3d(device, data::AbstractArray{T,3})`

Common pattern, shared by all three (and by both the
`T<:ANARIObjectHandle` and `T` non-handle method specialisations):

1. Validate that `device.ptr` is non-null.
2. Validate dimensions (`length` for 1D; positive `size` for 2D/3D —
   `ArgumentError` if any dimension is zero).
3. For object-handle inputs, materialise an `LibANARI.ANARIObject[]`
   buffer in column-major order (the for-loop order is `for k, j, i` so
   that `i` varies fastest); each element handle is also checked for
   non-null. For value inputs, `flat = vec(collect(data))`.
4. Allocate the ANARI array via `LibANARI.anariNewArray1D/2D/3D` with
   `appMemory = NULL` (device-managed memory) and the ANARI dtype derived
   from `anari_type(T)` (or `LibANARI.ANARI_OBJECT`-style for handles via
   `anari_type` on the handle type).
5. Wrap the resulting pointer in `Array1D/2D/3D`, recording `length` or
   `dims` and the `eltype` (the Julia element type for values, or
   `LibANARI.ANARIObject` for handle vectors).
6. Map the array, `unsafe_copyto!` the prepared buffer into the mapped
   region (typed `Ptr{T}` for values, `Ptr{LibANARI.ANARIObject}` for
   handles), and unmap inside a `try/finally` so the array is always
   unmapped even if the copy throws.
7. Return the wrapped array.

### 6.2 Mapping for inspection

`map_array(device, array)` is defined for each of the three array types.
It validates pointers, calls `LibANARI.anariMapArray`, then:

- If `array.eltype === Any`, returns the raw `Ptr{Cvoid}` so the user can
  do their own interpretation (the typical case for arrays not produced
  by `new_arrayND`).
- Otherwise wraps the mapped region with `unsafe_wrap`:
  - 1D → `Vector{T}` of length `array.length`.
  - 2D → `Matrix{T}` of shape `(dims[1], dims[2])`.
  - 3D → `Array{T,3}` of shape `(dims[1], dims[2], dims[3])`.

The returned wrapper aliases the mapped memory; the user MUST call
`unmap_array(device, array)` (or `anariUnmapArray` directly) before
re-using the array elsewhere. The example in `examples/sample.jl`
demonstrates the same aliasing pattern for `map_frame` outputs (`reshape`
and `transpose` over the mapped pointer).

### 6.3 Raw-pointer constructor

`Array1D(ptr, device, length=0, eltype=Any)` (and the equivalent for 2D/3D)
exists to wrap a pointer obtained outside the helpers — for example by
calling `LibANARI.anariNewArray1D` directly. In that case `eltype` defaults
to `Any` and `map_array` returns a raw `Ptr{Cvoid}`. The pattern is
exercised in `handles_test.jl` to verify the fallback path.

---

## 7. Rendering and frame API

`render.jl` implements the synchronous baseline.

### 7.1 Functions

- `render!(device, frame)` → calls `anariRenderFrame`. Returns the
  `frame` so the call can be chained.
- `wait_frame!(device, frame; mode=ANARIWaitMask(ANARI_WAIT))` → calls
  `anariFrameReady`. The default mode blocks until the frame is ready.
  Returns the `Cint`-style readiness value coming back from ANARI.
- `render_and_wait!(device, frame; mode=...)` → `render!` followed by
  `wait_frame!`. The single most common high-level recipe.
- `map_frame(device, frame, channel="color")` → calls `anariMapFrame`,
  passing `Ref{UInt32}` and `Ref{ANARIDataType}` placeholders for the
  output `width`, `height`, and `pixel_type`. Returns a 4-tuple
  `(data_ptr, width, height, pixel_type)`. Throws `ErrorException` if
  ANARI returns a null pointer.
- `unmap_frame(device, frame, channel="color")` → forwards to
  `anariUnmapFrame`.

Each function performs the device/frame null-pointer guard up front, so
operating on a released frame fails with `ArgumentError`, not a crash.

### 7.2 Asynchrony

The wrappers expose only the synchronous waiting primitive; there is no
`Task`/`Channel` orchestration in this layer. Callers that need
cooperative scheduling can spawn a `Task` themselves, since
`render!`/`wait_frame!` are perfectly composable. This deliberately
mirrors the work-plan decision to ship a "minimal predictable baseline"
first.

### 7.3 Pixel format selection

Selecting an observable pixel format is a `setparam!` call on the frame
with the channel name (e.g. `"channel.color"`) and an `ANARI_DATA_TYPE`
value such as `ANARI_UFIXED8_RGBA_SRGB`, exactly as in the C API. The
example shows the canonical pattern.

---

## 8. Status-callback bridge

`status.jl` integrates the ANARI status callback with Julia's `Logging`.

### 8.1 Severity mapping

| ANARI severity                    | Julia macro |
| --------------------------------- | ----------- |
| `ANARI_SEVERITY_FATAL_ERROR`      | `@error`    |
| `ANARI_SEVERITY_ERROR`            | `@error`    |
| `ANARI_SEVERITY_WARNING`          | `@warn`     |
| `ANARI_SEVERITY_PERFORMANCE_WARNING` | `@warn`  |
| `ANARI_SEVERITY_INFO`             | `@info`     |
| `ANARI_SEVERITY_DEBUG` (and other)| `@debug`    |

The formatted log message includes severity name, severity numeric value,
status code, and source-type code, followed by the original ANARI
message. `_severity_name` provides human-readable severity strings.

### 8.2 C trampolines

Two `@cfunction`-built trampolines are precomputed at module load time and
held in `const` globals so that the compiled function pointers stay valid
for the entire process lifetime:

- `_STATUS_CALLBACK_PTR` — calls `_status_callback`, which simply
  formats the ANARI status message and emits it through `Logging`. Used
  when the user opts into `status_logging=true` on `Library`.
- `_STATUS_CALLBACK_USER_PTR` — calls `_status_callback_user`, which
  unwraps the `userPtr` (a pinned `Ref{Any}` holding a Julia callback)
  via `unsafe_pointer_to_objref`, then forwards through
  `_invoke_user_status_callback`. Used by
  `Library(name, status_callback::Function)`.

`_invoke_user_status_callback` accepts callbacks with either signature
`(message)` or `(severity, code, source_type, message)` (selected via
`applicable`). If the user callback is not callable with either
signature, an `ArgumentError` is raised (and caught by the trampoline,
which logs the failure and falls back to the default logging path so the
runtime is not destabilised).

### 8.3 Lifetime guarantees for callbacks

- The trampoline `Ptr{Cvoid}` is captured into a module-level `const`, so
  it can never be GC'd.
- The user callback is wrapped in a `Ref{Any}` and stored on the
  `Library` object as `status_user_data_ref`. As long as the `Library`
  is alive, the closure cannot be collected, even though only its raw
  address is known to the C side.
- `release!(library::Library)` deliberately resets `status_user_data_ref
  = nothing` after `anariUnloadLibrary`, so the closure becomes eligible
  for GC once ANARI guarantees it will not call back any more.
- `_status_callback_user` further wraps the user-callback invocation in a
  `try/catch`, logs any thrown exception via `@error`, and then
  defaults to the standard logging path — this preserves the
  no-throw-into-C contract.

---

## 9. End-to-end usage flow

The recommended idiomatic flow (mirrored by `examples/sample.jl` and the
test suite) is:

1. `lib = Library("helide")` (or any backend name supported by the
   installed `ANARI_SDK_jll`); optionally
   `Library(name; status_logging=true)` or
   `Library(name, my_callback)` for diagnostics.
2. `dev = Device(lib, "default")`.
3. Build the scene with constructors (`Camera(dev, "perspective")`,
   `Renderer(dev, "default")`, `Geometry(dev, "triangle")`,
   `Material(dev, "matte")`, `Surface(dev)`, `Group(dev)`,
   `Instance(dev, "transform")`, `World(dev)`, …).
4. Upload bulk data with `new_array1d/2d/3d(dev, data)` and reference the
   resulting arrays with `setparam!(dev, object, name, array)`.
5. Configure each object with `setparam!` (inferred or explicit) and
   `commit!` after edits.
6. Create the `Frame`, set `size`, `world`, `camera`, `renderer`, and the
   desired `channel.*` formats, and `commit!` it.
7. `render_and_wait!(dev, frame)`.
8. `map_frame(dev, frame, "channel.color")` → consume the pixels →
   `unmap_frame(dev, frame, "channel.color")`.
9. `release!` everything in any order (parent references keep the
   ordering correct), or simply let GC do it. Releases are idempotent.

---

## 10. Error model summary

| Failure                                       | Reported as                |
| --------------------------------------------- | -------------------------- |
| `anariLoadLibrary`/`anariNewDevice`/`anariNew*` returns null | `ErrorException` with the C-function name |
| Constructor call with already-released parent | `ArgumentError`            |
| Operation on released handle (`setparam!`, `commit!`, `render!`, `wait_frame!`, `map_frame`, `unmap_frame`, `map_array`, `unmap_array`) | `ArgumentError` |
| `setparam!` with unsupported ANARI dtype      | `ArgumentError`            |
| Inferred `setparam!` for a value with no `anari_type` method | `MethodError` |
| Object dtype with non-handle value            | `ArgumentError`            |
| `anariMapFrame` / `anariMapArray` returns null| `ErrorException`           |
| ANARI runtime status events                   | Routed to `Logging` with severity-mapped macros |
| User status-callback throwing                 | Caught; `@error`-logged; fall back to default logging |

Every error path is exercised by the test suite under `test/`.

---

## 11. Testing

`test/runtests.jl` includes:

- `handles_test.jl` — null constructors, idempotent `release!`, full
  parameter/commit flow, scene-object constructors, sampler/spatial
  field/volume constructors, render+wait flow, frame map/unmap flow, 1D
  array copy round-trip, and 2D/3D array copy round-trips with both the
  helper-built and raw-pointer constructors.
- `anari_type_test.jl` — mapping of every supported Julia type to the
  expected `ANARIDataType`, plus the inferred `setparam!` happy path and
  the `MethodError` path.
- `status_test.jl` — covers the status-callback bridge (default logging
  and user-callback dispatch).
- `libanari_test.jl` — smoke tests against the generated low-level
  bindings, ensuring the FFI surface is present and callable.

The tests assume an ANARI backend named `"helide"` is available through
`ANARI_SDK_jll` at test time; they double as executable documentation of
the wrapper contracts described above.

---

## 12. Extensibility guidelines

- **New object families**: extend `handles.jl` with a new
  `@define_object_handle` line, add the matching constructor macro line,
  add an `anari_type` method, and (if relevant) extend
  `_check_object_dtype`.
- **New value types**: define `anari_type(::Type{T})` and add a branch
  in `_prepare_parameter_ref` that marshals to the matching ANARI memory
  layout. Keep `Ref`-allocations small and avoid heap allocation in the
  hot path.
- **Higher-level abstractions**: stay above the line — never edit
  `LibANARI.jl`. Compose new files into `src/` and `include` them from
  `src/ANARI.jl` after their dependencies (the include order in §1.2 is
  the contract).
- **Async or distributed extensions**: layer `Task`/`Channel` /
  KHR-extension support on top of the existing synchronous primitives.
  The wrappers were designed so that the synchronous core is itself a
  thin pass-through to ANARI and therefore composes well with Julia's
  cooperative scheduling.
