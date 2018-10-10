#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

kernel void compute_kernel_emit_pixel(
                                             texture2d<half, access::write> outTexture [[ texture(0) ]],
                                             ushort2 gid [[ thread_position_in_grid ]]) {
  // Echo a pixel value
  half4 pix = half4(1.0h, 0.5h, 0.0h, 1.0h);
  outTexture.write(pix, uint2(gid));
}
