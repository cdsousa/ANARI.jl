@testset "anari_type trait" begin
    L = ANARI.LibANARI

    # Scalar types
    @test ANARI.anari_type(Bool)    == L.ANARI_BOOL
    @test ANARI.anari_type(Int32)   == L.ANARI_INT32
    @test ANARI.anari_type(UInt32)  == L.ANARI_UINT32
    @test ANARI.anari_type(Float32) == L.ANARI_FLOAT32
    @test ANARI.anari_type(Float64) == L.ANARI_FLOAT64

    # Vector types
    @test ANARI.anari_type(NTuple{2, UInt32})  == L.ANARI_UINT32_VEC2
    @test ANARI.anari_type(NTuple{2, Float32}) == L.ANARI_FLOAT32_VEC2
    @test ANARI.anari_type(NTuple{3, Float32}) == L.ANARI_FLOAT32_VEC3
    @test ANARI.anari_type(NTuple{4, Float32}) == L.ANARI_FLOAT32_VEC4

    # Handle types
    @test ANARI.anari_type(ANARI.Device)   == L.ANARI_DEVICE
    @test ANARI.anari_type(ANARI.World)    == L.ANARI_WORLD
    @test ANARI.anari_type(ANARI.Frame)    == L.ANARI_FRAME
    @test ANARI.anari_type(ANARI.Camera)   == L.ANARI_CAMERA
    @test ANARI.anari_type(ANARI.Renderer) == L.ANARI_RENDERER
    @test ANARI.anari_type(ANARI.Geometry) == L.ANARI_GEOMETRY
    @test ANARI.anari_type(ANARI.Material) == L.ANARI_MATERIAL
    @test ANARI.anari_type(ANARI.Surface)  == L.ANARI_SURFACE
    @test ANARI.anari_type(ANARI.Group)    == L.ANARI_GROUP
    @test ANARI.anari_type(ANARI.Instance) == L.ANARI_INSTANCE
    @test ANARI.anari_type(ANARI.Light)    == L.ANARI_LIGHT
    @test ANARI.anari_type(ANARI.Sampler)       == L.ANARI_SAMPLER
    @test ANARI.anari_type(ANARI.SpatialField)  == L.ANARI_SPATIAL_FIELD
    @test ANARI.anari_type(ANARI.Volume)        == L.ANARI_VOLUME
    @test ANARI.anari_type(ANARI.Array1D)       == L.ANARI_ARRAY1D
end

@testset "setparam! inferred dtype" begin
    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    renderer = ANARI.Renderer(dev, "default")
    camera   = ANARI.Camera(dev, "default")
    world    = ANARI.World(dev)
    frame    = ANARI.Frame(dev)

    # Inferred from NTuple{2, UInt32}
    ANARI.setparam!(dev, frame, "size", (UInt32(32), UInt32(32)))

    # Inferred from object handle types
    ANARI.setparam!(dev, frame, "renderer", renderer)
    ANARI.setparam!(dev, frame, "camera",   camera)
    ANARI.setparam!(dev, frame, "world",    world)

    ANARI.commit!(dev, renderer)
    ANARI.commit!(dev, camera)
    ANARI.commit!(dev, world)
    ANARI.commit!(dev, frame)

    # Unsupported type raises MethodError (no anari_type method defined)
    @test_throws MethodError ANARI.setparam!(dev, frame, "size", (32, 32))

    ANARI.release!(frame)
    ANARI.release!(world)
    ANARI.release!(camera)
    ANARI.release!(renderer)
    ANARI.release!(dev)
    ANARI.release!(lib)
end
