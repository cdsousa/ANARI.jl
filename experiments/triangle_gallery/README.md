# Triangle Gallery Sample

This sample application renders three Full HD images using `ANARI.jl` and saves them as PNG files.

Each image contains:
- Two triangles shown side-by-side.
- Left triangle in plain green.
- Right triangle with per-vertex RGB primary colors.
- Dark blue background.
- A 90 degree rotation step between consecutive images.

## Run

From the repository root:

```bash
julia experiments/triangle_gallery/run.jl
```

Generated images are written to `experiments/triangle_gallery/output/`.
