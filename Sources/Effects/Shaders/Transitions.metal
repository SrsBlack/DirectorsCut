#include <metal_stdlib>
using namespace metal;

struct TransitionParams {
    float progress;     // 0.0 = fully source A, 1.0 = fully source B
    float direction;    // Used for directional transitions (0=left, 1=right, 2=up, 3=down)
    float softness;     // Edge softness for wipes
};

// Cross dissolve - simple blend between two textures
kernel void crossDissolve(
    texture2d<float, access::read> texA [[texture(0)]],
    texture2d<float, access::read> texB [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant TransitionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float4 colorA = texA.read(gid);
    float4 colorB = texB.read(gid);
    output.write(mix(colorA, colorB, params.progress), gid);
}

// Wipe transition - reveals B from a direction
kernel void wipeTransition(
    texture2d<float, access::read> texA [[texture(0)]],
    texture2d<float, access::read> texB [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant TransitionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float w = float(output.get_width());
    float h = float(output.get_height());
    float x = float(gid.x);
    float y = float(gid.y);

    float edge;
    int dir = int(params.direction);
    if (dir == 0) {       // left to right
        edge = x / w;
    } else if (dir == 1) { // right to left
        edge = 1.0 - x / w;
    } else if (dir == 2) { // top to bottom
        edge = y / h;
    } else {                // bottom to top
        edge = 1.0 - y / h;
    }

    float blend = smoothstep(params.progress - params.softness, params.progress + params.softness, edge);

    float4 colorA = texA.read(gid);
    float4 colorB = texB.read(gid);
    output.write(mix(colorB, colorA, blend), gid);
}

// Fade to color (black or white)
kernel void fadeTransition(
    texture2d<float, access::read> texA [[texture(0)]],
    texture2d<float, access::read> texB [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant TransitionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float fadeColor = params.direction; // 0 = black, 1 = white
    float4 color;

    if (params.progress < 0.5) {
        // First half: fade source A to color
        float t = params.progress * 2.0;
        float4 colorA = texA.read(gid);
        color = mix(colorA, float4(fadeColor, fadeColor, fadeColor, 1.0), t);
    } else {
        // Second half: fade color to source B
        float t = (params.progress - 0.5) * 2.0;
        float4 colorB = texB.read(gid);
        color = mix(float4(fadeColor, fadeColor, fadeColor, 1.0), colorB, t);
    }

    output.write(color, gid);
}

// Zoom transition
kernel void zoomTransition(
    texture2d<float, access::read> texA [[texture(0)]],
    texture2d<float, access::read> texB [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant TransitionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float w = float(output.get_width());
    float h = float(output.get_height());
    float2 center = float2(0.5);
    float2 uv = float2(float(gid.x) / w, float(gid.y) / h);

    bool zoomIn = params.direction == 0.0;

    if (zoomIn) {
        // Zoom in on A, then show B
        float scale = 1.0 + params.progress * 2.0;
        float2 zoomedUV = (uv - center) / scale + center;

        if (params.progress < 0.5) {
            uint2 samplePos = uint2(zoomedUV * float2(w, h));
            samplePos = clamp(samplePos, uint2(0), uint2(uint(w-1), uint(h-1)));
            output.write(texA.read(samplePos), gid);
        } else {
            float revScale = 3.0 - params.progress * 2.0;
            float2 revUV = (uv - center) / revScale + center;
            uint2 samplePos = uint2(revUV * float2(w, h));
            samplePos = clamp(samplePos, uint2(0), uint2(uint(w-1), uint(h-1)));
            output.write(texB.read(samplePos), gid);
        }
    } else {
        // Zoom out from B
        float scale = 3.0 - params.progress * 2.0;
        float2 zoomedUV = (uv - center) / scale + center;

        if (params.progress < 0.5) {
            output.write(texA.read(gid), gid);
        } else {
            uint2 samplePos = uint2(zoomedUV * float2(w, h));
            samplePos = clamp(samplePos, uint2(0), uint2(uint(w-1), uint(h-1)));
            float t = (params.progress - 0.5) * 2.0;
            float4 colorA = texA.read(gid);
            float4 colorB = texB.read(samplePos);
            output.write(mix(colorA, colorB, t), gid);
        }
    }
}
