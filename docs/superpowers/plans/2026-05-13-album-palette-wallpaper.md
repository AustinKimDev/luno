# Album Palette Wallpaper Plan

1. Add a pure core palette extractor and tests.
   - Verify: deterministic sample-color tests.
2. Encode enum parameters into shader numeric slots.
   - Verify: `ShaderParameterPackTests`.
3. Extend runtime uniforms with album palette colors and smooth interpolation.
   - Verify: compile and existing shader tests.
4. Decode artwork data in the app and push palette updates from Now Playing to the runtime.
   - Verify: build succeeds and no unrelated Now Playing behavior changes.
5. Add the bundled Album Palette package and shader with three modes.
   - Verify: bundled manifest and shader compilation tests.
