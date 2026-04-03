export new_array1d, new_array2d, new_array3d, map_array, unmap_array

Base.eltype(a::Array1D) = a.eltype
Base.eltype(a::Array2D) = a.eltype
Base.eltype(a::Array3D) = a.eltype

"""
    new_array1d(device, data::AbstractVector) -> Array1D

Allocate an ANARI 1D array on `device`, copy `data` into it, and return an `Array1D` whose `length` and `eltype`
fields describe the copy (object-handle vectors use `eltype == LibANARI.ANARIObject`).
"""
function new_array1d(device::Device, data::AbstractVector{T}) where {T<:ANARIObjectHandle}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    values = LibANARI.ANARIObject[]
    sizehint!(values, length(data))
    for object in data
        _isnull(object.ptr) && throw(ArgumentError("array element handle has already been released"))
        push!(values, _as_anari_object(object))
    end

    ptr = LibANARI.anariNewArray1D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        anari_type(T),
        UInt64(length(values)),
    )
    array = Array1D(ptr, device, length(values), LibANARI.ANARIObject)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{LibANARI.ANARIObject}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

function new_array1d(device::Device, data::AbstractVector{T}) where {T}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    values = collect(data)
    dtype = anari_type(T)

    ptr = LibANARI.anariNewArray1D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        dtype,
        UInt64(length(values)),
    )
    array = Array1D(ptr, device, length(values), T)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{T}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

"""
    new_array2d(device, data::AbstractMatrix) -> Array2D

Allocate an ANARI 2D array, copy `data` in column-major order (first dimension varies fastest, matching `vec(data)`),
and return an `Array2D` with `size` `(size(data,1), size(data,2))`.
"""
function new_array2d(device::Device, data::AbstractMatrix{T}) where {T<:ANARIObjectHandle}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    n1, n2 = size(data, 1), size(data, 2)
    (n1 == 0 || n2 == 0) && throw(ArgumentError("array dimensions must be positive"))

    values = LibANARI.ANARIObject[]
    sizehint!(values, n1 * n2)
    for j in 1:n2
        for i in 1:n1
            object = data[i, j]
            _isnull(object.ptr) && throw(ArgumentError("array element handle has already been released"))
            push!(values, _as_anari_object(object))
        end
    end

    ptr = LibANARI.anariNewArray2D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        anari_type(T),
        UInt64(n1),
        UInt64(n2),
    )
    array = Array2D(ptr, device, (n1, n2), LibANARI.ANARIObject)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{LibANARI.ANARIObject}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

function new_array2d(device::Device, data::AbstractMatrix{T}) where {T}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    n1, n2 = size(data, 1), size(data, 2)
    (n1 == 0 || n2 == 0) && throw(ArgumentError("array dimensions must be positive"))

    dtype = anari_type(T)
    flat = vec(collect(data))

    ptr = LibANARI.anariNewArray2D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        dtype,
        UInt64(n1),
        UInt64(n2),
    )
    array = Array2D(ptr, device, (n1, n2), T)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{T}(mapped), pointer(flat), length(flat))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

"""
    new_array3d(device, data::AbstractArray{T,3}) -> Array3D

Allocate an ANARI 3D array, copy `data` in column-major order (`vec(data)`), with extents `size(data)`.
"""
function new_array3d(device::Device, data::AbstractArray{T,3}) where {T<:ANARIObjectHandle}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    n1, n2, n3 = size(data, 1), size(data, 2), size(data, 3)
    (n1 == 0 || n2 == 0 || n3 == 0) && throw(ArgumentError("array dimensions must be positive"))

    values = LibANARI.ANARIObject[]
    sizehint!(values, n1 * n2 * n3)
    for k in 1:n3
        for j in 1:n2
            for i in 1:n1
                object = data[i, j, k]
                _isnull(object.ptr) && throw(ArgumentError("array element handle has already been released"))
                push!(values, _as_anari_object(object))
            end
        end
    end

    ptr = LibANARI.anariNewArray3D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        anari_type(T),
        UInt64(n1),
        UInt64(n2),
        UInt64(n3),
    )
    array = Array3D(ptr, device, (n1, n2, n3), LibANARI.ANARIObject)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{LibANARI.ANARIObject}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

function new_array3d(device::Device, data::AbstractArray{T,3}) where {T}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    n1, n2, n3 = size(data, 1), size(data, 2), size(data, 3)
    (n1 == 0 || n2 == 0 || n3 == 0) && throw(ArgumentError("array dimensions must be positive"))

    dtype = anari_type(T)
    flat = vec(collect(data))

    ptr = LibANARI.anariNewArray3D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        dtype,
        UInt64(n1),
        UInt64(n2),
        UInt64(n3),
    )
    array = Array3D(ptr, device, (n1, n2, n3), T)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{T}(mapped), pointer(flat), length(flat))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

"""
    map_array(device, array::Union{Array1D, Array2D, Array3D})

Map the array for CPU access. If `array.eltype === Any`, returns `Ptr{Cvoid}`; otherwise returns a wrapped
`Vector`, `Matrix`, or rank-3 `Array` view using stored length or `dims`.
"""
function map_array(device::Device, array::Array1D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    data_ptr = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(data_ptr) && throw(ErrorException("anariMapArray returned a null data pointer"))
    T = array.eltype
    if T === Any
        return data_ptr
    end
    return unsafe_wrap(Vector{T}, Ptr{T}(data_ptr), Int(array.length))
end

function map_array(device::Device, array::Array2D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    data_ptr = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(data_ptr) && throw(ErrorException("anariMapArray returned a null data pointer"))
    T = array.eltype
    if T === Any
        return data_ptr
    end
    n1, n2 = Int(array.dims[1]), Int(array.dims[2])
    return unsafe_wrap(Array{T,2}, Ptr{T}(data_ptr), (n1, n2))
end

function map_array(device::Device, array::Array3D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    data_ptr = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(data_ptr) && throw(ErrorException("anariMapArray returned a null data pointer"))
    T = array.eltype
    if T === Any
        return data_ptr
    end
    n1, n2, n3 = Int(array.dims[1]), Int(array.dims[2]), Int(array.dims[3])
    return unsafe_wrap(Array{T,3}, Ptr{T}(data_ptr), (n1, n2, n3))
end

"""
    unmap_array(device, array::Union{Array1D, Array2D, Array3D})

Unmap memory previously mapped with `map_array`.
"""
function unmap_array(device::Device, array::Array1D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    LibANARI.anariUnmapArray(device.ptr, array.ptr)
    return nothing
end

function unmap_array(device::Device, array::Array2D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    LibANARI.anariUnmapArray(device.ptr, array.ptr)
    return nothing
end

function unmap_array(device::Device, array::Array3D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    LibANARI.anariUnmapArray(device.ptr, array.ptr)
    return nothing
end
