# ANARI.jl Gap Analysis For Triangle Gallery Sample

## Short Answer

Yes, mostly.

The number of helper functions in `run.jl` is mainly a consequence of the current `ANARI.jl` wrapper still being focused on a small core surface:

- handle wrappers for `Library`, `Device`, `World`, `Frame`, `Camera`, `Renderer`, `Array1D`
- basic `setparam!` and `commit!`
- `new_array1d`, `map_array`, `unmap_array`
- frame rendering and frame mapping helpers

That surface is enough for simple frame smoke tests, but not yet enough for a proper scene-building sample without dropping into `LibANARI` and writing local marshalling helpers.

## Important Nuance

Not every helper in `run.jl` indicates a missing library abstraction.

There are three categories of helpers in the sample:

1. Missing wrapper/API surface in `ANARI.jl`
2. Normal sample-specific scene math and image-writing logic
3. Backend-specific workaround logic discovered while validating Helide

The true package gaps are concentrated in category 1.

## What `ANARI.jl` Already Covers Well

Current package support is solid for:

- library/device/frame/camera/renderer/world lifetime handling
- idempotent release semantics
- scalar and small vector parameter setting for a narrow type set
- 1D ANARI arrays when the element type already maps through `anari_type`
- synchronous render/wait/map/unmap flow

This is enough for tests and basic rendering scaffolding.

## Gaps Exposed By The Sample

### 1. Missing scene object wrappers

The sample had to call `LibANARI` directly for objects that should usually have first-class Julia wrappers:

- `Geometry`
- `Material`
- `Surface`
- `Group`
- `Instance`
- likely also `Light` for future examples

Impact:

- sample code cannot stay on the idiomatic wrapper layer
- lifetime management falls back to raw pointer release helpers
- object-type dispatch in `setparam!` stays incomplete because these objects are not wrapper types

Recommended addition:

- add handle wrappers parallel to `World`, `Frame`, `Camera`, `Renderer`
- export constructors like `Geometry(device, subtype)`, `Material(device, subtype)`, `Surface(device)`, `Group(device)`, `Instance(device, subtype)`, `Light(device, subtype)`

Priority: High

### 2. Incomplete parameter marshalling coverage

The sample had to define custom local helpers because `setparam!` does not currently support several parameter kinds needed for real scenes:

- `ANARI_STRING`
- `ANARI_DATA_TYPE`
- `ANARI_ARRAY1D` for object arrays and explicit raw array binding
- object dtypes for `GEOMETRY`, `MATERIAL`, `SURFACE`, `GROUP`, `INSTANCE`, `LIGHT`
- additional tuple types such as `NTuple{3, UInt32}`

Concrete symptoms in the sample:

- `anari_set_string`
- `anari_set_color_channel_format`
- `anari_set_object`
- explicit raw dtype passing for scene objects and arrays

Impact:

- high-level `setparam!` is not sufficient for typical ANARI scene construction
- users need to understand FFI-level dtype details too early
- wrapper ergonomics break down exactly where ANARI scenes become interesting

Recommended addition:

- expand `anari_type` coverage
- expand `_prepare_parameter_ref` coverage
- add wrapper support for all major ANARI object dtypes
- support strings directly in `setparam!`
- support `ANARIDataType` values directly in `setparam!`

Priority: High

### 3. Missing typed support for object-array parameters

ANARI scene graphs rely heavily on arrays of handles, for example:

- group surface arrays
- world instance arrays

The sample had to build raw handle arrays manually and pass them as `ANARI_ARRAY1D`.

Impact:

- common scene assembly patterns are verbose
- ownership/lifetime expectations are left implicit
- users are forced into raw `LibANARI` pointer thinking

Recommended addition:

- make `new_array1d(device, ::AbstractVector{<:ANARIObjectHandle})` work directly
- provide handle-array convenience constructors
- document ownership semantics clearly

Priority: High

### 4. Current `anari_type` coverage is too narrow for scene examples

The current trait covers only:

- `Bool`, `Int32`, `UInt32`, `Float32`, `Float64`
- `NTuple{2,UInt32}`, `NTuple{2,Float32}`, `NTuple{3,Float32}`, `NTuple{4,Float32}`
- `Device`, `World`, `Frame`, `Camera`, `Renderer`

That leaves several common scene payloads unsupported at the idiomatic layer.

Examples from this sample:

- triangle indices as `NTuple{3,UInt32}`
- arrays of raw scene object handles
- string parameters for material attribute binding

Recommended addition:

- add `NTuple{3,UInt32}` and other common ANARI vector types
- add the missing object wrapper mappings as part of the new scene handle types

Priority: Medium-High

### 5. No high-level scene assembly helpers yet

Even after adding missing wrappers, typical usage would still be fairly low-level.

The sample repeatedly performs patterns like:

- create geometry
- set vertex/index/color arrays
- commit geometry
- create material
- attach geometry and material to a surface
- pack surfaces into a group
- pack groups into an instance
- pack instances into a world

This is not strictly required for correctness, but it is the next obvious abstraction layer.

Recommended future additions:

- `Surface(device; geometry=..., material=...)`
- `Group(device; surfaces=[...])`
- `Instance(device; group=...)`
- `World(device; instances=[...])`

These can be added after the lower-level wrapper gaps are closed.

Priority: Medium

### 6. Frame export is outside the package surface

This is not necessarily an `ANARI.jl` gap, but it is worth calling out.

The sample needs application-side logic for:

- converting mapped frame memory to Julia image buffers
- vertical flipping / scanline interpretation
- PNG writing through `FileIO`/`ImageIO`

This is normal sample/application code, not something the wrapper must necessarily own.

Possible optional improvement:

- add a small utility example module or documented helper for `channel.color` to `Matrix{RGBA}` conversion

Priority: Low

### 7. Backend-specific background workaround surfaced during validation

In this environment, Helide returned opaque black background pixels in the mapped color frame, so the sample normalizes near-black background pixels to the requested dark-blue output color during PNG conversion.

This does not look like a core `ANARI.jl` API gap as much as a backend behavior or channel-format interaction.

Implication:

- this workaround should stay sample-local unless repeated across backends

Priority: Low

## Helpers In `run.jl` By Category

### Mostly indicating package gaps

- `anari_set_parameter`
- `anari_set_vec3`
- `anari_set_object`
- `anari_set_color_channel_format`
- `anari_set_string`
- `anari_commit`
- `anari_release`
- the local `new_array1d(device::L.ANARIDevice, ...)`

These mostly exist because the wrapper layer is not yet broad enough for scene objects and parameter types.

### Normal sample/application logic

- `rotate_point`
- `build_triangle_vertices`
- `write_png_from_frame`
- most of `render_one!` scene content choices

These would still exist in some form even with a richer wrapper API, because they encode the specific sample behavior.

### Mixed case

- `render_one!`

Part of it is sample logic, but a large fraction of its verbosity comes from missing scene wrappers and limited `setparam!` support.

## Recommended Implementation Order

1. Add wrapper handle types for `Geometry`, `Material`, `Surface`, `Group`, `Instance`, `Light`
2. Extend `anari_type` and `setparam!` to cover strings, `ANARIDataType`, more tuple types, and the new object handles
3. Support `Array1D` creation from vectors of ANARI object handles
4. Add concise constructors or helper builders for common scene graph patterns
5. Revisit examples and remove the raw `LibANARI` helper layer

## Expected Result After Closing The Main Gaps

Once the high-priority gaps are addressed, this sample should be reducible to:

- straightforward handle constructors
- direct `setparam!` calls with Julia values
- direct `new_array1d` calls for both numeric data and handle arrays
- no raw `LibANARI` object creation in the example
- no sample-local parameter marshalling helpers

That would be a good sign that the wrapper layer has become useful for real ANARI scene authoring rather than only smoke-test style rendering.