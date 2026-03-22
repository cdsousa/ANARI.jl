export render!, wait_frame!, render_and_wait!, map_frame, unmap_frame

function render!(device::Device, frame::Frame)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(frame.ptr) && throw(ArgumentError("frame handle has already been released"))

    LibANARI.anariRenderFrame(device.ptr, frame.ptr)
    return frame
end

function wait_frame!(
    device::Device,
    frame::Frame;
    mode::LibANARI.ANARIWaitMask=LibANARI.ANARIWaitMask(LibANARI.ANARI_WAIT),
)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(frame.ptr) && throw(ArgumentError("frame handle has already been released"))

    return LibANARI.anariFrameReady(device.ptr, frame.ptr, mode)
end

function render_and_wait!(
    device::Device,
    frame::Frame;
    mode::LibANARI.ANARIWaitMask=LibANARI.ANARIWaitMask(LibANARI.ANARI_WAIT),
)
    render!(device, frame)
    return wait_frame!(device, frame; mode=mode)
end

function map_frame(device::Device, frame::Frame, channel::AbstractString="color")
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(frame.ptr) && throw(ArgumentError("frame handle has already been released"))

    width_ref = Ref{UInt32}(0)
    height_ref = Ref{UInt32}(0)
    pixel_type_ref = Ref{LibANARI.ANARIDataType}(LibANARI.ANARI_UNKNOWN)

    data_ptr = LibANARI.anariMapFrame(
        device.ptr,
        frame.ptr,
        channel,
        width_ref,
        height_ref,
        pixel_type_ref,
    )
    _isnull(data_ptr) && throw(ErrorException("anariMapFrame returned a null data pointer"))

    return data_ptr, width_ref[], height_ref[], pixel_type_ref[]
end

function unmap_frame(device::Device, frame::Frame, channel::AbstractString="color")
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(frame.ptr) && throw(ArgumentError("frame handle has already been released"))

    LibANARI.anariUnmapFrame(device.ptr, frame.ptr, channel)
    return nothing
end
