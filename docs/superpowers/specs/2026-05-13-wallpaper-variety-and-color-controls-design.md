# Wallpaper Variety and Color Controls Design

## Goal

Add more bundled wallpaper variety and let users adjust the color feel of a selected wallpaper through presets. A user should be able to choose a wallpaper, tune tint and brightness, apply it, and save those values as a preset.

## Scope

- Add several bundled `.luno` sample packages with distinct visual styles.
- Extend shader parameter packing so color parameters can affect rendering.
- Add common color adjustment parameters to sample package manifests.
- Keep the current library window control model: sliders for floats, color wells for colors, checkboxes for booleans, and popups for enums.
- Update package format documentation and tests for the new shader uniform contract.

Out of scope:

- A marketplace or remote package source.
- A new visual editor.
- Image-based wallpaper assets.
- A full UI redesign of the library window.

## User Experience

The library window continues to show a wallpaper picker, display picker, preset name field, parameter controls, and action buttons. Bundled wallpapers include more than one visual category so the picker no longer feels like a single demo.

Each bundled sample exposes common controls where they make sense:

- `Tint`: a color well for choosing the target color.
- `Tint Strength`: a slider controlling how strongly the tint affects final colors.
- `Brightness`: a slider for darkening or brightening the final output.
- `Saturation`: a slider for muted or more vivid output.

The existing `Save Preset` action stores these values with the rest of the preset values.

## Architecture

`WallpaperPackageManifest` already supports `color` parameters and `PresetStore` already persists them, so the main missing piece is runtime delivery to Metal shaders.

`MetalWallpaperRenderer` should continue packing the first four numeric values into `parameter0`, and add a separate color uniform pack. The first four manifest parameters whose resolved value is `.color` are converted from hex to normalized RGB and packed into four `float4` slots. Alpha should be `1`.

The shader uniform contract becomes:

```metal
struct LunoUniforms {
    float time;
    float deltaTime;
    float2 resolution;
    float displayScale;
    float audioRMS;
    float audioBass;
    float audioMid;
    float audioTreble;
    float4 parameter0;
    float4 colorParameter0;
    float4 colorParameter1;
    float4 colorParameter2;
    float4 colorParameter3;
};
```

This keeps existing numeric behavior stable while making color parameters usable by new shader packages.

## Sample Wallpapers

Keep `Aurora Field` and update it to use color adjustment controls. Add three new bundled packages:

- `Liquid Chrome`: reflective liquid bands with slow motion and audio lift.
- `Solar Drift`: warm radial plasma and drifting light arcs.
- `Midnight Grid`: dark grid waves with crisp lines and audio pulse.

Each package is a self-contained `.luno` directory under `Sources/LunoApp/Resources/SamplePackages`.

## Shader Convention

Sample shaders should include a small local helper that applies the common color controls:

1. Convert final color to luminance.
2. Mix grayscale and original color by `saturation`.
3. Mix the result toward `tint` by `tintStrength`.
4. Multiply by `brightness`.
5. Clamp to a displayable range.

The common parameter order for bundled samples should be:

1. Wallpaper-specific numeric controls such as `speed`, `scale`, or `intensity`.
2. `tintStrength`
3. `brightness`
4. `saturation`
5. `tint`
6. Wallpaper-specific booleans if any

Because numeric uniforms only expose the first four float or bool parameters, bundled samples should keep the three color adjustment floats within the first four numeric slots.

## Tests

Add focused tests for:

- Hex color parsing into normalized shader color values.
- Numeric and color parameter packing order.
- Preset persistence for mixed float, bool, and color values if existing coverage does not already cover the new combination.
- Manifest decoding for the new bundled sample manifests where practical.

Run `swift test` as the primary verification command. Build the app if the local Xcode/SwiftPM environment supports it.

## Risks

Changing the uniform layout requires all bundled sample shaders to use the new layout. Existing third-party packages using the alpha shader contract may need to add the new color fields to compile against the updated engine. This is acceptable for the current local prototype, but the package format docs must state the new layout clearly.
