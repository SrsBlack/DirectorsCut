#include <metal_stdlib>
using namespace metal;

struct SharpenParams {
    float amount;   // 0.0 to 2.0
};

kernel void sharpen(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant SharpenParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;
    if (gid.x == 0 || gid.y == 0 ||
        gid.x >= input.get_width() - 1 || gid.y >= input.get_height() - 1) {
        output.write(input.read(gid), gid);
        return;
    }

    // Unsharp mask: center - surrounding average
    float4 center = input.read(gid);
    float4 top    = input.read(uint2(gid.x, gid.y - 1));
    float4 bottom = input.read(uint2(gid.x, gid.y + 1));
    float4 left   = input.read(uint2(gid.x - 1, gid.y));
    float4 right  = input.read(uint2(gid.x + 1, gid.y));

    float4 avg = (top + bottom + left + right) * 0.25;
    float4 sharpened = center + (center - avg) * params.amount;

    output.write(float4(saturate(sharpened.rgb), center.a), gid);
}
