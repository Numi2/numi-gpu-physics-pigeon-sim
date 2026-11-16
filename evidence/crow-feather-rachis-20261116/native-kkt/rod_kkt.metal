#include <metal_stdlib>
using namespace metal;
struct Input { float A[81]; float b[9]; float target[3]; uint index[3]; };
struct Output { float x[9]; float lambda[3]; uint status; };
inline bool factor(thread const float *a, thread float *l, uint n) {
 for(uint i=0;i<n*n;++i) l[i]=0.0f;
 for(uint i=0;i<n;++i) for(uint j=0;j<=i;++j) {
  float v=a[i*n+j]; for(uint k=0;k<j;++k) v-=l[i*n+k]*l[j*n+k];
  if(i==j) { if(!(v>0.0f)||!isfinite(v)) return false; l[i*n+j]=sqrt(v); }
  else {v/=l[j*n+j]; if(!isfinite(v))return false; l[i*n+j]=v;}
 } return true;
}
inline bool solve(thread const float *l, thread const float *b, thread float *x, uint n) {
 for(uint i=0;i<n;++i) {float v=b[i];for(uint j=0;j<i;++j)v-=l[i*n+j]*x[j]; x[i]=v/l[i*n+i];}
 for(int i=int(n)-1;i>=0;--i) {float v=x[i];for(uint j=uint(i)+1;j<n;++j)v-=l[j*n+uint(i)]*x[j];x[i]=v/l[uint(i)*n+uint(i)]; if(!isfinite(x[i]))return false;}
 return true;
}
kernel void rod_kkt(device const Input *inputs [[buffer(0)]], device Output *outputs [[buffer(1)]], uint id [[thread_position_in_grid]]) {
 Input in=inputs[id]; Output out={}; out.status=1;
 for(uint i=0;i<3;++i) if(in.index[i]>=9){outputs[id]=out;return;}
 float a[81],l[81],b[9],x[9];for(uint i=0;i<81;++i)a[i]=in.A[i];for(uint i=0;i<9;++i)b[i]=in.b[i];
 if(!factor(a,l,9)||!solve(l,b,x,9)){outputs[id]=out;return;}
 float responses[27];
 for(uint j=0;j<3;++j){float rhs[9],sol[9];for(uint i=0;i<9;++i)rhs[i]=(i==in.index[j])?1.0f:0.0f;if(!solve(l,rhs,sol,9)){outputs[id]=out;return;}for(uint i=0;i<9;++i)responses[j*9+i]=sol[i];}
 float w[9],wl[9],rhs[3],lambda[3];for(uint i=0;i<3;++i){rhs[i]=in.target[i]-x[in.index[i]];for(uint j=0;j<3;++j)w[i*3+j]=responses[j*9+in.index[i]];}
 if(!factor(w,wl,3)||!solve(wl,rhs,lambda,3)){outputs[id]=out;return;}
 for(uint i=0;i<9;++i){for(uint j=0;j<3;++j)x[i]+=responses[j*9+i]*lambda[j];if(!isfinite(x[i])){outputs[id]=out;return;}out.x[i]=x[i];}
 for(uint j=0;j<3;++j)out.lambda[j]=lambda[j];out.status=0;outputs[id]=out;
}
