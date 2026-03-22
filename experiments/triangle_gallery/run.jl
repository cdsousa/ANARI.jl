import Pkg

Pkg.activate(@__DIR__)

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const OUTPUT_DIR = joinpath(@__DIR__, "output")

function ensure_dependencies!()
    deps = Set(keys(Pkg.project().dependencies))

    if !("ANARI" in deps)
        Pkg.develop(Pkg.PackageSpec(path=PROJECT_ROOT))
        push!(deps, "ANARI")
    end

    missing = String[]
    for name in ("FileIO", "PNGFiles", "ColorTypes", "FixedPointNumbers", "ImageIO")
        if !(name in deps)
            push!(missing, name)
        end
    end

    if !isempty(missing)
        Pkg.add(missing)
    end

    return nothing
end

ensure_dependencies!()

using ANARI
using FileIO
using ColorTypes
using PNGFiles
using ImageIO
using FixedPointNumbers: N0f8

const L = ANARI.LibANARI
const WIDTH = UInt32(1920)
const HEIGHT = UInt32(1080)
const BACKGROUND_RGB = (0.00f0, 0.00f0, 0.28f0)

function anari_set_parameter(device::L.ANARIDevice, object::L.ANARIObject, name::AbstractString, dtype::L.ANARIDataType, value_ref)
    GC.@preserve value_ref begin
        L.anariSetParameter(device, object, name, dtype, Base.unsafe_convert(Ptr{Cvoid}, value_ref))
    end
    return nothing
end

function anari_set_vec3(device::L.ANARIDevice, object::L.ANARIObject, name::AbstractString, value::NTuple{3, Float32})
    value_ref = Ref{NTuple{3, Float32}}(value)
    anari_set_parameter(device, object, name, L.ANARI_FLOAT32_VEC3, value_ref)
    return nothing
end

function anari_set_object(device::L.ANARIDevice, object::L.ANARIObject, name::AbstractString, dtype::L.ANARIDataType, handle)
    handle_ref = Ref(handle)
    anari_set_parameter(device, object, name, dtype, handle_ref)
    return nothing
end

function anari_set_color_channel_format(device::L.ANARIDevice, frame::L.ANARIFrame)
    format_ref = Ref{L.ANARIDataType}(L.ANARI_UFIXED8_RGBA_SRGB)
    anari_set_parameter(device, frame, "channel.color", L.ANARI_DATA_TYPE, format_ref)
    return nothing
end

function anari_set_string(device::L.ANARIDevice, object::L.ANARIObject, name::AbstractString, value::String)
    c_value = Base.cconvert(Cstring, value)
    GC.@preserve value begin
        c_ptr = Base.unsafe_convert(Cstring, c_value)
        L.anariSetParameter(device, object, name, L.ANARI_STRING, Ptr{Cvoid}(c_ptr))
    end
    return nothing
end

function anari_commit(device::L.ANARIDevice, object::L.ANARIObject)
    L.anariCommitParameters(device, object)
    return nothing
end

function anari_release(device::L.ANARIDevice, object)
    object == C_NULL && return
    L.anariRelease(device, object)
    return nothing
end

function new_array1d(device::L.ANARIDevice, values::Vector{T}, dtype::L.ANARIDataType) where {T}
    array = L.anariNewArray1D(device, C_NULL, C_NULL, C_NULL, dtype, UInt64(length(values)))
    array == C_NULL && error("anariNewArray1D returned null")

    mapped = L.anariMapArray(device, array)
    mapped == C_NULL && error("anariMapArray returned null")

    try
        unsafe_copyto!(Ptr{T}(mapped), pointer(values), length(values))
    finally
        L.anariUnmapArray(device, array)
    end

    return array
end

function rotate_point(x::Float32, y::Float32, cx::Float32, cy::Float32, angle_rad::Float32)
    s = sin(angle_rad)
    c = cos(angle_rad)

    dx = x - cx
    dy = y - cy

    xr = (dx * c - dy * s) + cx
    yr = (dx * s + dy * c) + cy

    return xr, yr
end

function build_triangle_vertices(cx::Float32, cy::Float32, angle_rad::Float32)
    base = (
        (-0.24f0, -0.22f0),
        (0.24f0, -0.22f0),
        (0.00f0, 0.26f0),
    )

    verts = NTuple{3, Float32}[]
    for (x, y) in base
        xr, yr = rotate_point(cx + x, cy + y, cx, cy, angle_rad)
        push!(verts, (xr, yr, 0.0f0))
    end

    return verts
end

function write_png_from_frame(device::ANARI.Device, frame::ANARI.Frame, output_file::String)
    pixels, width_u32, height_u32, pixel_type = ANARI.map_frame(device, frame, "channel.color")

    width = Int(width_u32)
    height = Int(height_u32)
    count = width * height

    image = Matrix{RGBA{N0f8}}(undef, height, width)
    bg_r, bg_g, bg_b = BACKGROUND_RGB
    bg_threshold = 0.02f0

    if pixel_type == L.ANARI_FLOAT32_VEC4
        raw = unsafe_wrap(Vector{NTuple{4, Float32}}, Ptr{NTuple{4, Float32}}(pixels), count)
        for y in 1:height
            src_y = height - y
            row_offset = src_y * width
            for x in 1:width
                r, g, b, a = raw[row_offset + x]
                alpha = clamp(a, 0f0, 1f0)
                out_r = clamp(r * alpha + bg_r * (1f0 - alpha), 0f0, 1f0)
                out_g = clamp(g * alpha + bg_g * (1f0 - alpha), 0f0, 1f0)
                out_b = clamp(b * alpha + bg_b * (1f0 - alpha), 0f0, 1f0)

                if out_r < bg_threshold && out_g < bg_threshold && out_b < bg_threshold
                    out_r = bg_r
                    out_g = bg_g
                    out_b = bg_b
                end

                image[y, x] = RGBA{N0f8}(N0f8(out_r), N0f8(out_g), N0f8(out_b), N0f8(1f0))
            end
        end
    else
        raw = unsafe_wrap(Vector{NTuple{4, UInt8}}, Ptr{NTuple{4, UInt8}}(pixels), count)
        for y in 1:height
            src_y = height - y
            row_offset = src_y * width
            for x in 1:width
                r, g, b, a = raw[row_offset + x]
                alpha = Float32(a) / 255f0
                src_r = Float32(r) / 255f0
                src_g = Float32(g) / 255f0
                src_b = Float32(b) / 255f0
                out_r = clamp(src_r * alpha + bg_r * (1f0 - alpha), 0f0, 1f0)
                out_g = clamp(src_g * alpha + bg_g * (1f0 - alpha), 0f0, 1f0)
                out_b = clamp(src_b * alpha + bg_b * (1f0 - alpha), 0f0, 1f0)

                if out_r < bg_threshold && out_g < bg_threshold && out_b < bg_threshold
                    out_r = bg_r
                    out_g = bg_g
                    out_b = bg_b
                end

                image[y, x] = RGBA{N0f8}(N0f8(out_r), N0f8(out_g), N0f8(out_b), N0f8(1f0))
            end
        end
    end

    ANARI.unmap_frame(device, frame, "channel.color")
    save(output_file, image)
    return nothing
end

function render_one!(
    device::ANARI.Device,
    renderer::ANARI.Renderer,
    camera::ANARI.Camera,
    frame::ANARI.Frame,
    angle_deg::Int,
    output_file::String,
)
    dev = device.ptr

    world = ANARI.World(device)

    geometry_left = L.anariNewGeometry(dev, "triangle")
    geometry_right = L.anariNewGeometry(dev, "triangle")

    material_left = L.anariNewMaterial(dev, "matte")
    material_right = L.anariNewMaterial(dev, "matte")

    surface_left = L.anariNewSurface(dev)
    surface_right = L.anariNewSurface(dev)

    group = L.anariNewGroup(dev)
    instance = L.anariNewInstance(dev, "transform")

    angle_rad = Float32(deg2rad(angle_deg))

    left_vertices = build_triangle_vertices(-0.48f0, 0.0f0, angle_rad)
    right_vertices = build_triangle_vertices(0.48f0, 0.0f0, angle_rad)

    tri_index = [(UInt32(0), UInt32(1), UInt32(2))]

    right_colors = [
        (1.0f0, 0.0f0, 0.0f0),
        (0.0f0, 1.0f0, 0.0f0),
        (0.0f0, 0.0f0, 1.0f0),
    ]

    left_positions_array = new_array1d(dev, left_vertices, L.ANARI_FLOAT32_VEC3)
    right_positions_array = new_array1d(dev, right_vertices, L.ANARI_FLOAT32_VEC3)
    indices_array = new_array1d(dev, tri_index, L.ANARI_UINT32_VEC3)
    right_colors_array = new_array1d(dev, right_colors, L.ANARI_FLOAT32_VEC3)

    surfaces_array = C_NULL
    instances_array = C_NULL

    try
        anari_set_object(dev, geometry_left, "vertex.position", L.ANARI_ARRAY1D, left_positions_array)
        anari_set_object(dev, geometry_left, "primitive.index", L.ANARI_ARRAY1D, indices_array)
        anari_commit(dev, geometry_left)

        anari_set_object(dev, geometry_right, "vertex.position", L.ANARI_ARRAY1D, right_positions_array)
        anari_set_object(dev, geometry_right, "primitive.index", L.ANARI_ARRAY1D, indices_array)
        anari_set_object(dev, geometry_right, "vertex.color", L.ANARI_ARRAY1D, right_colors_array)
        anari_commit(dev, geometry_right)

        anari_set_vec3(dev, material_left, "color", (0.0f0, 1.0f0, 0.0f0))
        anari_set_string(dev, material_right, "color", "color")
        anari_commit(dev, material_left)
        anari_commit(dev, material_right)

        anari_set_object(dev, surface_left, "geometry", L.ANARI_GEOMETRY, geometry_left)
        anari_set_object(dev, surface_left, "material", L.ANARI_MATERIAL, material_left)
        anari_commit(dev, surface_left)

        anari_set_object(dev, surface_right, "geometry", L.ANARI_GEOMETRY, geometry_right)
        anari_set_object(dev, surface_right, "material", L.ANARI_MATERIAL, material_right)
        anari_commit(dev, surface_right)

        surfaces_array = new_array1d(dev, [surface_left, surface_right], L.ANARI_SURFACE)
        anari_set_object(dev, group, "surface", L.ANARI_ARRAY1D, surfaces_array)
        anari_commit(dev, group)

        anari_set_object(dev, instance, "group", L.ANARI_GROUP, group)
        anari_commit(dev, instance)

        instances_array = new_array1d(dev, [instance], L.ANARI_INSTANCE)
        anari_set_object(dev, world.ptr, "instance", L.ANARI_ARRAY1D, instances_array)
        anari_commit(dev, world.ptr)

        ANARI.setparam!(device, frame, "world", world)
        ANARI.commit!(device, frame)

        ANARI.render_and_wait!(device, frame)
        write_png_from_frame(device, frame, output_file)
    finally
        instances_array != C_NULL && anari_release(dev, instances_array)
        surfaces_array != C_NULL && anari_release(dev, surfaces_array)

        anari_release(dev, right_colors_array)
        anari_release(dev, indices_array)
        anari_release(dev, right_positions_array)
        anari_release(dev, left_positions_array)

        anari_release(dev, instance)
        anari_release(dev, group)
        anari_release(dev, surface_right)
        anari_release(dev, surface_left)
        anari_release(dev, material_right)
        anari_release(dev, material_left)
        anari_release(dev, geometry_right)
        anari_release(dev, geometry_left)

        ANARI.release!(world)
    end

    return nothing
end

function main()
    mkpath(OUTPUT_DIR)

    lib = ANARI.Library("helide")
    dev = ANARI.Device(lib, "default")

    renderer = ANARI.Renderer(dev, "default")
    camera = ANARI.Camera(dev, "perspective")
    frame = ANARI.Frame(dev)

    try
        ANARI.setparam!(dev, renderer, "background", BACKGROUND_RGB)
        ANARI.commit!(dev, renderer)

        ANARI.setparam!(dev, camera, "position", (0.0f0, 0.0f0, 2.8f0))
        ANARI.setparam!(dev, camera, "direction", (0.0f0, 0.0f0, -1.0f0))
        ANARI.setparam!(dev, camera, "up", (0.0f0, 1.0f0, 0.0f0))
        ANARI.setparam!(dev, camera, "aspect", Float32(WIDTH) / Float32(HEIGHT))
        ANARI.commit!(dev, camera)

        ANARI.setparam!(dev, frame, "size", (WIDTH, HEIGHT))
        ANARI.setparam!(dev, frame, "camera", camera)
        ANARI.setparam!(dev, frame, "renderer", renderer)

        anari_set_color_channel_format(dev.ptr, frame.ptr)
        ANARI.commit!(dev, frame)

        angles = (0, 90, 180)
        for (idx, angle) in enumerate(angles)
            output_file = joinpath(OUTPUT_DIR, "triangles_$(lpad(string(idx), 2, '0'))_$(angle)deg.png")
            @info "Rendering image" index=idx angle=angle file=output_file
            render_one!(dev, renderer, camera, frame, angle, output_file)
        end

        @info "Done" output_dir=OUTPUT_DIR
    finally
        ANARI.release!(frame)
        ANARI.release!(camera)
        ANARI.release!(renderer)
        ANARI.release!(dev)
        ANARI.release!(lib)
    end

    return nothing
end

main()
