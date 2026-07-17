#!/usr/bin/env julia
# Minimal triangle render example, mirroring cpp_examples/triangle.cpp.
# Uses the generated LibANARI bindings directly (no higher-level wrappers).
#
# Run:
#   julia --project examples/triangle.jl
#
# The helide backend is provided by ANARI_SDK_jll (preloaded on import).

using ANARI_SDK_jll
using ANARI.LibANARI
using ANARI: set_parameter_safe

function main()
    lib = anariLoadLibrary("helide", C_NULL, C_NULL)
    dev = anariNewDevice(lib, "default")

    cam = anariNewCamera(dev, "perspective")
    set_parameter_safe(dev, cam, "position", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, 3.0f0))
    set_parameter_safe(dev, cam, "direction", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, -1.0f0))
    anariCommitParameters(dev, cam)

    ren = anariNewRenderer(dev, "default")
    set_parameter_safe(dev, ren, "background", ANARI_FLOAT32_VEC3, (0.02f0, 0.02f0, 0.03f0))
    anariCommitParameters(dev, ren)

    vtx = NTuple{3, Float32}[(-1.0f0, -1.0f0, 0.0f0), (1.0f0, -1.0f0, 0.0f0), (0.0f0, 1.0f0, 0.0f0)]
    idx = NTuple{3, UInt32}[(0, 1, 2)]
    geo = anariNewGeometry(dev, "triangle")
    GC.@preserve vtx begin
        vtx_array = anariNewArray1D(dev, pointer(vtx), C_NULL, C_NULL, ANARI_FLOAT32_VEC3, 3)
    end
    set_parameter_safe(dev, geo, "vertex.position", ANARI_ARRAY1D, vtx_array)
    anariRelease(dev, vtx_array)
    GC.@preserve idx begin
        idx_array = anariNewArray1D(dev, pointer(idx), C_NULL, C_NULL, ANARI_UINT32_VEC3, 1)
    end
    set_parameter_safe(dev, geo, "primitive.index", ANARI_ARRAY1D, idx_array)
    anariRelease(dev, idx_array)
    anariCommitParameters(dev, geo)

    mat = anariNewMaterial(dev, "matte")
    anariCommitParameters(dev, mat)

    surf = anariNewSurface(dev)
    set_parameter_safe(dev, surf, "geometry", ANARI_GEOMETRY, geo)
    anariRelease(dev, geo)
    set_parameter_safe(dev, surf, "material", ANARI_MATERIAL, mat)
    anariRelease(dev, mat)
    anariCommitParameters(dev, surf)

    grp = anariNewGroup(dev)
    surfaces = ANARISurface[surf]
    GC.@preserve surfaces begin
        surface_array = anariNewArray1D(dev, pointer(surfaces), C_NULL, C_NULL, ANARI_SURFACE, 1)
    end
    set_parameter_safe(dev, grp, "surface", ANARI_ARRAY1D, surface_array)
    anariRelease(dev, surface_array)
    anariRelease(dev, surf)
    anariCommitParameters(dev, grp)

    inst = anariNewInstance(dev, "transform")
    set_parameter_safe(dev, inst, "group", ANARI_GROUP, grp)
    anariRelease(dev, grp)
    anariCommitParameters(dev, inst)

    world = anariNewWorld(dev)
    instances = ANARIInstance[inst]
    GC.@preserve instances begin
        instance_array = anariNewArray1D(dev, pointer(instances), C_NULL, C_NULL, ANARI_INSTANCE, 1)
    end
    set_parameter_safe(dev, world, "instance", ANARI_ARRAY1D, instance_array)
    anariRelease(dev, instance_array)
    anariRelease(dev, inst)
    anariCommitParameters(dev, world)

    frame = anariNewFrame(dev)
    set_parameter_safe(dev, frame, "size", ANARI_UINT32_VEC2, (UInt32(800), UInt32(600)))
    set_parameter_safe(dev, frame, "channel.color", ANARI_DATA_TYPE, ANARI_UFIXED8_RGBA_SRGB)
    set_parameter_safe(dev, frame, "camera", ANARI_CAMERA, cam)
    anariRelease(dev, cam)
    set_parameter_safe(dev, frame, "renderer", ANARI_RENDERER, ren)
    anariRelease(dev, ren)
    set_parameter_safe(dev, frame, "world", ANARI_WORLD, world)
    anariRelease(dev, world)
    anariCommitParameters(dev, frame)

    anariRenderFrame(dev, frame)
    while anariFrameReady(dev, frame, ANARI_WAIT) == 0
    end

    width = Ref{UInt32}(0)
    height = Ref{UInt32}(0)
    pixel_type = Ref{ANARIDataType}(ANARI_UNKNOWN)
    GC.@preserve width height pixel_type begin
        fb = anariMapFrame(dev, frame, "channel.color", width, height, pixel_type)
        w = Int(width[])
        h = Int(height[])
        px = unsafe_wrap(Vector{UInt32}, Ptr{UInt32}(fb), w * h; own = false)

        for i in (1, (h ÷ 2) * w + w ÷ 2 + 1)
            p = px[i]
            println("pixel[$i]: $(p & 0xFF) $((p >> 8) & 0xFF) $((p >> 16) & 0xFF)")
        end

        anariUnmapFrame(dev, frame, "channel.color")
    end
    anariRelease(dev, frame)
    anariRelease(dev, dev)
    anariUnloadLibrary(lib)
end

main()
