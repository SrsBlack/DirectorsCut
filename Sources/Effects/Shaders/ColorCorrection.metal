#include <metal_stdlib>
using namespace metal;

// Color correction parameters
struct ColorParams {
    float brightness;   // -1.0 to 1.0
    float contrast;     // 0.0 to 4.0 (1.0 = no change)
    float saturation;   // 0.0 to 4.0 (1.0 = no change)
    float temperature;  // 1000 to 40000 (6500 = daylight)
    float tint;         // -1.0 to 1.0
    float exposure;     // -3.0 to 3.0 (0.0 = no change)
    float highlights;   // -1.0 to 1.0
    float shadows;      // -1.0 to 1.0
};

// Convert RGB to HSL
float3 rgbToHsl(float3 rgb) {
    float maxC = max(max(rgb.r, rgb.g), rgb.b);
    float minC = min(min(rgb.r, rgb.g), rgb.b);
    float l = (maxC + minC) / 2.0;
    float s = 0.0;
    float h = 0.0;

    if (maxC != minC) {
        float d = maxC - minC;
        s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);

        if (maxC == rgb.r) {
            h = (rgb.g - rgb.b) / d + (rgb.g < rgb.b ? 6.0 : 0.0);
        } else if (maxC == rgb.g) {
            h = (rgb.b - rgb.r) / d + 2.0;
        } else {
            h = (rgb.r - rgb.g) / d + 4.0;
        }
        h /= 6.0;
    }
    return float3(h, s, l);
}

float hueToRgb(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0/2.0) return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

// Convert HSL to RGB
float3 hslToRgb(float3 hsl) {
    if (hsl.y == 0.0) {
        return float3(hsl.z);
    }
    float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
    float p = 2.0 * hsl.z - q;
    return float3(
        hueToRgb(p, q, hsl.x + 1.0/3.0),
        hueToRgb(p, q, hsl.x),
        hueToRgb(p, q, hsl.x - 1.0/3.0)
    );
}

// White balance: approximate color temperature to RGB multiplier
float3 temperatureToRgb(float kelvin) {
    float temp = kelvin / 100.0;
    float r, g, b;

    if (temp <= 66.0) {
        r = 1.0;
        g = saturate(0.39008157876901960784 * log(temp) - 0.63184144378862745098);
    } else {
        r = saturate(1.29293618606274509804 * pow(temp - 60.0, -0.1332047592));
        g = saturate(1.12989086089529411765 * pow(temp - 60.0, -0.0755148492));
    }

    if (temp >= 66.0) {
        b = 1.0;
    } else if (temp <= 19.0) {
        b = 0.0;
    } else {
        b = saturate(0.54320678911019607843 * log(temp - 10.0) - 1.19625408914);
    }

    return float3(r, g, b);
}

kernel void colorCorrection(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant ColorParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

    float4 color = input.read(gid);
    float3 rgb = color.rgb;

    // Exposure
    rgb *= pow(2.0, params.exposure);

    // Temperature (white balance)
    float3 tempColor = temperatureToRgb(params.temperature);
    float3 daylight = temperatureToRgb(6500.0);
    rgb *= tempColor / daylight;

    // Tint (green-magenta)
    rgb.g *= (1.0 + params.tint * 0.5);

    // Brightness
    rgb += params.brightness;

    // Contrast
    rgb = (rgb - 0.5) * params.contrast + 0.5;

    // Highlights & Shadows
    float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    float highlightMask = smoothstep(0.5, 1.0, luminance);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luminance);
    rgb += params.highlights * highlightMask * 0.5;
    rgb += params.shadows * shadowMask * 0.5;

    // Saturation
    float3 hsl = rgbToHsl(saturate(rgb));
    hsl.y *= params.saturation;
    rgb = hslToRgb(hsl);

    output.write(float4(saturate(rgb), color.a), gid);
}
