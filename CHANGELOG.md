# Changelog

All notable changes to Luno will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses semantic versioning.

## [0.1.0] - 2026-05-26

### Added

- Initial open source alpha release.
- Menu bar macOS app for local live wallpaper playback.
- Per-display wallpaper windows backed by runtime Metal shader compilation.
- Local `.luno` package loading with bundled sample content.
- Now Playing widget with Apple Music and Spotify metadata support.
- Audio-reactive shader uniforms derived from system audio capture.
- DMG release packaging script and tag-based GitHub Release workflow.

### Known Limitations

- macOS 15 or later is required.
- First-run permissions may need to be granted manually in System Settings.
- GitHub release builds are ad-hoc signed unless Developer ID signing and
  notarization secrets are configured separately.
