#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SHARPNESS;
	float BLUR_AMOUNT;
} params;

#pragma parameter SHARPNESS "Sharpening Amount" 0.0 0.0 0.5 0.05
#pragma parameter BLUR_AMOUNT "Blur Amount" 0.5 0.0 1.0 0.1

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Simple Catmull-Rom bicubic
vec4 cubic(float v)
{
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) / 6.0;
}

vec3 bicubicSample(sampler2D tex, vec2 texCoord, vec2 texSize)
{
    vec2 invTexSize = 1.0 / texSize;
    
    texCoord = texCoord * texSize - 0.5;
    
    vec2 fxy = fract(texCoord);
    texCoord -= fxy;
    
    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);
    
    vec4 c = texCoord.xxyy + vec2(-0.5, +1.5).xyxy;
    
    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;
    
    offset *= invTexSize.xxyy;
    
    vec3 sample0 = texture(tex, offset.xz).rgb;
    vec3 sample1 = texture(tex, offset.yz).rgb;
    vec3 sample2 = texture(tex, offset.xw).rgb;
    vec3 sample3 = texture(tex, offset.yw).rgb;
    
    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);
    
    return mix(
        mix(sample3, sample2, sx),
        mix(sample1, sample0, sx),
        sy
    );
}

vec3 gaussianBlur(sampler2D tex, vec2 uv, vec2 texelSize, float amount)
{
    vec3 color = vec3(0.0);
    vec2 off = texelSize * amount;
    
    // 9-tap Gaussian blur
    color += texture(tex, uv + vec2(-off.x, -off.y)).rgb * 0.0947416;
    color += texture(tex, uv + vec2(0.0, -off.y)).rgb * 0.118318;
    color += texture(tex, uv + vec2(off.x, -off.y)).rgb * 0.0947416;
    
    color += texture(tex, uv + vec2(-off.x, 0.0)).rgb * 0.118318;
    color += texture(tex, uv).rgb * 0.147761;
    color += texture(tex, uv + vec2(off.x, 0.0)).rgb * 0.118318;
    
    color += texture(tex, uv + vec2(-off.x, off.y)).rgb * 0.0947416;
    color += texture(tex, uv + vec2(0.0, off.y)).rgb * 0.118318;
    color += texture(tex, uv + vec2(off.x, off.y)).rgb * 0.0947416;
    
    return color;
}

void main()
{
    vec3 color = bicubicSample(Source, vTexCoord, params.SourceSize.xy);
    
    // Apply blur if needed
    if (params.BLUR_AMOUNT > 0.0)
    {
        vec3 blurred = gaussianBlur(Source, vTexCoord, params.SourceSize.zw, params.BLUR_AMOUNT);
        color = mix(color, blurred, params.BLUR_AMOUNT);
    }
    
    // Unsharp mask sharpening
    if (params.SHARPNESS > 0.0)
    {
        vec3 blur = vec3(0.0);
        vec2 offset = params.SourceSize.zw;
        
        // 3x3 box blur
        blur += texture(Source, vTexCoord + vec2(-offset.x, -offset.y)).rgb;
        blur += texture(Source, vTexCoord + vec2(0.0, -offset.y)).rgb;
        blur += texture(Source, vTexCoord + vec2(offset.x, -offset.y)).rgb;
        blur += texture(Source, vTexCoord + vec2(-offset.x, 0.0)).rgb;
        blur += texture(Source, vTexCoord).rgb;
        blur += texture(Source, vTexCoord + vec2(offset.x, 0.0)).rgb;
        blur += texture(Source, vTexCoord + vec2(-offset.x, offset.y)).rgb;
        blur += texture(Source, vTexCoord + vec2(0.0, offset.y)).rgb;
        blur += texture(Source, vTexCoord + vec2(offset.x, offset.y)).rgb;
        blur /= 9.0;
        
        color = color + (color - blur) * params.SHARPNESS;
    }
    
    FragColor = vec4(color, 1.0);
}
