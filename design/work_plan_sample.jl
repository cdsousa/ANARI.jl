
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

    # 3) Explicit typed parameter API for v1
    setparam!(dev, camera, "position", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, 3.0f0))
    setparam!(dev, camera, "direction", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, -1.0f0))
    setparam!(dev, renderer, "background", ANARI_FLOAT32_VEC3, (0.02f0, 0.02f0, 0.03f0))

    # 4) Thin array helper that copies into ANARI-owned memory
    vertices = [
        (-1.0f0, -1.0f0, 0.0f0),
        ( 1.0f0, -1.0f0, 0.0f0),
        ( 0.0f0,  1.0f0, 0.0f0),
    ]
    indices = [(0, 1, 2)]

    vtx_array = Array1D(dev, vertices; copy=true)
    idx_array = Array1D(dev, indices; copy=true)

    setparam!(dev, geometry, "vertex.position", ANARI_ARRAY1D, vtx_array)
    setparam!(dev, geometry, "primitive.index", ANARI_ARRAY1D, idx_array)
    commit!(dev, geometry)

    setparam!(dev, surface, "geometry", ANARI_GEOMETRY, geometry)
    setparam!(dev, surface, "material", ANARI_MATERIAL, material)
    commit!(dev, surface)

    setparam!(dev, group, "surface", ANARI_ARRAY1D, Array1D(dev, [surface]; copy=true))
    commit!(dev, group)

    setparam!(dev, instance, "group", ANARI_GROUP, group)
    commit!(dev, instance)

    setparam!(dev, world, "instance", ANARI_ARRAY1D, Array1D(dev, [instance]; copy=true))
    commit!(dev, world)

    # 5) Frame setup + synchronous rendering helpers
    frame = Frame(dev)
    setparam!(dev, frame, "size", ANARI_UINT32_VEC2, (800, 600))
    setparam!(dev, frame, "camera", ANARI_CAMERA, camera)
    setparam!(dev, frame, "renderer", ANARI_RENDERER, renderer)
    setparam!(dev, frame, "world", ANARI_WORLD, world)
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