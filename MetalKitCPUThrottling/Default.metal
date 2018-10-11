#include <metal_stdlib>
#include <simd/simd.h>

#import "AAPLShaderTypes.h"

using namespace metal;

// Vertex shader outputs and per-fragmeht inputs.  Includes clip-space position and vertex outputs
//  interpolated by rasterizer and fed to each fragment genterated by clip-space primitives.
typedef struct
{
  // The [[position]] attribute qualifier of this member indicates this value is the clip space
  //   position of the vertex wen this structure is returned from the vertex shader
  float4 clipSpacePosition [[position]];
  
  // Since this member does not have a special attribute qualifier, the rasterizer will
  //   interpolate its value with values of other vertices making up the triangle and
  //   pass that interpolated value to the fragment shader for each fragment in that triangle;
  float2 textureCoordinate;
  
} RasterizerData;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             constant AAPLVertex *vertexArray [[ buffer(AAPLVertexInputIndexVertices) ]])
{
  RasterizerData out;
  
  // Index into our array of positions to get the current vertex
  //   Our positons are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
  //   the origin)
  float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
  
  // THe output position of every vertex shader is in clip space (also known as normalized device
  //   coordinate space, or NDC).   A value of (-1.0, -1.0) in clip-space represents the
  //   lower-left corner of the viewport wheras (1.0, 1.0) represents the upper-right corner of
  //   the viewport.
  
  out.clipSpacePosition.xy = pixelSpacePosition;
  
  // Set the z component of our clip space position 0 (since we're only rendering in
  //   2-Dimensions for this sample)
  out.clipSpacePosition.z = 0.0;
  
  // Set the w component to 1.0 since we don't need a perspective divide, which is also not
  //   necessary when rendering in 2-Dimensions
  out.clipSpacePosition.w = 1.0;
  
  // Pass our input textureCoordinate straight to our output RasterizerData.  This value will be
  //   interpolated with the other textureCoordinate values in the vertices that make up the
  //   triangle.
  out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
  out.textureCoordinate.y = 1.0 - out.textureCoordinate.y;
  
  return out;
}

// Fragment function
fragment float4
samplingPassThroughShader(RasterizerData in [[stage_in]],
                          texture2d<half, access::sample> inTexture [[ texture(AAPLTextureIndexes) ]])
{
  constexpr sampler s(mag_filter::linear, min_filter::linear);
  
  return float4(inTexture.sample(s, in.textureCoordinate));
  
}

// Compute function example

kernel void compute_kernel_emit_pixel(
                                      texture2d<half, access::write> outTexture [[ texture(0) ]],
                                      ushort2 gid [[ thread_position_in_grid ]]) {
  // Echo a pixel value
  half4 pix = half4(1.0h, 0.5h, 0.0h, 1.0h);
  outTexture.write(pix, uint2(gid));
}
