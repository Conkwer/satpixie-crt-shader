# CRT-SatPixie for RetroArch (Slang)

Modernized fork of **Mattias Gustavsson's NewPixie CRT** with **user controls**, **straight screen**, and **Natural Vision** mode. Fixes common complaints while preserving the authentic look.

## Features
- **No curvature** - Straight, sharp screen geometry (unlike original); Completely removes curvature dependency.
- **Natural Vision Mode** - Neutral colors, proper gamma (eliminates green tint)
- **Controllable Blur** - Horizontal/Vertical sliders (default: 0.0 = sharp)
- **Toggleable Effects** - Ghosting, Chromatic Aberration, Vignette, Shadow Mask
- **Aspect-aware Vignette** - 4:3 pillarbox or widescreen modes (used for Vignette)
- **Overscan Crop** - Authentic CRT edge trimming
- **Multi-platform** - Vulkan/DX11/OpenGL/Metal via Slang. The version for RetroArch and ReShade

## What is Satpixie?

Satpixie is an enhanced version of Mattias Gustavsson's newpixie CRT shader, backporting some of the quality-of-life improvements from the community-modified ReShade version (CRT-NewPixie_Albatross_1.1.fx) to RetroArch's Slang format.

The original newpixie shader had several issues:
- Forced chromatic aberration that couldn't be disabled
- Excessive green color tint
- Always-on vignette effect
- Fixed ghosting intensity
- Screen curvature that caused black screens at 0.0 (bug)
- Blur adjustment do not works even in the forks

Satpixie fixes all of these with adjustable parameters while maintaining the lightweight efficiency that makes newpixie popular for PS1/PS2/3D games.

### Fixed Issues
- Curvature at 0.0 no longer causes black screen
- All effects can be disabled for a clean, sharp image
- Luminance-adaptive noise (less visible in dark areas)

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


For ReShade, You know what to do. 
Use CRT-Satpixie-Simplified.fx as default; for classic PC games you can try CRT-Satpixie-Darkstone.fx  

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
