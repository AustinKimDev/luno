import Foundation

func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

let manifestJSON = """
{
  "id": "com.luno.samples.aurora",
  "name": "Aurora Field",
  "version": "1.0.0",
  "engineVersion": "1.0",
  "author": "Luno",
  "entryShader": "Aurora.metal",
  "assets": ["Assets/noise.png"],
  "parameters": [
    {
      "id": "speed",
      "name": "Speed",
      "type": "float",
      "default": 0.8,
      "min": 0.0,
      "max": 2.0
    },
    {
      "id": "tint",
      "name": "Tint",
      "type": "color",
      "default": "#3366FF"
    },
    {
      "id": "reactive",
      "name": "Audio Reactive",
      "type": "bool",
      "default": true
    },
    {
      "id": "mode",
      "name": "Mode",
      "type": "enum",
      "default": "ribbons",
      "options": ["ribbons", "waves"]
    }
  ],
  "audioBindings": ["rms", "bass", "mid", "treble", "spectrum"],
  "preview": "preview.png",
  "tags": ["shader", "audio"]
}
"""
