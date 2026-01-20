#include "ReShade.fxh"

// Satpixie CRT - Natural Vision Color Correction
// Replaced NTSC TV tints with PC monitor YIQ adjustment for games like Darkstone

// YIQ color space matrices
static const float3x3 RGBtoYIQ = float3x3(
    0.299,     0.587,     0.114,
    0.595716, -0.274453, -0.321263,
    0.211456, -0.522591,  0.311135
);

static const float3x3 YIQtoRGB = float3x3(
    1.0,  0.95629572,  0.62102442,
    1.0, -0.27212210, -0.64738060,
    1.0, -1.10698902,  1.70461500
);

static const float3 YIQ_lo = float3(0.0, -0.595716, -0.522591);
static const float3 YIQ_hi = float3(1.0,  0.595716,  0.522591);

uniform bool use_frame <
	ui_type = "boolean";
	ui_label = "Use Frame Image";
> = false;

uniform int FrameAspectMode <
    ui_type = "combo";
    ui_label = "Frame Aspect Ratio";
    ui_items = "Wide\0Pillarbox\0";
> = 1;

uniform float u_vig_shift <
    ui_type = "drag";
    ui_label = "Frame Vignette";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.14;

uniform float curvature <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.1;
    ui_label = "Curvature";
    ui_tooltip = "Recommended: 1.4 for Pillarbox, 1.2 for Widescreen";
> = 0.0;

uniform bool u_use_uv <
    ui_type = "checkbox";
    ui_label = "Use Original UV";
    ui_tooltip = "Uncheck for Curvature";
> = true;

uniform int ShadowMaskMode <
    ui_type = "combo";
    ui_label = "Shadow Mask Mode";
    ui_items = "Off\0Brightness Lines\0Color Mask\0";
> = 2;

// REPLACED: NTSC tint mode with Natural Vision YIQ controls
uniform float GAMMA_IN <
    ui_type = "drag";
    ui_label = "NaturalVision Gamma In";
    ui_min = 1.0;
    ui_max = 3.0;
    ui_step = 0.05;
> = 2.4;

uniform float GAMMA_OUT <
    ui_type = "drag";
    ui_label = "NaturalVision Gamma Out";
    ui_min = 1.0;
    ui_max = 3.0;
    ui_step = 0.05;
> = 2.2;

uniform float Y_ADJUST <
    ui_type = "drag";
    ui_label = "NaturalVision Luminance";
    ui_min = 0.5;
    ui_max = 1.5;
    ui_step = 0.01;
> = 1.0;

uniform float I_ADJUST <
    ui_type = "drag";
    ui_label = "NaturalVision Orange-Cyan";
    ui_min = 0.5;
    ui_max = 1.5;
    ui_step = 0.01;
> = 1.0;

uniform float Q_ADJUST <
    ui_type = "drag";
    ui_label = "NaturalVision Magenta-Green";
    ui_min = 0.5;
    ui_max = 1.5;
    ui_step = 0.01;
> = 1.0;

uniform float u_vignette_intensity <
    ui_type = "drag";
    ui_label = "Vignette";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 0.0;

uniform float chroma_shift <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 0.005;
    ui_step = 0.0001;
    ui_label = "Chromatic Aberration";
> = 0.0000;

uniform float u_ghosting <
    ui_type = "drag";
    ui_label = "Ghosting";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.0;

uniform bool wiggle_toggle <
	ui_type = "boolean";
	ui_label = "Interference";
> = false;

uniform bool scanroll <
	ui_type = "boolean";
	ui_label = "Rolling Scanlines";
> = false;

uniform float acc_modulate <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Accumulate Modulation";
> = 0.00;

texture2D tAccTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler sAccTex { Texture=tAccTex; };

float3 PrevColor(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv).rgb;
}

float4 PS_satpixie_Accum(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target
{
   float4 a = tex2D(sAccTex, uv.xy) * float4(acc_modulate,acc_modulate,acc_modulate,acc_modulate);
   float4 b = tex2D(ReShade::BackBuffer, uv.xy);
   return max( a, b * 0.96 );
}

texture GaussianBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex;};

uniform float blur_x <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.25;
	ui_label = "Horizontal Blur"; 
> = 0.0;

uniform float blur_y <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_step = 0.25;
	ui_label = "Vertical Blur";
> = 0.0;

float4 PS_satpixie_Blur(float4 pos : SV_Position, float2 uv_tx : TEXCOORD0) : SV_Target
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

uniform int FCount < source = "framecount"; >;
texture tFrame < source = "crt_satpixie/crtframe.png"; >
{
    Width = 1024;
    Height = 1024;
    MipLevels = 1;
};

sampler sFrame { Texture = tFrame; AddressU = BORDER; AddressV = BORDER; MinFilter = LINEAR; MagFilter = LINEAR;};

uniform float2 u_scale <
    ui_type = "input";
    ui_label = "Scale (X, Y)";
> = float2(1.000, 1.000);

uniform float2 u_offset <
    ui_type = "input";
    ui_label = "Offset (X, Y)";
> = float2(0.000, 0.000);

float3 tsample(sampler samp, float2 tc, float offs, float2 resolution)
{
    tc = tc * u_scale + u_offset;
    float3 s = pow(abs(tex2D(samp, float2(tc.x, 1.0 - tc.y)).rgb), float3(2.2, 2.2, 2.2));
    return s * float3(1.25, 1.25, 1.25);
}
		
float3 filmic( float3 LinearColor )
{
    float3 x = max( float3(0.0,0.0,0.0), LinearColor-float3(0.004,0.004,0.004));
    return (x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06);
}
		
float2 curve(float2 uv)
{
    if (curvature <= 0.0)
        return uv;

    float2 res = ReShade::ScreenSize.xy;
    float aspect = res.x / res.y;

    uv -= 0.5;
    uv.x *= aspect;

    uv *= curvature;
    uv.x *= 1.0 + pow((abs(uv.y) / 4.0), 2.0);
    float y_curv = lerp(1.0 + pow((abs(uv.x) / 3.0), 2.0), 1.0, step(abs(curvature - 1.0), 0.001));
    uv.y *= y_curv;
    uv /= curvature;

    uv.x /= aspect;
    uv += 0.5;
    uv = uv * 0.92 + 0.04;

    return uv;
}
		
float rand(float2 co){ return frac(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453); }
    
#define resolution ReShade::ScreenSize.xy
#define mod(x,y) (x-y*floor(x/y))

float4 PS_satpixie_Final(float4 pos: SV_Position, float2 uv_tx : TEXCOORD0) : SV_Target
{
    float time = mod(FCount, 849.0) * 36.0;
    float2 uv = uv_tx.xy;
    uv.y = 1.0 - uv_tx.y;
    
    float2 curved_uv = lerp( curve( uv ), uv, 0.4 );
    float scale = -0.101;
    float2 scuv = curved_uv*(1.0-scale)+scale/2.0+float2(0.003, -0.001);
    scuv = lerp(scuv, uv, u_use_uv ? 1.0 : 0.0);
    
    float3 col;
    float x = wiggle_toggle* sin(0.1*time+curved_uv.y*13.0)*sin(0.23*time+curved_uv.y*19.0)*sin(0.3+0.11*time+curved_uv.y*23.0)*0.0012;
    float o =sin(uv_tx.y*1.5)/resolution.x;
    x+=o*0.25;
    time = float(mod(FCount, 640) * 1); 
    
    if (chroma_shift <= 0.000001) {
        float3 ccol = tsample(GaussianBlurSampler, float2(x+scuv.x+0.0000, scuv.y+0.0000), resolution.y/800.0, resolution );
        col = ccol.xyz + 0.02;
    } else {
        col.r = tsample(GaussianBlurSampler,float2(x+scuv.x+ chroma_shift,scuv.y+ chroma_shift),resolution.y/800.0, resolution ).x+0.02;
        col.g = tsample(GaussianBlurSampler,float2(x+scuv.x+0.0000,scuv.y-0.0011),resolution.y/800.0, resolution ).y+0.02;
        col.b = tsample(GaussianBlurSampler,float2(x+scuv.x- chroma_shift,scuv.y+0.0000),resolution.y/800.0, resolution ).z+0.02;
    }
    
    float i = clamp(col.r*0.299 + col.g*0.587 + col.b*0.114, 0.0, 1.0 );
    i = pow( 1.0 - pow(i,2.0), 1.0 );
    i = (1.0-i) * 0.85 + 0.15; 
    
    /* Ghosting */
    float ghs = u_ghosting;
    float3 r = tsample(GaussianBlurSampler, float2(x-0.014*1.0, -0.027)*0.85+0.007*float2( 0.35*sin(1.0/7.0 + 15.0*curved_uv.y + 0.9*time), 
        0.35*sin( 2.0/7.0 + 10.0*curved_uv.y + 1.37*time) )+float2(scuv.x+0.001,scuv.y+0.001),
        5.5+1.3*sin( 3.0/9.0 + 31.0*curved_uv.x + 1.70*time),resolution).xyz*float3(0.5,0.25,0.25);
    float3 g = tsample(GaussianBlurSampler, float2(x-0.019*1.0, -0.020)*0.85+0.007*float2( 0.35*cos(1.0/9.0 + 15.0*curved_uv.y + 0.5*time), 
        0.35*sin( 2.0/9.0 + 10.0*curved_uv.y + 1.50*time) )+float2(scuv.x+0.000,scuv.y-0.002),
        5.4+1.3*sin( 3.0/3.0 + 71.0*curved_uv.x + 1.90*time),resolution).xyz*float3(0.25,0.5,0.25);
    float3 b = tsample(GaussianBlurSampler, float2(x-0.017*1.0, -0.003)*0.85+0.007*float2( 0.35*sin(2.0/3.0 + 15.0*curved_uv.y + 0.7*time), 
        0.35*cos( 2.0/3.0 + 10.0*curved_uv.y + 1.63*time) )+float2(scuv.x-0.002,scuv.y+0.000),
        5.3+1.3*sin( 3.0/7.0 + 91.0*curved_uv.x + 1.65*time),resolution).xyz*float3(0.25,0.25,0.5);
		
    col += float3(ghs*(1.0-0.299),ghs*(1.0-0.299),ghs*(1.0-0.299))*pow(clamp(float3(3.0,3.0,3.0)*r,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
    col += float3(ghs*(1.0-0.587),ghs*(1.0-0.587),ghs*(1.0-0.587))*pow(clamp(float3(3.0,3.0,3.0)*g,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
    col += float3(ghs*(1.0-0.114),ghs*(1.0-0.114),ghs*(1.0-0.114))*pow(clamp(float3(3.0,3.0,3.0)*b,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
    
    /* REPLACED: NTSC tint with Natural Vision YIQ color correction */
    col = pow(col, float3(GAMMA_IN, GAMMA_IN, GAMMA_IN));
    col = mul(RGBtoYIQ, col);
    col = float3(pow(col.x, Y_ADJUST), col.y * I_ADJUST, col.z * Q_ADJUST);
    col = clamp(col, YIQ_lo, YIQ_hi);
    col = mul(YIQtoRGB, col);
    col = pow(col, float3(1.0/GAMMA_OUT, 1.0/GAMMA_OUT, 1.0/GAMMA_OUT));
    
    col = clamp(col*1.3 + 0.75*col*col + 1.25*col*col*col*col*col, float3(0.0, 0.0, 0.0), float3(10.0, 10.0, 10.0));

    /* Vignette */
    float2 vignetteUV = curved_uv;
    float vignette = 1.0;

    if (FrameAspectMode == 1) {
        float aspect = ReShade::ScreenSize.x / ReShade::ScreenSize.y;
        float targetAspect = 4.0 / 2.99;
        float scale = aspect / targetAspect;
        float border = (1.0 - (1.0 / scale)) * 0.5;

        if (vignetteUV.x > border && vignetteUV.x < (1.0 - border)) {
            float vignetteX = (vignetteUV.x - border) / (1.0 - 2.0 * border);
            float vignetteY = vignetteUV.y;
            float vig = 16.0 * vignetteX * vignetteY * (1.0 - vignetteX) * (1.0 - vignetteY);
            vignette = 1.3 * pow(0.1 + vig, 0.5);
        }
    } else {
        float vig = 16.0 * vignetteUV.x * vignetteUV.y * (1.0 - vignetteUV.x) * (1.0 - vignetteUV.y);
        vignette = 1.3 * pow(0.1 + vig, 0.5);
    }

    col *= lerp(1.0, vignette, u_vignette_intensity);
    time *= scanroll;
		
    /* Scanlines */
    float scans = clamp(0.35 + 0.18 * sin(6.0 * time - scuv.y * resolution.y * 1.5), 0.0, 1.0);
    float s = pow(scans,0.9);
    col = col * float3(s,s,s);
    
    /* Shadow mask */
    float maskU = uv_tx.x;
    float warpedPx = maskU * resolution.x;
    float stripeWidth = 3.0;
    float idx       = warpedPx / stripeWidth;
    float center    = frac(idx) - 0.5;
    float aa        = fwidth(idx);
    float maskLine  = saturate(1.0 - abs(center) / aa);

    float3 brightnessMask = lerp(1.1, 0.8, maskLine);
    float stripePhase    = frac(idx);
    float3 phaseOffsets  = float3(0.0, 1.0/3.0, 2.0/3.0);
    float3 rawDistance   = abs(stripePhase.xxx - phaseOffsets);
    float3 circDistance  = min(rawDistance, 1.0 - rawDistance);
    float3 maskLineRGB   = saturate(1.0 - circDistance / aa);
    float3 colorMask     = lerp(0.75, 1.5, maskLineRGB);

    float3 finalMask = lerp(
        float3(1,1,1),
        lerp(brightnessMask, colorMask, step(2.0, ShadowMaskMode)),
        step(1.0, ShadowMaskMode)
    );
    col.rgb *= finalMask;

    col = filmic( col );
		
    /* Noise */
    float2 seed = curved_uv*resolution.xy;
    float lum = dot(col, float3(0.299, 0.587, 0.114));
    float noiseBase = 0.015;
    float scaledNoise = lerp(0.0, noiseBase, lum);
    float n = rand(seed + time) - 0.5;
    col += n * pow(scaledNoise, 1.0 + (1.0 - lum));
		
    /* Flicker */
    col *= (1.0-0.004*(sin(50.0*time+curved_uv.y*2.0)*0.5+0.5));

    uv = curved_uv;
	
    /* Frame */
    if (use_frame)
    {
        float2 uvFrame = uv_tx.xy;
        float2 uvVig   = uv;             
        if (FrameAspectMode == 1)
        {
            float aspect = ReShade::ScreenSize.x / ReShade::ScreenSize.y;       
            float target = 4.0/3.0;                                            
            float pad = (aspect - target) / (2.0 * aspect);                    

            uvFrame.x = saturate( (uvFrame.x - pad) / (1.0 - 2.0*pad) );
            uvVig.x   = saturate( (uvVig.x   - pad) / (1.0 - 2.0*pad) );
        }

        float fvig = clamp(
            1024.0 * (((uvVig.x - 0.494) * u_vig_shift + 0.5)) *
            (((uvVig.y - 0.5) * u_vig_shift + 0.5)) *
            (1.0 - ((uvVig.x - 0.5015) * u_vig_shift + 0.5)) *
            (1.0 - ((uvVig.y - 0.5040) * u_vig_shift + 0.5)), 0.6, 1.0 );

        float aspect = ReShade::ScreenSize.x / ReShade::ScreenSize.y;
        float targetAspect = 3.0 / 1.8;
        if (aspect > targetAspect) {
            float targetWidth = targetAspect / aspect;
            float xMin = 0.5 - targetWidth * 0.5;
            float xMax = 0.5 + targetWidth * 0.5;
            float inside = step(xMin, uvVig.x) * step(uvVig.x, xMax);
            fvig = lerp(1.0, fvig, inside);
        }
        col *= fvig;

        float4 f = tex2D(sFrame, uvFrame);
        col = lerp(col, f.xyz, f.w);
    }

    return float4(col, 1.0);
}

technique CRTSatpixie
{
	pass Accum
	{
		VertexShader=PostProcessVS;
		PixelShader=PS_satpixie_Accum;
	}
	
	pass SaveBuffer {
		VertexShader=PostProcessVS;
		PixelShader=PrevColor;
		RenderTarget = tAccTex;
	}
	
	pass Blur
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_satpixie_Blur;
		RenderTarget = GaussianBlurTex;
	}
	
	pass Final
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_satpixie_Final;
	}
}
