#include <metal_stdlib>
using namespace metal;

struct ChromaKeyParams {
    float3 keyColor;    // The color to key out (e.g., green)
    float threshold;    // How close a color must be to the key (0.0-1.0)
    float smoothing;    // Edge smoothing amount (0.0-1.0)
};

kernel void chromaKey(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant ChromaKeyParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

    float4 color = input.read(gid);

    // Calculate color distance from key color in YCbCr space for better chroma keying
    float3 rgb = color.rgb;
    float3 key = params.keyColor;

    // Convert to YCbCr
    float y  =  0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
    float cb = -0.169 * rgb.r - 0.331 * rgb.g + 0.500 * rgb.b;
    float cr =  0.500 * rgb.r - 0.419 * rgb.g - 0.081 * rgb.b;

    float ky  =  0.299 * key.r + 0.587 * key.g + 0.114 * key.b;
    float kcb = -0.169 * key.r - 0.331 * key.g + 0.500 * key.b;
    float kcr =  0.500 * key.r - 0.419 * key.g - 0.081 * key.b;

    // Distance in chroma space (ignore luminance for better results)
    float dist = distance(float2(cb, cr), float2(kcb, kcr));

    // Compute alpha mask with smooth edges
    float alpha = smoothstep(params.threshold, params.threshold + params.smoothing, dist);

    // Spill suppression: reduce the key color component in semi-transparent areas
    float3 result = rgb;
    if (alpha < 1.0) {
        // Desaturate areas close to the key color
        float spillAmount = 1.0 - alpha;
        float gray = dot(result, float3(0.2126, 0.7152, 0.0722));
        result = mix(float3(gray), result, alpha);
    }

    output.write(float4(result, color.a * alpha), gid);
}
