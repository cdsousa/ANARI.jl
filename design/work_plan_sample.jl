
# This is a design sample for future implementation work.
# It is intentionally non-executable in the current state of the package.
# Edit freely as API decisions evolve.

using ANARI

function sample_usage()
    # 1) Library + device construction (constructor style)
    lib = Library("helide")
    dev = Device(lib, "default")

    # 2) World graph objects (constructor style)
    camera = Camera(dev, "perspective")
    renderer = Renderer(dev, "default")
    geometry = Geometry(dev, "triangle")
    material = Material(dev, "matte")
    surface = Surface(dev)
    group = Group(dev)
    instance = Instance(dev, "transform")
    world = World(dev)

    # 3) Inferred typed parameter API — dtype derived from value via anari_type
    setparam!(dev, camera,   "position",   (0.0f0, 0.0f0,  3.0f0))
    setparam!(dev, camera,   "direction",  (0.0f0, 0.0f0, -1.0f0))
    setparam!(dev, renderer, "background", (0.02f0, 0.02f0, 0.03f0))

    # 4) Thin array helper that copies into ANARI-owned memory
    vertices = [
        (-1.0f0, -1.0f0, 0.0f0),
        ( 1.0f0, -1.0f0, 0.0f0),
        ( 0.0f0,  1.0f0, 0.0f0),
    ]
    indices = [(UInt32(0), UInt32(1), UInt32(2))]

    vtx_array = Array1D(dev, vertices; copy=true)
    idx_array = Array1D(dev, indices; copy=true)

    setparam!(dev, geometry, "vertex.position", vtx_array)
    setparam!(dev, geometry, "primitive.index", idx_array)
    commit!(dev, geometry)

    setparam!(dev, surface, "geometry", geometry)
    setparam!(dev, surface, "material", material)
    commit!(dev, surface)

    setparam!(dev, group, "surface", Array1D(dev, [surface]; copy=true))
    commit!(dev, group)

    setparam!(dev, instance, "group", group)
    commit!(dev, instance)

    setparam!(dev, world, "instance", Array1D(dev, [instance]; copy=true))
    commit!(dev, world)

    # 5) Frame setup + synchronous rendering helpers
    frame = Frame(dev)
    setparam!(dev, frame, "size",     (UInt32(800), UInt32(600)))
    setparam!(dev, frame, "camera",   camera)
    setparam!(dev, frame, "renderer", renderer)
    setparam!(dev, frame, "world",    world)
    commit!(dev, frame)

    render!(dev, frame)
    wait_ready!(dev, frame)  # internally uses ANARI_WAIT

    # 6) Map frame channel (color) and consume image data
    pixels, width, height, pixel_type = map_frame(dev, frame, "color")
    # ... consume pixels ...
    unmap_frame(dev, frame, "color")

    # 7) Manual release remains available and idempotent
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

    return nothing
end