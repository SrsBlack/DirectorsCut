#include <metal_stdlib>
using namespace metal;

struct BlurParams {
    float radius;
    int kernelSize;
};

// Gaussian blur (two-pass separable for performance)
kernel void gaussianBlurHorizontal(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant BlurParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

    float sigma = params.radius;
    int radius = int(ceil(sigma * 2.0));
    radius = min(radius, 32);

    float4 sum = float4(0.0);
    float weightSum = 0.0;

    for (int x = -radius; x <= radius; x++) {
        int sampleX = int(gid.x) + x;
        if (sampleX < 0 || sampleX >= int(input.get_width())) continue;

        float weight = exp(-float(x * x) / (2.0 * sigma * sigma));
        sum += input.read(uint2(sampleX, gid.y)) * weight;
        weightSum += weight;
    }

    output.write(sum / weightSum, gid);
}

kernel void gaussianBlurVertical(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant BlurParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

    float sigma = params.radius;
    int radius = int(ceil(sigma * 2.0));
    radius = min(radius, 32);

    float4 sum = float4(0.0);
    float weightSum = 0.0;

    for (int y = -radius; y <= radius; y++) {
        int sampleY = int(gid.y) + y;
        if (sampleY < 0 || sampleY >= int(input.get_height())) continue;

        float weight = exp(-float(y * y) / (2.0 * sigma * sigma));
        sum += input.read(uint2(gid.x, sampleY)) * weight;
        weightSum += weight;
    }

    output.write(sum / weightSum, gid);
}
