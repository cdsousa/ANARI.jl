#!/usr/bin/env julia
# Minimal triangle render example, mirroring cpp_examples/triangle.cpp.
#
# Run:
#   julia --project examples/triangle.jl
#
# Writes examples/triangle.png
#
# The helide backend is provided by ANARI_SDK_jll (preloaded on import).

using ANARI_SDK_jll
using ANARI.LibANARI
using ANARI: Library, Device, Camera, Geometry, Material, Surface, Group, Instance, World
using ANARI: Renderer, Frame, Array1D, setparam!, commit!, release!
using FileIO
using Images

function main()
    lib = Library(anariLoadLibrary("helide", C_NULL, C_NULL))
    dev = Device(lib, anariNewDevice(lib.handle, "default"))

    cam = Camera(dev, "perspective")
    setparam!(cam, "position", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, 3.0f0))
    setparam!(cam, "direction", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, -1.0f0))
    commit!(cam)

    ren = Renderer(dev, "default")
    setparam!(ren, "background", ANARI_FLOAT32_VEC3, (0.02f0, 0.02f0, 0.03f0))
    commit!(ren)

    vtx = NTuple{3, Float32}[(-1.0f0, -1.0f0, 0.0f0), (1.0f0, -1.0f0, 0.0f0), (0.0f0, 1.0f0, 0.0f0)]
    idx = NTuple{3, UInt32}[(0, 1, 2)]
    geo = Geometry(dev, "triangle")
    GC.@preserve vtx begin
        vtx_array = Array1D(dev, pointer(vtx), C_NULL, C_NULL, ANARI_FLOAT32_VEC3, 3)
        setparam!(geo, "vertex.position", ANARI_ARRAY1D, vtx_array)
        release!(vtx_array)
    end
    GC.@preserve idx begin
        idx_array = Array1D(dev, pointer(idx), C_NULL, C_NULL, ANARI_UINT32_VEC3, 1)
        setparam!(geo, "primitive.index", ANARI_ARRAY1D, idx_array)
        release!(idx_array)
    end
    commit!(geo)

    mat = Material(dev, "matte")
    commit!(mat)

    surf = Surface(dev)
    setparam!(surf, "geometry", ANARI_GEOMETRY, geo)
    release!(geo)
    setparam!(surf, "material", ANARI_MATERIAL, mat)
    release!(mat)
    commit!(surf)

    grp = Group(dev)
    surfaces = ANARISurface[surf.handle]
    GC.@preserve surfaces begin
        surface_array = Array1D(dev, pointer(surfaces), C_NULL, C_NULL, ANARI_SURFACE, 1)
        setparam!(grp, "surface", ANARI_ARRAY1D, surface_array)
        release!(surface_array)
    end
    release!(surf)
    commit!(grp)

    inst = Instance(dev, "transform")
    setparam!(inst, "group", ANARI_GROUP, grp)
    release!(grp)
    commit!(inst)

    world = World(dev)
    instances = ANARIInstance[inst.handle]
    GC.@preserve instances begin
        instance_array = Array1D(dev, pointer(instances), C_NULL, C_NULL, ANARI_INSTANCE, 1)
        setparam!(world, "instance", ANARI_ARRAY1D, instance_array)
        release!(instance_array)
    end
    release!(inst)
    commit!(world)

    frame = Frame(dev)
    setparam!(frame, "size", ANARI_UINT32_VEC2, (UInt32(800), UInt32(600)))
    setparam!(frame, "channel.color", ANARI_DATA_TYPE, ANARI_UFIXED8_RGBA_SRGB)
    setparam!(frame, "camera", ANARI_CAMERA, cam)
    release!(cam)
    setparam!(frame, "renderer", ANARI_RENDERER, ren)
    release!(ren)
    setparam!(frame, "world", ANARI_WORLD, world)
    release!(world)
    commit!(frame)

    anariRenderFrame(dev.handle, frame.handle)
    while anariFrameReady(dev.handle, frame.handle, ANARI_WAIT) == 0
        sleep(0.01)
    end

    width = Ref{UInt32}(0)
    height = Ref{UInt32}(0)
    pixel_type = Ref{ANARIDataType}(ANARI_UNKNOWN)
    GC.@preserve width height pixel_type begin
        fb = anariMapFrame(dev.handle, frame.handle, "channel.color", width, height, pixel_type)
        w = Int(width[])
        h = Int(height[])
        px = unsafe_wrap(Vector{UInt32}, Ptr{UInt32}(fb), w * h; own = false)
        rgba = reinterpret(RGBA{N0f8}, copy(px))
        img = permutedims(reshape(rgba, w, h), (2, 1))
        output = joinpath(@__DIR__, "triangle.png")
        save(output, img)
        println("Saved render to ", output)

        anariUnmapFrame(dev.handle, frame.handle, "channel.color")
    end
    release!(frame)
    release!(dev)
    release!(lib)
end

main()
