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