# Constructor-style ANARI.jl API sketch
#
# This is a design sample for future implementation work.
# It is intentionally non-executable in the current state of the package.
# Edit freely as API decisions evolve.

module WorkPlanSample

# Optional namespace alias in user code:
# using ANARI
# const A = ANARI

function sample_usage()
    # 1) Library + device construction (constructor style)
    lib = Library("environment")
    dev = Device(lib, "default")

    # 2) World graph objects (constructor style)
    cam = Camera(dev, "perspective")
    ren = Renderer(dev, "default")
    geom = Geometry(dev, "triangle")
    mat = Material(dev, "matte")
    surf = Surface(dev)
    grp = Group(dev)
    inst = Instance(dev, "transform")
    world = World(dev)

    # 3) Explicit typed parameter API for v1
    setparam!(dev, cam, "position", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, 3.0f0))
    setparam!(dev, cam, "direction", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, -1.0f0))
    setparam!(dev, ren, "background", ANARI_FLOAT32_VEC3, (0.02f0, 0.02f0, 0.03f0))

    # 4) Thin array helper that copies into ANARI-owned memory
    vertices = [
        (-1.0f0, -1.0f0, 0.0f0),
        ( 1.0f0, -1.0f0, 0.0f0),
        ( 0.0f0,  1.0f0, 0.0f0),
    ]
    indices = [(0, 1, 2)]

    vtx_array = Array1D(dev, vertices; copy=true)
    idx_array = Array1D(dev, indices; copy=true)

    setparam!(dev, geom, "vertex.position", ANARI_ARRAY1D, vtx_array)
    setparam!(dev, geom, "primitive.index", ANARI_ARRAY1D, idx_array)
    commit!(dev, geom)

    setparam!(dev, surf, "geometry", ANARI_GEOMETRY, geom)
    setparam!(dev, surf, "material", ANARI_MATERIAL, mat)
    commit!(dev, surf)

    setparam!(dev, grp, "surface", ANARI_ARRAY1D, Array1D(dev, [surf]; copy=true))
    commit!(dev, grp)

    setparam!(dev, inst, "group", ANARI_GROUP, grp)
    commit!(dev, inst)

    setparam!(dev, world, "instance", ANARI_ARRAY1D, Array1D(dev, [inst]; copy=true))
    commit!(dev, world)

    # 5) Frame setup + synchronous rendering helpers
    frame = Frame(dev)
    setparam!(dev, frame, "size", ANARI_UINT32_VEC2, (800, 600))
    setparam!(dev, frame, "camera", ANARI_CAMERA, cam)
    setparam!(dev, frame, "renderer", ANARI_RENDERER, ren)
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
    release!(inst)
    release!(grp)
    release!(surf)
    release!(mat)
    release!(geom)
    release!(ren)
    release!(cam)
    release!(dev)
    release!(lib)

    return nothing
end

# Suggested internal conventions (non-binding notes):
# - All handle wrappers are mutable structs with inner constructors.
# - Inner constructors attach finalizers that call release! if ptr != C_NULL.
# - release!(x) is idempotent and sets x.ptr = C_NULL after native release.
# - Constructors throw if native pointer is null.
# - Status callback forwards ANARI severity to Julia Logging.

end # module WorkPlanSample
