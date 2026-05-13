# `.luno` Package Format

A `.luno` package is a directory or zipped directory with this shape:

```text
AuroraField.luno/
  manifest.json
  Aurora.metal
  preview.png
  Assets/
```

For the alpha, packages are local and trusted only as shader packages. They cannot run CPU plugins, shell commands, scripts, or network code.

## Manifest

```json
{
  "id": "com.luno.samples.aurora",
  "name": "Aurora Field",
  "version": "1.0.0",
  "engineVersion": "1.0",
  "author": "Luno",
  "entryShader": "Aurora.metal",
  "assets": [],
  "parameters": [
    {
      "id": "speed",
      "name": "Speed",
      "type": "float",
      "default": 0.7,
      "min": 0.1,
      "max": 2.0
    }
  ],
  "audioBindings": ["rms", "bass", "mid", "treble"],
  "preview": "preview.png",
  "tags": ["shader", "audio"]
}
```

Supported parameter types:

- `float`: `default`, `min`, and `max`.
- `bool`: boolean `default`.
- `color`: hex string `default`, such as `#3366FF`.
- `enum`: string `default` and string `options`.

## Shader Contract

The entry shader must define:

```metal
vertex LunoVertexOut lunoVertex(uint vertexID [[vertex_id]]);
fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]);
```

The alpha uniform layout is:

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

`parameter0` packs the first four `float` and `bool` parameters in manifest order. Float values are passed directly. Bool values are passed as `1.0` for true and `0.0` for false. Extra numeric parameters are persisted by the preset system but are not included in the alpha uniform layout.

`colorParameter0` through `colorParameter3` pack the first four `color` parameters in manifest order. Colors are converted from `#RRGGBB` or `#RRGGBBAA` into normalized RGBA values. `#RRGGBB` colors use alpha `1.0`.

`enum` parameters are persisted by the preset system but are not packed into shader uniforms.
