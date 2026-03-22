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
    @test array isa ANARI.Array1D{Float32}
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
    @test fallback_array isa ANARI.Array1D{Any}
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