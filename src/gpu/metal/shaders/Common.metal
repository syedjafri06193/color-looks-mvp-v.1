#include <metal_stdlib>
using namespace metal;

struct ColorLooksParamsCommon
{
    uint  width;
    uint  height;

    float exposureStops;   // [-20..+20]
    float contrast;        // [0.1..4.0]
    float pivot;           // linear pivot, e.g. 0.18
    float saturation;      // [0..4]

    float filmStrength;    // [0..1]
    float grainAmount;     // [0..1]
    uint  frameIndex;      // temporal seed for grain stability
};

// Rec.709 luminance (works fine as a base; you can swap to ACES AP1 coefficients later)
inline float luminance(float3 rgb)
{
    return dot(rgb, float3(0.2126, 0.7152, 0.0722));
}

inline float3 safeLog2(float3 x) { return log2(max(x, float3(1e-6))); }
inline float3 safeExp2(float3 x) { return exp2(x); }
