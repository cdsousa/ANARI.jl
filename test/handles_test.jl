@testset "Handle wrappers unit tests" begin
    @test_throws ErrorException ANARI.Library(ANARI.LibANARI.ANARILibrary(C_NULL))

    lib = ANARI.Library("helide")
    @test lib.ptr != C_NULL

    dev = ANARI.Device(lib, "default")
    @test dev.ptr != C_NULL

    ANARI.release!(dev)
    @test dev.ptr == C_NULL

    # Release operations should be safe to call more than once.
    ANARI.release!(dev)
    @test dev.ptr == C_NULL

    ANARI.release!(lib)
    @test lib.ptr == C_NULL

    ANARI.release!(lib)
    @test lib.ptr == C_NULL

    @test_throws ArgumentError ANARI.Device(lib, "default")
end

@testset "Handle wrappers parameter and commit flow" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    renderer = ANARI.Renderer(dev, "default")
    camera = ANARI.Camera(dev, "default")
    world = ANARI.World(dev)
    frame = ANARI.Frame(dev)

    @test renderer.ptr != C_NULL
    @test camera.ptr != C_NULL
    @test world.ptr != C_NULL
    @test frame.ptr != C_NULL

    size = (UInt32(64), UInt32(64))
    ANARI.setparam!(dev, frame, "size", ANARI.LibANARI.ANARI_UINT32_VEC2, size)
    ANARI.setparam!(dev, frame, "renderer", ANARI.LibANARI.ANARI_RENDERER, renderer)
    ANARI.setparam!(dev, frame, "camera", ANARI.LibANARI.ANARI_CAMERA, camera)
    ANARI.setparam!(dev, frame, "world", ANARI.LibANARI.ANARI_WORLD, world)

    ANARI.commit!(dev, renderer)
    ANARI.commit!(dev, camera)
    ANARI.commit!(dev, world)
    ANARI.commit!(dev, frame)

    ANARI.release!(frame)
    ANARI.release!(world)
    ANARI.release!(camera)
    ANARI.release!(renderer)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test frame.ptr == C_NULL
    @test world.ptr == C_NULL
    @test camera.ptr == C_NULL
    @test renderer.ptr == C_NULL
    @test dev.ptr == C_NULL
    @test lib.ptr == C_NULL

    @test_throws ArgumentError ANARI.commit!(dev, frame)
    @test_throws ArgumentError ANARI.setparam!(dev, frame, "size", ANARI.LibANARI.ANARI_UINT32_VEC2, size)
end

@testset "Handle wrappers scene object constructors and commit flow" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    world = ANARI.World(dev)
    geometry = ANARI.Geometry(dev, "triangle")
    material = ANARI.Material(dev, "matte")
    surface = ANARI.Surface(dev)
    group = ANARI.Group(dev)
    instance = ANARI.Instance(dev, "transform")
    light = ANARI.Light(dev, "directional")

    @test world.ptr != C_NULL
    @test geometry.ptr != C_NULL
    @test material.ptr != C_NULL
    @test surface.ptr != C_NULL
    @test group.ptr != C_NULL
    @test instance.ptr != C_NULL
    @test light.ptr != C_NULL

    ANARI.setparam!(dev, surface, "geometry", ANARI.LibANARI.ANARI_GEOMETRY, geometry)
    ANARI.setparam!(dev, surface, "material", ANARI.LibANARI.ANARI_MATERIAL, material)
    ANARI.commit!(dev, geometry)
    ANARI.commit!(dev, material)
    ANARI.commit!(dev, surface)

    surface_array = ANARI.new_array1d(dev, [surface])
    ANARI.setparam!(dev, group, "surface", ANARI.LibANARI.ANARI_ARRAY1D, surface_array)
    ANARI.commit!(dev, group)

    ANARI.setparam!(dev, instance, "group", ANARI.LibANARI.ANARI_GROUP, group)
    ANARI.commit!(dev, instance)

    instance_array = ANARI.new_array1d(dev, [instance])
    ANARI.setparam!(dev, world, "instance", ANARI.LibANARI.ANARI_ARRAY1D, instance_array)
    ANARI.commit!(dev, world)

    ANARI.release!(instance_array)
    ANARI.release!(surface_array)
    ANARI.release!(light)
    ANARI.release!(instance)
    ANARI.release!(group)
    ANARI.release!(surface)
    ANARI.release!(material)
    ANARI.release!(geometry)
    ANARI.release!(world)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test_throws ArgumentError ANARI.Geometry(dev, "triangle")
    @test_throws ArgumentError ANARI.Material(dev, "matte")
    @test_throws ArgumentError ANARI.Surface(dev)
    @test_throws ArgumentError ANARI.Group(dev)
    @test_throws ArgumentError ANARI.Instance(dev, "transform")
    @test_throws ArgumentError ANARI.Light(dev, "directional")
end

@testset "Handle wrappers sampler, spatial field, and volume constructors" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    sampler = ANARI.Sampler(dev, "transform")
    field = ANARI.SpatialField(dev, "structuredRegular")
    volume = ANARI.Volume(dev, "transferFunction1D")

    @test sampler.ptr != C_NULL
    @test field.ptr != C_NULL
    @test volume.ptr != C_NULL

    ANARI.commit!(dev, sampler)
    ANARI.commit!(dev, field)
    ANARI.commit!(dev, volume)

    ANARI.release!(volume)
    ANARI.release!(field)
    ANARI.release!(sampler)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test_throws ArgumentError ANARI.Sampler(dev, "transform")
    @test_throws ArgumentError ANARI.SpatialField(dev, "structuredRegular")
    @test_throws ArgumentError ANARI.Volume(dev, "transferFunction1D")
end

@testset "Handle wrappers render and wait flow" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    renderer = ANARI.Renderer(dev, "default")
    camera = ANARI.Camera(dev, "default")
    world = ANARI.World(dev)
    frame = ANARI.Frame(dev)

    ANARI.setparam!(dev, frame, "size", (UInt32(64), UInt32(64)))
    ANARI.setparam!(dev, frame, "renderer", renderer)
    ANARI.setparam!(dev, frame, "camera", camera)
    ANARI.setparam!(dev, frame, "world", world)

    ANARI.commit!(dev, renderer)
    ANARI.commit!(dev, camera)
    ANARI.commit!(dev, world)
    ANARI.commit!(dev, frame)

    @test ANARI.render!(dev, frame) === frame

    ready = ANARI.wait_frame!(dev, frame)
    @test ready != 0

    ready2 = ANARI.render_and_wait!(dev, frame)
    @test ready2 != 0

    ANARI.release!(frame)
    ANARI.release!(world)
    ANARI.release!(camera)
    ANARI.release!(renderer)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test_throws ArgumentError ANARI.render!(dev, frame)
    @test_throws ArgumentError ANARI.wait_frame!(dev, frame)
end

@testset "Handle wrappers frame map and unmap flow" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    renderer = ANARI.Renderer(dev, "default")
    camera = ANARI.Camera(dev, "default")
    world = ANARI.World(dev)
    frame = ANARI.Frame(dev)

    ANARI.setparam!(dev, frame, "size", (UInt32(64), UInt32(64)))
    ANARI.setparam!(dev, frame, "renderer", renderer)
    ANARI.setparam!(dev, frame, "camera", camera)
    ANARI.setparam!(dev, frame, "world", world)

    ANARI.commit!(dev, renderer)
    ANARI.commit!(dev, camera)
    ANARI.commit!(dev, world)
    ANARI.commit!(dev, frame)

    ready = ANARI.render_and_wait!(dev, frame)
    @test ready != 0

    pixels, width, height, pixel_type = ANARI.map_frame(dev, frame, "channel.color")
    @test pixels != C_NULL
    @test width == UInt32(64)
    @test height == UInt32(64)
    @test pixel_type isa ANARI.LibANARI.ANARIDataType

    ANARI.unmap_frame(dev, frame, "channel.color")

    ANARI.release!(frame)
    ANARI.release!(world)
    ANARI.release!(camera)
    ANARI.release!(renderer)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test_throws ArgumentError ANARI.map_frame(dev, frame)
    @test_throws ArgumentError ANARI.unmap_frame(dev, frame)
end

@testset "Handle wrappers array copy helper" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    input = Float32[1, 2, 3, 5, 8]
    array = ANARI.new_array1d(dev, input)
    @test array isa ANARI.Array1D
    @test eltype(array) === Float32
    @test array.ptr != C_NULL
    @test array.length == UInt64(length(input))

    data_ptr = ANARI.map_array(dev, array)
    @test data_ptr isa Vector{Float32}
    @test data_ptr == input

    ANARI.unmap_array(dev, array)

    raw_ptr = ANARI.LibANARI.anariNewArray1D(
        dev.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        ANARI.LibANARI.ANARI_FLOAT32,
        UInt64(length(input)),
    )
    fallback_array = ANARI.Array1D(raw_ptr, dev, length(input))
    @test fallback_array isa ANARI.Array1D
    @test eltype(fallback_array) === Any
    @test fallback_array.length == UInt64(length(input))

    fallback_ptr = ANARI.map_array(dev, fallback_array)
    @test fallback_ptr isa Ptr{Cvoid}
    @test fallback_ptr != C_NULL
    ANARI.unmap_array(dev, fallback_array)

    ANARI.release!(array)
    ANARI.release!(fallback_array)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test array.ptr == C_NULL
    @test_throws ArgumentError ANARI.map_array(dev, array)
    @test_throws ArgumentError ANARI.unmap_array(dev, array)
end

@testset "Handle wrappers array 2D/3D copy helpers" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    mat = Float32[i + 10j for i in 1:3, j in 1:4]
    a2 = ANARI.new_array2d(dev, mat)
    @test a2 isa ANARI.Array2D
    @test eltype(a2) === Float32
    @test size(a2) == (3, 4)
    @test a2.ptr != C_NULL

    m2 = ANARI.map_array(dev, a2)
    @test m2 isa Matrix{Float32}
    @test m2 == mat
    ANARI.unmap_array(dev, a2)

    vol = Float64[i + 10j + 100k for i in 1:2, j in 1:3, k in 1:2]
    a3 = ANARI.new_array3d(dev, vol)
    @test a3 isa ANARI.Array3D
    @test eltype(a3) === Float64
    @test size(a3) == (2, 3, 2)
    @test a3.ptr != C_NULL

    m3 = ANARI.map_array(dev, a3)
    @test m3 isa Array{Float64,3}
    @test m3 == vol
    ANARI.unmap_array(dev, a3)

    raw2 = ANARI.LibANARI.anariNewArray2D(
        dev.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        ANARI.LibANARI.ANARI_FLOAT32,
        UInt64(2),
        UInt64(2),
    )
    fb2 = ANARI.Array2D(raw2, dev, (2, 2))
    @test eltype(fb2) === Any
    p2 = ANARI.map_array(dev, fb2)
    @test p2 isa Ptr{Cvoid}
    ANARI.unmap_array(dev, fb2)

    raw3 = ANARI.LibANARI.anariNewArray3D(
        dev.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        ANARI.LibANARI.ANARI_FLOAT32,
        UInt64(1),
        UInt64(1),
        UInt64(1),
    )
    fb3 = ANARI.Array3D(raw3, dev, (1, 1, 1))
    p3 = ANARI.map_array(dev, fb3)
    @test p3 isa Ptr{Cvoid}
    ANARI.unmap_array(dev, fb3)

    ANARI.release!(a2)
    ANARI.release!(a3)
    ANARI.release!(fb2)
    ANARI.release!(fb3)
    ANARI.release!(dev)
    ANARI.release!(lib)

    @test_throws ArgumentError ANARI.map_array(dev, a2)
end