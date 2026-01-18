# Satpixie CRT Shader for RetroArch

A backport of the Albatross 1.1 improvements to the newpixie CRT shader for RetroArch, featuring full customization controls that were previously only available in the ReShade version.  
Also added the variant for ReShade since the original CRT-NewPixie_Albatross_1.1.fx had a bug with the blur sliders.

## What is Satpixie?

Satpixie is an enhanced version of Mattias Gustavsson's newpixie CRT shader, backporting all the quality-of-life improvements from the community-modified ReShade version (CRT-NewPixie_Albatross_1.1.fx) to RetroArch's Slang format.

The original newpixie shader had several issues:
- Forced chromatic aberration that couldn't be disabled
- Excessive green color tint
- Always-on vignette effect
- Fixed ghosting intensity
- Screen curvature that caused black screens at 0.0

Satpixie fixes all of these with adjustable parameters while maintaining the lightweight, single-pass efficiency that makes newpixie popular for PS1/PS2/3D games.

## Features

### New Adjustable Parameters
- ✅ **Chromatic Aberration Toggle** - Simple on/off instead of forced-on
- ✅ **Ghosting Control** (0.0-1.0) - Adjust or disable the trailing effect
- ✅ **Color Tint Modes** - Neutral/Warm/Cold/Original
- ✅ **Vignette Intensity** (0.0-2.0) - Reduce or disable edge darkening
- ✅ **Shadow Mask Modes** - Off/Brightness/Color options
- ✅ **Use Original UV Toggle** - Perfect flat screen with no distortion
- ✅ **Aspect-aware Curvature** - Proper widescreen handling when enabled

### Fixed Issues
- ✅ Curvature at 0.0 no longer causes black screen
- ✅ All effects can be disabled for a clean, sharp image
- ✅ Luminance-adaptive noise (less visible in dark areas)

## Installation

1. Download the `satpixie` folder
2. Copy it to your RetroArch shaders directory:
   - Windows: `RetroArch/shaders/shaders_slang/crt/shaders/satpixie/`
   - Linux: `~/.config/retroarch/shaders/shaders_slang/crt/shaders/satpixie/`
3. Copy `satpixie-crt.slangp` to `RetroArch/shaders/shaders_slang/crt/`

## Usage

### Loading the Shader
1. Open RetroArch
2. **Quick Menu** > **Shaders** > **Load Shader Preset**
3. Navigate to `shaders_slang/crt/satpixie-crt.slangp`
4. Select and apply

### Recommended Settings

**For Clean/Sharp Image (default):**
- Chromatic Aberration: **OFF (0.00)**
- Ghosting: **0.00**
- Vignette: **0.00**
- Curvature: **0.00**
- Use Original UV: **ON (1.00)**
- Color Tint: **Neutral (0.00)**
- Shadow Mask: **Brightness Lines (1.00)**

**For Original Newpixie Look:**
- Chromatic Aberration: **ON (1.00)**
- Ghosting: **0.15**
- Vignette: **1.00**
- Curvature: **2.00**
- Use Original UV: **OFF (0.00)**
- Color Tint: **Default/Greenish (3.00)**

### Performance Tip
For sharper image on low-resolution content, add to the `.slangp` (or use normal2x-hight filter):
```
scale_type_x0 = source
scale_x0 = 2.0
scale_type_y0 = source
scale_y0 = 2.0
```

## License

This shader is available under dual license (same as original newpixie):

**ALTERNATIVE A - MIT License**  
Copyright (c) 2016 Mattias Gustavsson

**ALTERNATIVE B - Public Domain (Unlicense)**  
This is free and unencumbered software released into the public domain.

See the shader source files for full license text.

## Credits

- **Original Shader**: Mattias Gustavsson (newpixie CRT)
- **Slang Adaptation**: hunterk (libretro)
- **ReShade Albatross Mod**: Community contributor (Reddit)
- **RetroArch Backport**: This repository

## Why "Satpixie"?

Saturn + newpixie = Satpixie, because this shader is particularly excellent for Sega Saturn and PS1 emulation, providing clean scanlines without the performance overhead of complex shaders like CRT-Royale.

## See Also

- Original newpixie shader: https://github.com/libretro/slang-shaders/tree/master/crt/shaders/newpixie
- RetroArch Shaders Documentation: https://docs.libretro.com/guides/shaders/
