#include <metal_stdlib>
using namespace metal;
kernel void edge_difference(device const float4* input [[buffer(0)]], device float4* output [[buffer(1)]], uint i [[thread_position_in_grid]]) {
 float4 a=input[i];
 float s=a.x-a.z;
 float bv=a.x-s;
 float err=(a.x-(s+bv))+(bv-a.z);
 float residual=err+(a.y-a.w);
 float hi=s+residual;
 float lo=residual-(hi-s);
 output[i]=float4(hi,lo,s,0.0f);
}
