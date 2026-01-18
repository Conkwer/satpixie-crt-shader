#include "ReShade.fxh"

// CRT-NewPixie (Curvature-Free)
// by Mattias Gustavsson
// adapted for slang by hunterk
// curvature/blur borders removed + UI toggles
// by Conkwer (SSF/Satpixie optimized)
// Gamma fix applied - Natural Vision now works correctly
// Chromatic Aberration toggle fixed

uniform float acc_modulate <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
	ui_label = "Accumulate Modulation";
> = 0.65;

uniform bool natural_vision <
	ui_type = "boolean";
	ui_label = "Natural Vision Mode";
> = false;

uniform float gamma <
	ui_type = "drag"; ui_min = 1.8; ui_max = 2.6; ui_step = 0.1;
	ui_label = "Gamma (Natural Vision only)";
> = 2.3;

uniform bool ghosting_on <
	ui_type = "boolean";
	ui_label = "Ghosting";
> = true;

uniform bool chroma_on <
	ui_type = "boolean";
	ui_label = "Chromatic Aberration";
> = true;

uniform bool vignette_on <
	ui_type = "boolean";
	ui_label = "Vignette";
> = true;

uniform bool wiggle_toggle <
	ui_type = "boolean";
	ui_label = "Interference";
> = false;

uniform bool scanroll <
	ui_type = "boolean";
	ui_label = "Rolling Scanlines";
> = true;

uniform float blur_x <
	ui_type = "drag"; ui_min = 0.0; ui_max = 5.0; ui_step = 0.25;
	ui_label = "Horizontal Blur";
> = 1.0;

uniform float blur_y <
	ui_type = "drag"; ui_min = 0.0; ui_max = 5.0; ui_step = 0.25;
	ui_label = "Vertical Blur";
> = 1.0;

// Textures & Passes (unchanged)
texture2D tAccTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler sAccTex { Texture=tAccTex; };

texture GaussianBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex; };

uniform int FCount < source = "framecount"; >;

// PASS 1-3 (unchanged)
float3 PrevColor(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv).rgb;
}

float4 PS_NewPixie_Accum(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
   float4 a = tex2D(sAccTex, uv.xy) * float4(acc_modulate,acc_modulate,acc_modulate,acc_modulate);
   float4 b = tex2D(ReShade::BackBuffer, uv.xy);
   return max( a, b * 0.96 );
}

float4 PS_NewPixie_Blur(float4 pos : SV_Position, float2 uv_tx : TEXCOORD0) : SV_Target
{
   float2 blur = float2(blur_x, blur_y) * ReShade::PixelSize.xy;
   float2 uv = uv_tx.xy;
   float4 sum = tex2D( ReShade::BackBuffer, uv ) * 0.2270270270;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x - 4.0 * blur.x, uv.y - 4.0 * blur.y ) ) * 0.0162162162;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x - 3.0 * blur.x, uv.y - 3.0 * blur.y ) ) * 0.0540540541;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x - 2.0 * blur.x, uv.y - 2.0 * blur.y ) ) * 0.1216216216;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x - 1.0 * blur.x, uv.y - 1.0 * blur.y ) ) * 0.1945945946;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x + 1.0 * blur.x, uv.y + 1.0 * blur.y ) ) * 0.1945945946;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x + 2.0 * blur.x, uv.y + 2.0 * blur.y ) ) * 0.1216216216;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x + 3.0 * blur.x, uv.y + 3.0 * blur.y ) ) * 0.0540540541;
   sum += tex2D(ReShade::BackBuffer, float2( uv.x + 4.0 * blur.x, uv.y + 4.0 * blur.y ) ) * 0.0162162162;
   return sum;
}

// Core functions (curvature removed)
float3 tsample( sampler samp, float2 tc, float offs, float2 resolution )
{
	// FIXED: No curvature scaling or border blur
	float3 s = pow( abs( tex2D( samp, float2( tc.x, 1.0-tc.y ) ).rgb), float3( 2.2,2.2,2.2 ) );
	return s*float3(1.25,1.25,1.25);
}
		
float3 filmic( float3 LinearColor )
{
	float3 x = max( float3(0.0,0.0,0.0), LinearColor-float3(0.004,0.004,0.004));
    return (x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06);
}

float rand(float2 co){ return frac(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453); }
    
#define resolution ReShade::ScreenSize.xy
#define mod(x,y) (x-y*floor(x/y))

float4 PS_NewPixie_Final(float4 pos: SV_Position, float2 uv_tx : TEXCOORD0) : SV_Target
{
   float time = mod(FCount, 849.0) * 36.0;
    float2 uv = uv_tx.xy;
	uv.y = 1.0 - uv_tx.y;
    
    // STRAIGHT UV (no curve distortion!)
    float2 scuv = uv;
	
    uv = scuv;
		
    /* Main color, Bleed (chroma toggleable) */
    float3 col;
	
    float x = wiggle_toggle* sin(0.1*time+uv.y*13.0)*sin(0.23*time+uv.y*19.0)*sin(0.3+0.11*time+uv.y*23.0)*0.0012;
    float o =sin(uv_tx.y*1.5)/resolution.x;
    x+=o*0.25;
    
    time = float(mod(FCount, 640) * 1); 
    
    float chroma_offs_x = chroma_on ? 0.0015 : 0.0;
    float chroma_offs_y = chroma_on ? 0.0011 : 0.0;
    
	col.r = tsample(GaussianBlurSampler,float2(x+scuv.x+0.0009,scuv.y+0.0009),resolution.y/800.0, resolution ).x+0.02;
	col.g = tsample(GaussianBlurSampler,float2(x+scuv.x+0.0000,scuv.y-chroma_offs_y),resolution.y/800.0, resolution ).y+0.02;
	col.b = tsample(GaussianBlurSampler,float2(x+scuv.x-chroma_offs_x,scuv.y+0.0000),resolution.y/800.0, resolution ).z+0.02;
    
    float i = clamp(col.r*0.299 + col.g*0.587 + col.b*0.114, 0.0, 1.0 );
    i = pow( 1.0 - pow(i,2.0), 1.0 );
    i = (1.0-i) * 0.85 + 0.15; 
    
    /* Ghosting (toggleable) */
    float ghs = 0.15;
    if (ghosting_on) {
        float3 r = tsample(GaussianBlurSampler, float2(x-0.014*1.0, -0.027)*0.85+0.007*float2( 0.35*sin(1.0/7.0 + 15.0*uv.y + 0.9*time), 
            0.35*sin( 2.0/7.0 + 10.0*uv.y + 1.37*time) )+float2(scuv.x+0.001,scuv.y+0.001),
            5.5+1.3*sin( 3.0/9.0 + 31.0*uv.x + 1.70*time),resolution).xyz*float3(0.5,0.25,0.25);
        float3 g = tsample(GaussianBlurSampler, float2(x-0.019*1.0, -0.020)*0.85+0.007*float2( 0.35*cos(1.0/9.0 + 15.0*uv.y + 0.5*time), 
            0.35*sin( 2.0/9.0 + 10.0*uv.y + 1.50*time) )+float2(scuv.x+0.000,scuv.y-0.002),
            5.4+1.3*sin( 3.0/3.0 + 71.0*uv.x + 1.90*time),resolution).xyz*float3(0.25,0.5,0.25);
        float3 b = tsample(GaussianBlurSampler, float2(x-0.017*1.0, -0.003)*0.85+0.007*float2( 0.35*sin(2.0/3.0 + 15.0*uv.y + 0.7*time), 
            0.35*cos( 2.0/3.0 + 10.0*uv.y + 1.63*time) )+float2(scuv.x-0.002,scuv.y+0.000),
            5.3+1.3*sin( 3.0/7.0 + 91.0*uv.x + 1.65*time),resolution).xyz*float3(0.25,0.25,0.5);
			
        col += float3(ghs*(1.0-0.299),ghs*(1.0-0.299),ghs*(1.0-0.299))*pow(clamp(float3(3.0,3.0,3.0)*r,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
        col += float3(ghs*(1.0-0.587),ghs*(1.0-0.587),ghs*(1.0-0.587))*pow(clamp(float3(3.0,3.0,3.0)*g,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
        col += float3(ghs*(1.0-0.114),ghs*(1.0-0.114),ghs*(1.0-0.114))*pow(clamp(float3(3.0,3.0,3.0)*b,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
    }
		
    /* Level adjustment (curves) */
    // APPLY NATURAL VISION HERE (before color grading)
    if (natural_vision) {
        col.rgb = pow(col.rgb, gamma/2.2);  // Neutral gamma
        col *= float3(1.0, 1.0, 1.0);  // Remove green tint
    } else {
        col *= float3(0.95,1.05,0.95);  // Original green tint
    }
    
    col = clamp(col*1.3 + 0.75*col*col + 1.25*col*col*col*col*col,float3(0.0,0.0,0.0),float3(10.0,10.0,10.0));
		
    /* Vignette (toggleable) */
    float vig = vignette_on ? (0.1 + 1.0*16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y)) : 1.0;
    vig = 1.3*pow(vig,0.5);
    col *= vig;
    
    time *= scanroll;
		
    /* Scanlines */
    float scans = clamp( 0.35+0.18*sin(6.0*time-uv.y*resolution.y*1.5), 0.0, 1.0);
    float s = pow(scans,0.9);
    col = col * float3(s,s,s);
		
    /* Vertical lines (shadow mask) */
    col*=1.0-0.23*(clamp((mod(uv_tx.xy.x, 3.0))/2.0,0.0,1.0));
		
    /* Tone map */
    col = filmic( col );
		
    /* Noise */
    float2 seed = uv*resolution.xy;
    col -= 0.015*pow(float3(rand( seed +time ), rand( seed +time*2.0 ), rand( seed +time * 3.0 ) ), float3(1.5,1.5,1.5) );
		
    /* Flicker */
    col *= (1.0-0.004*(sin(50.0*time+uv.y*2.0)*0.5+0.5));
    
    // NO FRAME/curvature clamps needed anymore

    return float4( col, 1.0 );
}

technique CRTNewPixie
{
	pass PS_CRTNewPixie_Accum
	{
		VertexShader=PostProcessVS;
		PixelShader=PS_NewPixie_Accum;
	}
	
	pass PS_CRTNewPixie_SaveBuffer {
		VertexShader=PostProcessVS;
		PixelShader=PrevColor;
		RenderTarget = tAccTex;
	}
	
	pass PS_CRTNewPixie_Blur
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_NewPixie_Blur;
		RenderTarget = GaussianBlurTex;
	}
	
	pass PS_CRTNewPixie_Final
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_NewPixie_Final;
	}
}