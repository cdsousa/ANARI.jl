# ANARI

## What ANARI is

ANARI (Analytic Rendering Interface) is a Khronos standard C99 API for high-level rendering of 3D surfaces and volumes through interchangeable rendering backends ("devices").  
Instead of coding directly against a specific renderer, GPU API, or vendor SDK, an application talks to ANARI objects and parameters; the chosen backend implements the rendering details.

From an application perspective, ANARI is a portable "rendering contract":

- You describe scene data, camera, renderer settings, frame configuration, and output channels.
- The backend decides how to execute (rasterization, path tracing, CPU/GPU/distributed, etc.).
- You can query capabilities and extensions at runtime and adapt behavior without rewriting renderer-specific code.

Full specification available at: [ANARI 1.1 Specification](https://registry.khronos.org/ANARI/specs/1.1/ANARI-1.1.html)
SDK available at: [ANARI SDKs](https://github.com/KhronosGroup/ANARI-SDK)

## Architecture principles of the API

## C99 front-end + runtime-loaded backends

ANARI is defined as a C99 API (`anari.h`) with a common front-end and dynamically loadable backend libraries:

- `anariLoadLibrary()` / `anariUnloadLibrary()` manage a vendor library.
- `anariNewDevice()` / `anariNewInitializedDevice()` instantiate a specific device subtype.
- Device implementations are separable from the application and from the ANARI header/front-end.

This design favors language interoperability and backend portability.

## Opaque handles and object-based scene model

All runtime entities are opaque handles: `ANARIObject` as the generic base handle, plus typed handles such as `ANARIDevice`, `ANARIWorld`, `ANARIGeometry`, `ANARIFrame`, etc.  
Applications construct a scene via object composition rather than backend-specific structs.

Common object families exposed in `anari.h` include:

- Scene/building blocks: `World`, `Instance`, `Group`, `Surface`, `Volume`, `Light`
- Shading/data: `Geometry`, `Material`, `Sampler`, `SpatialField`
- Render control: `Camera`, `Renderer`, `Frame`
- Data containers: `Array1D`, `Array2D`, `Array3D`

## Parameterized, mostly write-only API with explicit commit

Objects are configured through named parameters (`anariSetParameter()`) and finalized with `anariCommitParameters()`.

Important behavior:

- Parameter changes do not affect rendering until committed.
- Parameter queries are intentionally not part of the model (to avoid constraining backend implementations, including distributed ones).
- Unknown/unsupported parameters can be ignored (implementations may warn).
- `anariUnsetParameter()` / `anariUnsetAllParameters()` reset configuration (also commit-gated).

## Introspection and extensions are first-class

ANARI relies on runtime introspection for portability:

- Enumerate device subtypes/extensions (`anariGetDeviceSubtypes()`, `anariGetDeviceExtensions()`).
- Discover object subtypes and parameter metadata (`anariGetObjectSubtypes()`, `anariGetObjectInfo()`, `anariGetParameterInfo()`).
- Query dynamic values/properties with `anariGetProperty()` and wait policies.

Extensions are capability additions (never reductions), including KHR and vendor extensions.

## Asynchronous rendering and explicit synchronization model

Frame rendering is asynchronous:

- Start: `anariRenderFrame()`
- Poll/block: `anariFrameReady(..., ANARI_NO_WAIT | ANARI_WAIT)`
- Optional cancel request: `anariDiscardFrame()`
- Read outputs by mapping channels: `anariMapFrame()` / `anariUnmapFrame()`

Threading model highlights:

- API calls are thread-safe only with external synchronization when calls share objects (by default, same-device calls must be synchronized).
- Some synchronization rules can be relaxed via `KHR_DEVICE_SYNCHRONIZATION`.

## Explicit ownership and lifetime

ANARI uses reference counting:

- `anariRetain()` increments public ownership.
- `anariRelease()` decrements ownership.
- Releasing your reference does not require the backend to destroy immediately (internal refs may remain).

Arrays support multiple ownership modes:

- Shared application memory (`appMemory` non-NULL, optional deleter callback).
- Device-managed memory (`appMemory == NULL`, writable via map/unmap).
- Direct parameter array mapping (`anariMapParameterArray*`) for efficient device-owned writes.

## Backend-agnostic but scalable to distributed rendering

Core semantics are single-process friendly, while extensions (e.g., MPI-related) define distributed lockstep behavior for multi-process data-parallel workflows.

## How an end-user application typically uses ANARI

The usual flow in rendering code is:

1. **Load library and pick a device subtype**
   - `anariLoadLibrary("...")`
   - Query subtypes/extensions and choose based on required capabilities.

2. **Create and configure a device**
   - `anariNewDevice()` or `anariNewInitializedDevice()` for immutable init parameters.
   - Set optional status callback parameters for diagnostics.
   - Commit device parameters when needed.

3. **Create scene objects and data**
   - Build geometry/material/surface, groups, instances, lights, volumes/spatial fields.
   - Put top-level drawables into a `World`.
   - Use `ANARIArray*` or mapped parameter arrays for bulk data.

4. **Set parameters and commit each modified object**
   - Set object-specific fields (e.g., vertices, indices, material inputs, transforms).
   - Call `anariCommitParameters(device, object)` after edits.

5. **Create camera, renderer, and frame**
   - Camera subtype + view/projection parameters.
   - Renderer subtype + quality/performance options.
   - Frame with required params: `world`, `camera`, `renderer`, `size`.
   - Enable desired channels (`channel.color`, `channel.depth`, etc.) as supported.

6. **Render asynchronously**
   - Call `anariRenderFrame(device, frame)`.
   - Poll or wait via `anariFrameReady()`.
   - Optionally query progress/duration with `anariGetProperty()`.

7. **Read frame outputs**
   - Map channel(s) with `anariMapFrame()`, consume pixels, then `anariUnmapFrame()`.
   - Channel format/type is configured on the frame and reported at map time.

8. **Manage lifetimes and shutdown**
   - Release objects you no longer need (`anariRelease()`).
   - Ensure devices are released before unloading their library.
   - `anariUnloadLibrary()` last.

## Practical guidance for robust end-user code

- Treat ANARI as a **scene submission + asynchronous execution API**.
- **Always commit** objects after parameter edits and before expecting render-visible effects.
- Use introspection/extension checks early to select a compatible device and feature set.
- Keep synchronization rules in mind when issuing API calls from multiple threads.
- Prefer direct mapped parameter arrays for one-object data uploads; prefer `ANARIArray*` handles when sharing data across multiple objects.

