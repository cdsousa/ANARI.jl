# Example: idiomatic ANARI.jl usage aligned with `design/work_plan.md`.
#
# Requires a working ANARI device library (e.g. helide via ANARI_SDK_jll). From the repo root:
#   julia --project=examples examples/sample.jl
#
# Dependencies (Images, FileIO, PNGFiles) live in `examples/Project.toml`, not the ANARI package.
# Writes `sample_render.png` next to this script.

using ANARI
using ANARI.LibANARI: ANARI_DATA_TYPE, ANARI_UFIXED8_RGBA_SRGB
using FileIO
using Images
using PNGFiles

function sample()
    out_path = joinpath(@__DIR__, "sample_render.png")

    # --- Library & device (constructor-style API; raw FFI stays in `LibANARI`) ---
    lib = Library("helide")
    dev = Device(lib, "default")

    # --- Scene objects ---
    camera = Camera(dev, "perspective")
    renderer = Renderer(dev, "default")
    geometry = Geometry(dev, "triangle")
    material = Material(dev, "matte")
    surface = Surface(dev)
    group = Group(dev)
    instance = Instance(dev, "transform")
    world = World(dev)

    # --- Inferred `setparam!`: dtype from `anari_type(typeof(value))` ---
    setparam!(dev, camera, "position", (0.0f0, 0.0f0, 3.0f0))
    setparam!(dev, camera, "direction", (0.0f0, 0.0f0, -1.0f0))
    setparam!(dev, renderer, "background", (0.02f0, 0.02f0, 0.03f0))

    # --- `new_array1d`: copy Julia data into ANARI-owned memory; returns `Array1D` ---
    vertices = [
        (-1.0f0, -1.0f0, 0.0f0),
        (1.0f0, -1.0f0, 0.0f0),
        (0.0f0, 1.0f0, 0.0f0),
    ]
    indices = [(UInt32(0), UInt32(1), UInt32(2))]

    vtx_array = new_array1d(dev, vertices)
    idx_array = new_array1d(dev, indices)

    setparam!(dev, geometry, "vertex.position", vtx_array)
    setparam!(dev, geometry, "primitive.index", idx_array)
    commit!(dev, geometry)

    setparam!(dev, surface, "geometry", geometry)
    setparam!(dev, surface, "material", material)
    commit!(dev, material)
    commit!(dev, surface)

    surface_array = new_array1d(dev, [surface])
    setparam!(dev, group, "surface", surface_array)
    commit!(dev, group)

    setparam!(dev, instance, "group", group)
    commit!(dev, instance)

    instance_array = new_array1d(dev, [instance])
    setparam!(dev, world, "instance", instance_array)
    commit!(dev, world)

    # --- Frame: enable RGBA8 color channel, then synchronous render + wait ---
    frame = Frame(dev)
    setparam!(dev, frame, "size", (UInt32(800), UInt32(600)))
    setparam!(dev, frame, "camera", camera)
    setparam!(dev, frame, "renderer", renderer)
    setparam!(dev, frame, "world", world)
    # ANARI 1.1: `channel.color` is a DATA_TYPE parameter selecting the observable pixel format.
    setparam!(dev, frame, "channel.color", ANARI_DATA_TYPE, ANARI_UFIXED8_RGBA_SRGB)
    commit!(dev, camera)
    commit!(dev, renderer)
    commit!(dev, world)
    commit!(dev, frame)

    render!(dev, frame)
    wait_frame!(dev, frame)

    # --- Map frame: buffer is row-major RGBA8; wrap as `Matrix{RGBA{N0f8}}` for Images ---
    # `unsafe_wrap`, `reshape`, and `transpose` alias the mapped memory (no copy). Unmap only
    # after consumers finish reading—here, after `save` has written the PNG from that memory.
    channel = "channel.color"
    pixels_ptr, width, height, _pixel_type = map_frame(dev, frame, channel)
    w, h = Int(width), Int(height)
    rgba = unsafe_wrap(Vector{RGBA{N0f8}}, Ptr{RGBA{N0f8}}(pixels_ptr), w * h)
    img = transpose(reshape(rgba, (w, h)))

    save(out_path, img)
    unmap_frame(dev, frame, channel)

    # --- Explicit `release!` (idempotent); arrays used only as parameters can be released after world commits ---
    release!(instance_array)
    release!(surface_array)
    release!(idx_array)
    release!(vtx_array)

    release!(frame)
    release!(world)
    release!(instance)
    release!(group)
    release!(surface)
    release!(material)
    release!(geometry)
    release!(renderer)
    release!(camera)
    release!(dev)
    release!(lib)

    println("Wrote ", out_path)
    return nothing
end

sample()
