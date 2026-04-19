# ANARI.jl

This document describes the architectural and detailed design of the
`ANARI.jl` Julia package. It covers the package layout, the responsibilities
of each module, the type hierarchy, the lifetime/ownership model, the
parameter and rendering APIs, the data marshalling rules, and the diagnostics
bridge.

For a primer on the underlying ANARI API, see [about_ANARI.md](about_ANARI.md).

---

## Layers architecture

The package is organized in two cleanly separated layers, a low-level FFI layer and a high-level idiomatic layer.
They depend on an external JLL package, `ANARI_SDK_jll`, for the C header and shared library.

###  Low-level FFI layer: `LibANARI`

A single file `src/LibANARI.jl` which is auto-generated from the C99 header `anari/anari.h` shipped by
`ANARI_SDK_jll` using *Clang.jl*'s `Generators` interface. It contains low-level bindings for
every C function, every opaque handle typedef, every enum, and every constant.
This file MUST NOT be hand-edited. All idiomatic behavior lives strictly in the higher layer.

### High-level idiomatic layer: `ANARI`

Entry point is file `src/ANARI.jl` that loads the low-level layer and includes source files for the various wrapper aspects.


---

