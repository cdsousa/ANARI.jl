#include <cstdio>
#include "anari/anari_cpp.hpp"
#include "anari/anari_cpp/ext/std.h"
using namespace anari::std_types;

static void printRgb(const uint32_t* px, int i) {
  uint32_t p = px[i];
  printf("pixel[%d]: %u %u %u\n", i, p & 255u, (p >> 8) & 255u, (p >> 16) & 255u);
}

int main() {
  auto lib = anari::loadLibrary("helide");
  auto d = anari::newDevice(lib, "default");

  auto cam = anari::newObject<anari::Camera>(d, "perspective");
  anari::setParameter(d, cam, "position", vec3{0, 0, 3});
  anari::setParameter(d, cam, "direction", vec3{0, 0, -1});
  anari::commitParameters(d, cam);

  auto ren = anari::newObject<anari::Renderer>(d, "default");
  anari::setParameter(d, ren, "background", vec3{0.02f, 0.02f, 0.03f});
  anari::commitParameters(d, ren);

  vec3 vtx[] = {{-1, -1, 0}, {1, -1, 0}, {0, 1, 0}};
  uvec3 idx[] = {{0, 1, 2}};
  auto geo = anari::newObject<anari::Geometry>(d, "triangle");
  anari::setParameterArray1D(d, geo, "vertex.position", vtx, 3);
  anari::setParameterArray1D(d, geo, "primitive.index", idx, 1);
  anari::commitParameters(d, geo);

  auto mat = anari::newObject<anari::Material>(d, "matte");
  anari::commitParameters(d, mat);

  auto surf = anari::newObject<anari::Surface>(d);
  anari::setAndReleaseParameter(d, surf, "geometry", geo);
  anari::setAndReleaseParameter(d, surf, "material", mat);
  anari::commitParameters(d, surf);

  auto grp = anari::newObject<anari::Group>(d);
  anari::setParameterArray1D(d, grp, "surface", &surf, 1);
  anari::release(d, surf);
  anari::commitParameters(d, grp);

  auto inst = anari::newObject<anari::Instance>(d, "transform");
  anari::setAndReleaseParameter(d, inst, "group", grp);
  anari::commitParameters(d, inst);

  auto world = anari::newObject<anari::World>(d);
  anari::setParameterArray1D(d, world, "instance", &inst, 1);
  anari::release(d, inst);
  anari::commitParameters(d, world);

  uvec2 size = {800, 600};
  auto frame = anari::newObject<anari::Frame>(d);
  anari::setParameter(d, frame, "size", size);
  anari::setParameter(d, frame, "channel.color", ANARI_UFIXED8_RGBA_SRGB);
  anari::setAndReleaseParameter(d, frame, "camera", cam);
  anari::setAndReleaseParameter(d, frame, "renderer", ren);
  anari::setAndReleaseParameter(d, frame, "world", world);
  anari::commitParameters(d, frame);

  anari::render(d, frame);
  anari::wait(d, frame);

  auto fb = anari::map<uint32_t>(d, frame, "channel.color");
  int w = int(fb.width), h = int(fb.height);
  printRgb(fb.data, 0);
  printRgb(fb.data, (h / 2) * w + w / 2);
  anari::unmap(d, frame, "channel.color");

  anari::release(d, frame);
  anari::release(d, d);
  anari::unloadLibrary(lib);
}
