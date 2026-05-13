# Wallpaper Variety and Color Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add several bundled shader wallpapers and make tint, brightness, and saturation preset controls affect rendering.

**Architecture:** Keep the existing package and preset model. Add a small engine-side parameter packing helper that converts manifest and preset values into numeric and color uniform packs, then have `MetalWallpaperRenderer` send those packs to shaders. Update bundled sample manifests and shaders to use the shared color-adjustment convention.

**Tech Stack:** SwiftPM, XCTest, AppKit/MetalKit runtime, Metal shader source files, `.luno` manifest JSON.

---

### Task 1: Shader Parameter Packing

**Files:**
- Create: `Sources/LunoEngineCore/ShaderParameterPack.swift`
- Create: `Tests/LunoEngineCoreTests/ShaderParameterPackTests.swift`
- Modify: `Sources/LunoEngineCore/WallpaperRuntime.swift`

- [ ] **Step 1: Write failing tests**

Add tests for numeric packing, color packing, and preset override behavior in `Tests/LunoEngineCoreTests/ShaderParameterPackTests.swift`.

- [ ] **Step 2: Verify red**

Run: `swift test --filter ShaderParameterPackTests`

Expected: fails because `ShaderParameterPack` does not exist.

- [ ] **Step 3: Implement minimal packing helper**

Create `ShaderParameterPack` with `numeric: SIMD4<Float>` and `colors: [SIMD4<Float>]`. Pack first four float/bool values into `numeric`, first four color values into `colors`, and parse `#RRGGBB` / `#RRGGBBAA`.

- [ ] **Step 4: Wire renderer uniforms**

Replace private renderer packing with `ShaderParameterPack.make(manifest:preset:)`. Add four color fields to `LunoShaderUniforms`.

- [ ] **Step 5: Verify green**

Run: `swift test --filter ShaderParameterPackTests`

Expected: pass.

### Task 2: Bundled Sample Wallpapers

**Files:**
- Modify: `Sources/LunoApp/Resources/SamplePackages/AuroraField.luno/manifest.json`
- Modify: `Sources/LunoApp/Resources/SamplePackages/AuroraField.luno/Aurora.metal`
- Create: `Sources/LunoApp/Resources/SamplePackages/LiquidChrome.luno/manifest.json`
- Create: `Sources/LunoApp/Resources/SamplePackages/LiquidChrome.luno/LiquidChrome.metal`
- Create: `Sources/LunoApp/Resources/SamplePackages/SolarDrift.luno/manifest.json`
- Create: `Sources/LunoApp/Resources/SamplePackages/SolarDrift.luno/SolarDrift.metal`
- Create: `Sources/LunoApp/Resources/SamplePackages/MidnightGrid.luno/manifest.json`
- Create: `Sources/LunoApp/Resources/SamplePackages/MidnightGrid.luno/MidnightGrid.metal`

- [ ] **Step 1: Add sample manifest validation test**

Add a test that loads bundled sample manifests from `Sources/LunoApp/Resources/SamplePackages` and validates them.

- [ ] **Step 2: Verify red**

Run: `swift test --filter WallpaperPackageManifestTests`

Expected: fails until new sample manifests exist or existing Aurora manifest contains the expected color controls.

- [ ] **Step 3: Update and add sample packages**

Add `Tint`, `Tint Strength`, `Brightness`, and `Saturation` controls to sample manifests. Add three visually distinct shader packages.

- [ ] **Step 4: Verify green**

Run: `swift test --filter WallpaperPackageManifestTests`

Expected: pass.

### Task 3: Package Format Documentation

**Files:**
- Modify: `docs/package-format.md`

- [ ] **Step 1: Update shader uniform docs**

Document `colorParameter0` through `colorParameter3` and clarify numeric/color packing rules.

- [ ] **Step 2: Verify documentation matches code**

Review `ShaderParameterPack.swift`, `WallpaperRuntime.swift`, and `docs/package-format.md` together.

### Task 4: Full Verification

**Files:**
- No planned code edits.

- [ ] **Step 1: Run full test suite**

Run: `swift test`

Expected: pass.

- [ ] **Step 2: Build app**

Run: `swift build`

Expected: pass.
