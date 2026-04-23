#include <metal_stdlib>
using namespace metal;

struct TransformParams {
    int flipHorizontal;   // 1 = flip, 0 = no flip
    int flipVertical;     // 1 = flip, 0 = no flip
};

kernel void transformFlip(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant TransformParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint w = input.get_width();
    uint h = input.get_height();
    if (gid.x >= w || gid.y >= h) return;

    uint srcX = params.flipHorizontal ? (w - 1 - gid.x) : gid.x;
    uint srcY = params.flipVertical   ? (h - 1 - gid.y) : gid.y;

    output.write(input.read(uint2(srcX, srcY)), gid);
}

// Film grain effect — adds random noise to simulate analog film
struct FilmGrainParams {
    float intensity;    // 0.0 to 1.0
    float time;         // frame time for varying the noise pattern
};

// Simple hash function for deterministic noise
float hash(float2 p, float seed) {
    float h = dot(p, float2(127.1 + seed, 311.7 + seed));
    return fract(sin(h) * 43758.5453123);
}

kernel void filmGrain(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant FilmGrainParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

    float4 color = input.read(gid);
    float2 uv = float2(gid) / float2(input.get_width(), input.get_height());

    float noise = hash(uv * 1000.0, params.time) * 2.0 - 1.0;
    float3 grain = color.rgb + float3(noise) * params.intensity * 0.15;

    output.write(float4(saturate(grain), color.a), gid);
}
