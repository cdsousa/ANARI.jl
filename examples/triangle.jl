using ANARI
using ANARI.LibANARI: ANARI_DATA_TYPE, ANARI_UFIXED8_RGBA_SRGB

using FileIO
using Images

function sample()
    
    lib = Library("helide")
    dev = Device(lib, "default")

    camera = Camera(dev, "perspective")
    renderer = Renderer(dev, "default")
    geometry = Geometry(dev, "triangle")
    material = Material(dev, "matte")
    surface = Surface(dev)
    group = Group(dev)
    instance = Instance(dev, "transform")
    world = World(dev)

    setparam!(dev, camera, "position", (0.0f0, 0.0f0, 3.0f0))
    setparam!(dev, camera, "direction", (0.0f0, 0.0f0, -1.0f0))
    setparam!(dev, renderer, "background", (0.02f0, 0.02f0, 0.03f0))

    vertices = [
        (-1.0f0, -1.0f0, 0.0f0),
        (1.0f0, -1.0f0, 0.0f0),
        (0.0f0, 1.0f0, 0.0f0),
    ]
    indices = [(UInt32(0), UInt32(1), UInt32(2))]

    vtx_array = Array1D(dev, vertices)
    idx_array = Array1D(dev, indices)

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

    frame = Frame(dev)
    setparam!(dev, frame, "size", (UInt32(800), UInt32(600)))
    setparam!(dev, frame, "camera", camera)
    setparam!(dev, frame, "renderer", renderer)
    setparam!(dev, frame, "world", world)
    
    setparam!(dev, frame, "channel.color", ANARI_DATA_TYPE, ANARI_UFIXED8_RGBA_SRGB)
    commit!(dev, camera)
    commit!(dev, renderer)
    commit!(dev, world)
    commit!(dev, frame)

    render!(dev, frame)
    wait_frame!(dev, frame)

    channel = "channel.color"
    pixels_ptr, width, height, _pixel_type = map_frame(dev, frame, channel)
    w, h = Int(width), Int(height)
    rgba = unsafe_wrap(Vector{RGBA{N0f8}}, Ptr{RGBA{N0f8}}(pixels_ptr), w * h)
    img = transpose(reshape(rgba, (w, h)))

    save(out_path, img)
    unmap_frame(dev, frame, channel)
    
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

    out_path = joinpath(@__DIR__, "sample_render.png")
    println("Wrote ", out_path)
    return nothing
end

sample()
