#version 450

// CRT-SatPixie for RetroArch (slang)
// Based on the simplified ReShade version
// Features: Aspect-aware vignette, toggleable shadow mask, Natural Vision mode, 
// Improved chromatic aberration with working blur, Geometry controls

#pragma name "CRT-SatPixie"
#pragma version 1.2
#pragma author "Adapted from NewPixie and forks"

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float acc_modulate;
	float natural_vision;
	float gamma;
	float ghosting_on;
	float chroma_on;
	float chroma_strength;
	float vignette_on;
	float vignette_aspect;
	float wiggle_toggle;
	float scanroll;
	float ShadowMaskMode;
	float enable_geometry_controls;
	float stretch_vertical;
	float stretch_horizontal;
	float offset_horizontal;
	float offset_vertical;
} params;

#pragma parameter acc_modulate "Accumulate Modulation" 0.65 0.0 1.0 0.01
#pragma parameter natural_vision "Natural Vision Mode" 1.0 0.0 1.0 1.0
#pragma parameter gamma "Gamma (Natural Vision only)" 2.3 1.8 2.6 0.1
#pragma parameter ghosting_on "Ghosting" 0.0 0.0 1.0 1.0
#pragma parameter chroma_on "Chromatic Aberration" 1.0 0.0 1.0 1.0
#pragma parameter chroma_strength "Chroma Strength" 0.7 0.0 5.0 0.1
#pragma parameter vignette_on "Vignette" 1.0 0.0 1.0 1.0
#pragma parameter vignette_aspect "Vignette Aspect (0=Wide,1=Pillarbox)" 1.0 0.0 1.0 1.0
#pragma parameter wiggle_toggle "Interference" 0.0 0.0 1.0 1.0
#pragma parameter scanroll "Rolling Scanlines" 1.0 0.0 1.0 1.0
#pragma parameter ShadowMaskMode "Shadow Mask (0=Off,1=Brightness,2=Color)" 0.0 0.0 2.0 1.0
#pragma parameter enable_geometry_controls "Enable Geometry Controls" 0.0 0.0 1.0 1.0
#pragma parameter stretch_vertical "Vertical Stretch (%)" 100.0 80.0 130.0 1.0
#pragma parameter stretch_horizontal "Horizontal Stretch (%)" 100.0 80.0 130.0 1.0
#pragma parameter offset_horizontal "Horizontal Position" 0.0 -200.0 200.0 1.0
#pragma parameter offset_vertical "Vertical Position" 0.0 -200.0 200.0 1.0

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
layout(set = 0, binding = 3) uniform sampler2D accum1;  // Accumulation texture
layout(set = 0, binding = 4) uniform sampler2D blur2;   // Blurred texture (should be used for main color!)

vec3 tsample(sampler2D samp, vec2 tc, float offs, vec2 resolution)
{
	// Apply geometry controls if enabled
	if (params.enable_geometry_controls > 0.5) {
		// Convert offset to UV space
		float h_offset = params.offset_horizontal / 555.0;
		float v_offset = params.offset_vertical / 555.0;
		
		// Apply position offset first (shift the image)
		tc.x += h_offset;
		tc.y += v_offset;
		
		// Convert stretch (100 = 1.0, 110 = 1.1, 90 = 0.9)
		float stretch_h = params.stretch_horizontal / 100.0;
		float stretch_v = params.stretch_vertical / 100.0;
		
		// Apply stretch from center
		tc.x = 0.5 + ((tc.x - 0.5) / stretch_h);
		tc.y = 0.5 + ((tc.y - 0.5) / stretch_v);
	}
	
	// Return black for out-of-bounds sampling
	if (tc.x < 0.0 || tc.x > 1.0 || tc.y < 0.0 || tc.y > 1.0) {
		return vec3(0.0);
	}
	
	// No overscan crop - use geometry controls instead for positioning
	// No curvature scaling or border blur
	vec3 s = pow(abs(texture(samp, vec2(tc.x, 1.0 - tc.y)).rgb), vec3(2.2));
	return s * vec3(1.25);
}

vec3 filmic(vec3 LinearColor)
{
	vec3 x = max(vec3(0.0), LinearColor - vec3(0.004));
	return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

float rand(vec2 co)
{
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

#define resolution params.OutputSize.xy

void main()
{
	float time = mod(float(params.FrameCount), 849.0) * 36.0;
	vec2 uv = vTexCoord.xy;
	uv.y = 1.0 - uv.y;
	
	// STRAIGHT UV (no curve distortion!)
	vec2 scuv = uv;
	
	/* Main color, Bleed (chroma toggleable) */
	vec3 col;
	
	float x = params.wiggle_toggle * sin(0.1 * time + uv.y * 13.0) * 
			  sin(0.23 * time + uv.y * 19.0) * 
			  sin(0.3 + 0.11 * time + uv.y * 23.0) * 0.0012;
	float o = sin(uv.y * 1.5) / resolution.x;
	x += o * 0.25;
	
	time = float(mod(params.FrameCount, 640)) * 1.0;
	
	/* FIXED: Use blurred texture (blur2) for main color, not accumulation texture (accum1) */
	if (params.chroma_on > 0.5)
	{
		// Apply chromatic aberration using BLURRED texture
		float strength = params.chroma_strength * 0.0015; // Scale to reasonable values
		
		// Red channel: shifted right and up
		col.r = tsample(blur2, vec2(x + scuv.x + strength, scuv.y + strength * 0.7), 
						resolution.y / 800.0, resolution).x + 0.02;
		
		// Green channel: centered (reference)
		col.g = tsample(blur2, vec2(x + scuv.x, scuv.y), 
						resolution.y / 800.0, resolution).y + 0.02;
		
		// Blue channel: shifted left and down
		col.b = tsample(blur2, vec2(x + scuv.x - strength, scuv.y - strength * 0.7), 
						resolution.y / 800.0, resolution).z + 0.02;
	}
	else
	{
		// No chromatic aberration - all channels aligned, still using BLURRED texture
		vec3 aligned = tsample(blur2, vec2(x + scuv.x, scuv.y), 
							   resolution.y / 800.0, resolution).rgb + 0.02;
		col = aligned;
	}
	
	float i = clamp(col.r * 0.299 + col.g * 0.587 + col.b * 0.114, 0.0, 1.0);
	i = pow(1.0 - pow(i, 2.0), 1.0);
	i = (1.0 - i) * 0.85 + 0.15;
	
	/* Ghosting (toggleable) */
	float ghs = 0.15;
	if (params.ghosting_on > 0.5)
	{
		// Apply chromatic aberration to ghosting as well
		float ghost_chroma = params.chroma_on > 0.5 ? params.chroma_strength * 0.001 : 0.0;
		
		// FIXED: Ghosting already uses blur2 correctly
		vec3 r = tsample(blur2, vec2(x - 0.014 * 1.0 + ghost_chroma, -0.027 + ghost_chroma * 0.7) * 0.85 + 0.007 * vec2(
			0.35 * sin(1.0 / 7.0 + 15.0 * uv.y + 0.9 * time),
			0.35 * sin(2.0 / 7.0 + 10.0 * uv.y + 1.37 * time)) + 
			vec2(scuv.x + 0.001, scuv.y + 0.001),
			5.5 + 1.3 * sin(3.0 / 9.0 + 31.0 * uv.x + 1.70 * time), resolution).xyz * 
			vec3(0.5, 0.25, 0.25);
		
		vec3 g = tsample(blur2, vec2(x - 0.019 * 1.0, -0.020) * 0.85 + 0.007 * vec2(
			0.35 * cos(1.0 / 9.0 + 15.0 * uv.y + 0.5 * time),
			0.35 * sin(2.0 / 9.0 + 10.0 * uv.y + 1.50 * time)) + 
			vec2(scuv.x + 0.000, scuv.y - 0.002),
			5.4 + 1.3 * sin(3.0 / 3.0 + 71.0 * uv.x + 1.90 * time), resolution).xyz * 
			vec3(0.25, 0.5, 0.25);
		
		vec3 b = tsample(blur2, vec2(x - 0.017 * 1.0 - ghost_chroma, -0.003 - ghost_chroma * 0.7) * 0.85 + 0.007 * vec2(
			0.35 * sin(2.0 / 3.0 + 15.0 * uv.y + 0.7 * time),
			0.35 * cos(2.0 / 3.0 + 10.0 * uv.y + 1.63 * time)) + 
			vec2(scuv.x - 0.002, scuv.y + 0.000),
			5.3 + 1.3 * sin(3.0 / 7.0 + 91.0 * uv.x + 1.65 * time), resolution).xyz * 
			vec3(0.25, 0.25, 0.5);
		
		col += vec3(ghs * (1.0 - 0.299)) * pow(clamp(vec3(3.0) * r, vec3(0.0), vec3(1.0)), 
			  vec3(2.0)) * vec3(i);
		col += vec3(ghs * (1.0 - 0.587)) * pow(clamp(vec3(3.0) * g, vec3(0.0), vec3(1.0)), 
			  vec3(2.0)) * vec3(i);
		col += vec3(ghs * (1.0 - 0.114)) * pow(clamp(vec3(3.0) * b, vec3(0.0), vec3(1.0)), 
			  vec3(2.0)) * vec3(i);
	}
	
	/* Level adjustment (curves) - APPLY NATURAL VISION HERE */
	if (params.natural_vision > 0.5)
	{
		// Natural Vision: neutral gamma, no green tint
		col.rgb = pow(col.rgb, vec3(params.gamma / 2.2));
		col *= vec3(1.0, 1.0, 1.0);
	}
	else
	{
		// Original: green tint
		col *= vec3(0.95, 1.05, 0.95);
	}
	
	col = clamp(col * 1.3 + 0.75 * col * col + 1.25 * col * col * col * col * col, 
				vec3(0.0), vec3(10.0));
	
	/* Vignette (toggleable + aspect-aware) */
	if (params.vignette_on > 0.5)
	{
		float vignette = 1.0;
		vec2 vignetteUV = scuv; // Use straight UV
		
		if (params.vignette_aspect > 0.5) // Pillarbox mode (4:3 aspect for vignette)
		{
			float aspect = resolution.x / resolution.y;
			float targetAspect = 4.0 / 2.99;
			float scale = aspect / targetAspect;
			float border = (1.0 - (1.0 / scale)) * 0.5;
			
			if (vignetteUV.x > border && vignetteUV.x < (1.0 - border))
			{
				float vignetteX = (vignetteUV.x - border) / (1.0 - 2.0 * border);
				float vignetteY = vignetteUV.y;
				float vig = 16.0 * vignetteX * vignetteY * (1.0 - vignetteX) * (1.0 - vignetteY);
				vignette = 1.3 * pow(0.1 + vig, 0.5);
			}
		}
		else // Wide mode (fullscreen vignette)
		{
			float vig = 16.0 * vignetteUV.x * vignetteUV.y * 
					   (1.0 - vignetteUV.x) * (1.0 - vignetteUV.y);
			vignette = 1.3 * pow(0.1 + vig, 0.5);
		}
		
		col *= vignette;
	}
	
	time *= params.scanroll;
	
	/* Scanlines */
	float scans = clamp(0.35 + 0.18 * sin(6.0 * time - scuv.y * resolution.y * 1.5), 0.0, 1.0);
	float s = pow(scans, 0.9);
	col = col * vec3(s);
	
	/* Shadow mask - simplified with 3 modes (Off/Brightness/Color) */
	if (params.ShadowMaskMode > 0.5) // Mode 1 or 2
	{
		float maskU = vTexCoord.x;
		float warpedPx = maskU * resolution.x;
		float stripeWidth = 3.0;
		float idx = warpedPx / stripeWidth;
		float center = fract(idx) - 0.5;
		float aa = fwidth(idx);
		float maskLine = clamp(1.0 - abs(center) / aa, 0.0, 1.0);
		
		if (params.ShadowMaskMode < 1.5) // Mode 1: Brightness Lines
		{
			vec3 brightnessMask = mix(vec3(1.1), vec3(0.8), maskLine);
			col.rgb *= brightnessMask;
		}
		else // Mode 2: Color Mask
		{
			float stripePhase = fract(idx);
			vec3 phaseOffsets = vec3(0.0, 1.0 / 3.0, 2.0 / 3.0);
			vec3 rawDistance = abs(vec3(stripePhase) - phaseOffsets);
			vec3 circDistance = min(rawDistance, vec3(1.0) - rawDistance);
			vec3 maskLineRGB = clamp(vec3(1.0) - circDistance / aa, vec3(0.0), vec3(1.0));
			vec3 colorMask = mix(vec3(0.75), vec3(1.5), maskLineRGB);
			col.rgb *= colorMask;
		}
	}
	
	/* Tone map */
	col = filmic(col);
	
	/* Noise */
	vec2 seed = scuv * resolution.xy;
	col -= 0.015 * pow(vec3(rand(seed + time), rand(seed + time * 2.0), 
				   rand(seed + time * 3.0)), vec3(1.5));
	
	/* Flicker */
	col *= (1.0 - 0.004 * (sin(50.0 * time + uv.y * 2.0) * 0.5 + 0.5));
	
	FragColor = vec4(col, 1.0);
}