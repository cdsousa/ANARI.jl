export new_array1d, map_array, unmap_array

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
    array = Array1D(ptr, device)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{T}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

function map_array(device::Device, array::Array1D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    data_ptr = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(data_ptr) && throw(ErrorException("anariMapArray returned a null data pointer"))
    return data_ptr
end

function unmap_array(device::Device, array::Array1D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    LibANARI.anariUnmapArray(device.ptr, array.ptr)
    return nothing
end
