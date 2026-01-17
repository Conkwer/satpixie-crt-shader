#version 450

// satpixie CRT
// by Mattias Gustavsson
// adapted for slang by hunterk
// backported Albatross 1.1 features by request

/*
------------------------------------------------------------------------------
This software is available under 2 licenses - you may choose the one you like.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2016 Mattias Gustavsson
Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do 
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this 
software, either in source code form or as a compiled binary, for any purpose, 
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this 
software dedicate any and all copyright interest in the software to the public 
domain. We make this dedication for the benefit of the public at large and to 
the detriment of our heirs and successors. We intend this dedication to be an 
overt act of relinquishment in perpetuity of all present and future rights to 
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float use_frame;
	float curvature;
	float wiggle_toggle;
	float scanroll;
	float use_uv;
	float chroma_shift;
	float ghosting;
	float tint_mode;
	float vignette_intensity;
	float shadow_mask_mode;
} params;

#pragma parameter use_frame "Use Frame Image" 0.0 0.0 1.0 1.0
#pragma parameter curvature "Curvature" 0.0 0.0 2.0 0.05
#pragma parameter use_uv "Use Original UV (Flat)" 1.0 0.0 1.0 1.0
#pragma parameter wiggle_toggle "Interference" 0.0 0.0 1.0 1.0
#pragma parameter scanroll "Rolling Scanlines" 1.0 0.0 1.0 1.0
#pragma parameter chroma_shift "Chromatic Aberration" 0.0 0.0 1.0 1.0
#pragma parameter ghosting "Ghosting" 0.0 0.0 1.0 0.01
#pragma parameter tint_mode "Color Tint (0=Neutral,1=Warm,2=Cold,3=Default)" 0.0 0.0 3.0 1.0
#pragma parameter vignette_intensity "Vignette" 0.0 0.0 2.0 0.01
#pragma parameter shadow_mask_mode "Shadow Mask (0=Off,1=Brightness,2=Color)" 1.0 0.0 2.0 1.0

#define gl_FragCoord (vTexCoord.xy * params.OutputSize.xy)
#define backbuffer accum1
#define blurbuffer blur2
#define frametexture frametexture

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
   vec4 modpos = vec4(Position.x, 1.-Position.y, Position.z, Position.w);
   gl_Position = global.MVP * modpos;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D accum1;
layout(set = 0, binding = 4) uniform sampler2D blur2;
layout(set = 0, binding = 5) uniform sampler2D frametexture;

vec3 tsample( sampler2D samp, vec2 tc, float offs, vec2 resolution )
{
    tc = tc * vec2(1.025, 0.92) + vec2(-0.0125, 0.04);
    vec3 s = pow( abs( texture( samp, vec2( tc.x, 1.0-tc.y ) ).rgb), vec3( 2.2 ) );
    return s*vec3(1.25);
}
		
vec3 filmic( vec3 LinearColor )
{
    vec3 x = max( vec3(0.0), LinearColor-vec3(0.004));
    return (x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06);
}
		
vec2 curve(vec2 uv)
{
    if (params.curvature <= 0.0)
        return uv;

    vec2 res = params.OutputSize.xy;
    float aspect = res.x / res.y;

    uv -= 0.5;
    uv.x *= aspect;

    uv *= params.curvature;
    uv.x *= 1.0 + pow((abs(uv.y) / 4.0), 2.0);
    float y_curv = mix(1.0 + pow((abs(uv.x) / 3.0), 2.0), 1.0, 
                       step(abs(params.curvature - 1.0), 0.001));
    uv.y *= y_curv;
    uv /= params.curvature;

    uv.x /= aspect;
    uv += 0.5;
    uv = uv * 0.92 + 0.04;

    return uv;
}
		
float rand(vec2 co)
{
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
    
#define resolution params.OutputSize.xy

void main()
{
    float time = mod(float(params.FrameCount), 849.0) * 36.;
    vec2 uv = vTexCoord.xy;
    
    /* Curve */
    vec2 curved_uv = mix( curve( uv ), uv, 0.4 );
    float scale = -0.101;
    vec2 scuv = curved_uv*(1.0-scale)+scale/2.0+vec2(0.003, -0.001);
    
    // Albatross: use_uv toggle to bypass curvature distortion
    scuv = mix(scuv, uv, params.use_uv);
		
    /* Main color, Bleed */
    vec3 col;
    float x = params.wiggle_toggle* sin(0.1*time+curved_uv.y*13.0)*sin(0.23*time+curved_uv.y*19.0)*sin(0.3+0.11*time+curved_uv.y*23.0)*0.0012;
    float o = sin(gl_FragCoord.y*1.5)/resolution.x;
    x += o*0.25;
    
    time = float(mod(params.FrameCount, 640) * 1); 
    
	// Albatross: Chromatic aberration with conditional logic
	if (params.chroma_shift < 0.5) {
		// OFF: no chromatic aberration
		vec3 ccol = tsample(backbuffer, vec2(x+scuv.x, scuv.y), resolution.y/800.0, resolution);
		col = ccol.xyz + 0.02;
	} else {
		// ON: use original fixed offsets
		col.r = tsample(backbuffer, vec2(x+scuv.x+0.0009, scuv.y+0.0009), resolution.y/800.0, resolution).x+0.02;
		col.g = tsample(backbuffer, vec2(x+scuv.x+0.0000, scuv.y-0.0011), resolution.y/800.0, resolution).y+0.02;
		col.b = tsample(backbuffer, vec2(x+scuv.x-0.0015, scuv.y+0.0000), resolution.y/800.0, resolution).z+0.02;
	}

    
    float i = clamp(col.r*0.299 + col.g*0.587 + col.b*0.114, 0.0, 1.0 );
    i = pow( 1.0 - pow(i,2.0), 1.0 );
    i = (1.0-i) * 0.85 + 0.15; 
    
    /* Ghosting - Albatross: adjustable parameter */
    float ghs = params.ghosting;
    vec3 r = tsample(blurbuffer, vec2(x-0.014*1.0, -0.027)*0.85+0.007*vec2( 0.35*sin(1.0/7.0 + 15.0*curved_uv.y + 0.9*time), 
        0.35*sin( 2.0/7.0 + 10.0*curved_uv.y + 1.37*time) )+vec2(scuv.x+0.001,scuv.y+0.001),
        5.5+1.3*sin( 3.0/9.0 + 31.0*curved_uv.x + 1.70*time),resolution).xyz*vec3(0.5,0.25,0.25);
    vec3 g = tsample(blurbuffer, vec2(x-0.019*1.0, -0.020)*0.85+0.007*vec2( 0.35*cos(1.0/9.0 + 15.0*curved_uv.y + 0.5*time), 
        0.35*sin( 2.0/9.0 + 10.0*curved_uv.y + 1.50*time) )+vec2(scuv.x+0.000,scuv.y-0.002),
        5.4+1.3*sin( 3.0/3.0 + 71.0*curved_uv.x + 1.90*time),resolution).xyz*vec3(0.25,0.5,0.25);
    vec3 b = tsample(blurbuffer, vec2(x-0.017*1.0, -0.003)*0.85+0.007*vec2( 0.35*sin(2.0/3.0 + 15.0*curved_uv.y + 0.7*time), 
        0.35*cos( 2.0/3.0 + 10.0*curved_uv.y + 1.63*time) )+vec2(scuv.x-0.002,scuv.y+0.000),
        5.3+1.3*sin( 3.0/7.0 + 91.0*curved_uv.x + 1.65*time),resolution).xyz*vec3(0.25,0.25,0.5);
		
    col += vec3(ghs*(1.0-0.299))*pow(clamp(vec3(3.0)*r,vec3(0.0),vec3(1.0)),vec3(2.0))*vec3(i);
    col += vec3(ghs*(1.0-0.587))*pow(clamp(vec3(3.0)*g,vec3(0.0),vec3(1.0)),vec3(2.0))*vec3(i);
    col += vec3(ghs*(1.0-0.114))*pow(clamp(vec3(3.0)*b,vec3(0.0),vec3(1.0)),vec3(2.0))*vec3(i);
		
    /* Level adjustment (curves) - Albatross: Color tint modes */
    vec3 tintColor;
    if (params.tint_mode < 0.5) {
        tintColor = vec3(1.00, 1.00, 1.00);  // Neutral
    } else if (params.tint_mode < 1.5) {
        tintColor = vec3(1.05, 0.98, 0.95);  // Warm
    } else if (params.tint_mode < 2.5) {
        tintColor = vec3(0.95, 1.02, 1.07);  // Cold
    } else {
        tintColor = vec3(0.95, 1.05, 0.95);  // Default (original greenish)
    }
    
    col *= tintColor;
    col = clamp(col*1.3 + 0.75*col*col + 1.25*col*col*col*col*col, vec3(0.0), vec3(10.0));
		
    /* Vignette - Albatross: adjustable intensity */
    float vig = (0.1 + 1.0*16.0*curved_uv.x*curved_uv.y*(1.0-curved_uv.x)*(1.0-curved_uv.y));
    vig = 1.3*pow(vig,0.5);
    col *= mix(1.0, vig, params.vignette_intensity);
    
    time *= params.scanroll;
		
    /* Scanlines */
    float scans = clamp( 0.35+0.18*sin(6.0*time-curved_uv.y*resolution.y*1.5), 0.0, 1.0);
    float s = pow(scans,0.9);
    col = col * vec3(s);
		
    /* Shadow mask - Albatross: 3 modes */
    float maskU = vTexCoord.x;
    float warpedPx = maskU * resolution.x;
    float stripeWidth = 3.0;
    float idx = warpedPx / stripeWidth;
    float center = fract(idx) - 0.5;
    float aa = fwidth(idx);
    float maskLine = clamp(1.0 - abs(center) / aa, 0.0, 1.0);

    vec3 brightnessMask = mix(vec3(1.1), vec3(0.8), maskLine);
    float stripePhase = fract(idx);
    vec3 phaseOffsets = vec3(0.0, 1.0/3.0, 2.0/3.0);
    vec3 rawDistance = abs(vec3(stripePhase) - phaseOffsets);
    vec3 circDistance = min(rawDistance, vec3(1.0) - rawDistance);
    vec3 maskLineRGB = clamp(vec3(1.0) - circDistance / aa, vec3(0.0), vec3(1.0));
    vec3 colorMask = mix(vec3(0.75), vec3(1.5), maskLineRGB);

    vec3 finalMask = mix(
        vec3(1.0),
        mix(brightnessMask, colorMask, step(2.0, params.shadow_mask_mode)),
        step(1.0, params.shadow_mask_mode)
    );
    col.rgb *= finalMask;
		
    /* Tone map */
    col = filmic( col );
		
    /* Noise - Albatross: luminance-adaptive */
    vec2 seed = curved_uv*resolution.xy;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float noiseBase = 0.015;
    float scaledNoise = mix(0.0, noiseBase, lum);
    float n = rand(seed + time) - 0.5;
    col += n * pow(scaledNoise, 1.0 + (1.0 - lum));
		
    /* Flicker */
    col *= (1.0-0.004*(sin(50.0*time+curved_uv.y*2.0)*0.5+0.5));

    uv = curved_uv;
    
    /* Frame */
    vec2 fscale = vec2( 0.026, -0.018);
    uv = vec2(uv.x, 1.-uv.y);
    vec4 f = texture(frametexture, vTexCoord.xy);
    f.xyz = mix( f.xyz, vec3(0.5,0.5,0.5), 0.5 );
    float fvig = clamp( -0.00+512.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y), 0.2, 0.8 );
    col = mix( col, mix( max( col, 0.0), pow( abs( f.xyz ), vec3( 1.4 ) ) * fvig, f.w * f.w), vec3( params.use_frame ) );
    
    FragColor = vec4( col, 1.0 );
}
