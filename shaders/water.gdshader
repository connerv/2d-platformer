shader_type canvas_item;
#define iTime TIME
#define fragColor COLOR

uniform float uv_scale : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float color_alpha : hint_range(0.0, 1.0, 0.1) = 1.0;
uniform float reflection_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float distortion_strength : hint_range(0.0, 0.05, 0.001) = 0.01;
uniform float wave_speed : hint_range(0.0, 5.0, 0.05) = 1.0;
uniform float reflection_fade : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float rect_height = 0.5;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float noise(in vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2  i = floor(p + (p.x + p.y) * K1);
    vec2  a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    vec2  o = vec2(m, 1.0 - m);
    vec2  b = a - o + K2;
    vec2  c = a - 1.0 + 2.0 * K2;
    vec3  h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3  n = h*h*h*h * vec3(dot(a, hash(i+0.0)), dot(b, hash(i+o)), dot(c, hash(i+1.0)));
    return dot(n, vec3(70.0));
}
#define MAX_WAVES 4
#define SUPERPOSITION 4
#define TAU 6.28318
#define PHI 1.618
float height(vec2 p, float t) {
    float acc = 0.0;
    for (int i = 0; i < MAX_WAVES; i++) {
    for (int j = 0; j < SUPERPOSITION; j++) {
        int seed = i + 5 * j;
        float theta = TAU * PHI * 10.0 * float(seed);
        float up = cos(theta) * p.x - sin(theta) * p.y;
        float vp = sin(theta) * p.x + cos(theta) * p.y;
        float initial_phase = TAU * PHI * float(seed);
        float k = pow(2.0, float(i));
        float phase = initial_phase + up * k + cos(vp) + 3.0 * t + 0.5 * k * t;
        acc += cos(phase) / (k * k);
    }}
    return acc;
}
vec4 hn_fdm(vec2 p, float t) {
    float h = height(p, t);
    vec2 vx = vec2(0.1, 0.0);
    vec2 vy = vec2(0.0, 0.1);
    vec3 v1 = normalize(vec3(vx.x, 0.0, height(p+vx, t) - h));
    vec3 v2 = normalize(vec3(0.0, vy.y, height(p+vy, t) - h));
    return vec4(cross(v1, v2), h);
}

void fragment() {
    vec2 uv_screen = (UV - 0.5) * uv_scale;
    vec4 nh = hn_fdm(uv_screen * 10.0, iTime * wave_speed);
    vec3 norm = nh.xyz;

    vec3 sun_dir = normalize(vec3(-0.2, 0.4, 1.0));
    vec4 water_colour    = vec4(0.2, 0.4, 0.6, 1.0);
    vec4 sky_colour      = vec4(0.2, 0.6, 0.8, 1.0);
    vec4 specular_colour = vec4(1.0, 1.0, 1.0, 1.0);

    vec4 water_color;
    if (dot(sun_dir, norm) > 0.98) {
        water_color = specular_colour;
    } else {
        water_color = mix(water_colour, sky_colour, dot(norm, normalize(vec3(0.0, 0.2, 1.0))));
    }

    float screen_top_y = SCREEN_UV.y - UV.y * rect_height;
    float reflected_y  = screen_top_y - UV.y * rect_height;
    vec2 reflected_uv  = vec2(SCREEN_UV.x, reflected_y);
    reflected_uv += norm.xy * distortion_strength;

    // Fade reflection top (UV.y=0, full) to bottom (UV.y=1, gone)
    // reflection_fade controls how aggressively it fades:
    // 0.0 = no fade, 1.0 = fades completely by the bottom
    float fade = 1.0 - pow(UV.y, 1.0 - reflection_fade + 0.001);
    float effective_reflection = reflection_strength * clamp(fade, 0.0, 1.0);

    vec4 reflection = texture(screen_texture, reflected_uv);
    fragColor = mix(water_color, reflection, effective_reflection);
    fragColor.a = color_alpha;
}