#include <metal_stdlib>
using namespace metal;

struct LUTParams {
    float intensity;    // 0.0 = no effect, 1.0 = full LUT
    int lutSize;        // Size of the LUT (typically 33 or 64)
};

// Apply a 3D LUT (color lookup table) to a frame
kernel void applyLUT(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    texture3d<float, access::sample> lut [[texture(2)]],
    constant LUTParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

    float4 color = input.read(gid);

    // Sample the 3D LUT
    constexpr sampler lutSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float3 lutCoord = saturate(color.rgb);
    float4 lutColor = lut.sample(lutSampler, lutCoord);

    // Blend between original and LUT-graded
    float3 result = mix(color.rgb, lutColor.rgb, params.intensity);

    output.write(float4(result, color.a), gid);
}
