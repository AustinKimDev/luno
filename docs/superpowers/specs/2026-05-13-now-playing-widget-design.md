# Now Playing Widget Design

Status: spec
Date: 2026-05-13
Target platform: macOS 15+
Owner: jidong

## Summary

A floating macOS window that displays the currently playing track (title, artist, album, composer, album artwork) sourced from Apple Music, Spotify, or the system-wide Now Playing service. The widget shares the audio reactivity signal already used by Luno's Metal wallpapers so the widget and wallpaper pulse to the same beat. Three built-in visual styles let the user pick the shape that fits their setup. Hover reveals play/pause/skip controls.

## Goals

- Show the current track's title, artist, album, composer, and album artwork in real time.
- Cover Apple Music, Spotify, and best-effort coverage of browsers and other audio apps through `MediaRemote.framework`.
- Use the existing `AudioFeatures` stream so the widget visually reacts to the same music data the shader wallpapers do.
- Stay quiet when nothing is playing (auto fade-out).
- Offer the user three visual styles, draggable placement, and a global on/off.

## Non-Goals

- Lyrics (live or static), queues, up-next, playlists.
- Global keyboard shortcuts.
- Like/bookmark actions.
- Browser-tab title scraping or per-site DOM scraping.
- App Store distribution compatibility (we use `MediaRemote.framework`, a private API).
- Marketplace metadata enrichment (Apple Music API, MusicBrainz, etc.).

## User-Facing Behavior

### Default state

- Off by default. User enables from the library window.
- First enable triggers a permissions sheet explaining that Apple Music and Spotify metadata require Automation permission. macOS displays its native Automation dialog the first time AppleScript fires.
- When enabled and music is playing, the widget fades in within 300ms.

### Styles

The user picks one of three built-in styles, stored in preferences.

| Style | Size (pt) | Album art | Composer line |
|---|---|---|---|
| A. Album-art dominant | 180 × 216 | 152 × 152 | Yes |
| B. Compact horizontal bar | 280 × 72 | 48 × 48 | Yes |
| C. Minimal | 240 × 52 | 28 × 28 | No (no room) |

All styles share the same glass background (`NSVisualEffectView` blur + dark translucent overlay), 14 pt corner radius, and `1px / rgba(255,255,255,0.08)` border.

### Hover controls

Default state shows track info. On `NSTrackingArea` enter, controls fade in over 150ms.

| Style | Controls layout |
|---|---|
| A | Overlay on album art, centered: `◀  ⏸  ▶`. Text below stays visible. |
| B | Right side: `◀  ⏸  ▶`. Text fades to 0.3 opacity while hovered. |
| C | Right side: `⏸` only. Skip omitted (not enough width). |

Controls map to provider-specific actions:
- Apple Music: AppleScript `play/pause/playpause/next track/previous track of application "Music"`.
- Spotify: `play/pause/playpause/next track/previous track of application "Spotify"`.
- MediaRemote-sourced tracks: not controllable. Buttons are visually disabled when the active provider is `MediaRemoteProvider`.

### Audio reactivity

The widget subscribes to the same `AudioFeatures` snapshot the shader pipeline consumes. Two effects:

- **Album-art pulse** — `scale 1.0 ↔ 1.03` driven by bass energy. Dampened spring (mass 1, stiffness 220, damping 22).
- **Border glow** — `box-shadow` color borrowed from the wallpaper's dominant color uniform, intensity driven by sub-bass.

Global strength clamped to 0.5. When hovered, both effects are scaled by an additional 0.3 so controls remain easy to read. A user toggle in preferences disables reactivity entirely.

### Auto hide

- On pause: 5-second delay, then fade out over 400ms.
- On resume / new track: fade in within 300ms.
- If the cursor is inside the widget bounds, the fade-out timer is paused.
- User preference: "Keep widget visible while paused" overrides this.

### Composer line

- If `composer` is `nil` or empty, the line is omitted and the widget's height reduces accordingly (the parent layout recomputes).
- Style C never shows a composer line.
- Realistically: rich for Apple Music classical/jazz catalog, frequently empty for Spotify and MediaRemote-sourced tracks.

### Placement

- Default position: bottom-right of the primary display, 24pt inset.
- Drag the widget anywhere by mouse. Position is saved per display (`CGDirectDisplayID` → `CGPoint`).
- If the saved display is gone on next launch, fall back to the main display, clamped within the visible frame.
- Window level: `.floating`. Joins all spaces.

## Architecture

Two layers, mirroring the existing engine-vs-app split.

### `LunoEngineCore/NowPlaying/`

```
NowPlayingTrack.swift
NowPlayingSource.swift            // enum { appleMusic, spotify, mediaRemote }
NowPlayingProvider.swift          // protocol
AppleMusicProvider.swift
SpotifyProvider.swift
MediaRemoteProvider.swift
MediaRemoteSymbols.swift          // dlopen wrapper, testable boundary
NowPlayingCoordinator.swift       // actor, fan-in + priority filter
NowPlayingControlCommand.swift    // enum { play, pause, playPause, next, previous }
NowPlayingControls.swift          // protocol — providers that support control implement it
```

### `LunoApp/NowPlayingWidget/`

```
NowPlayingPreferences.swift            // style, position per display, isEnabled, reactivity, keepVisibleWhilePaused
NowPlayingWindowController.swift       // borderless floating NSWindow, drag handling, fade
NowPlayingViewModel.swift              // ObservableObject; subscribes to Coordinator + AudioFeatures
NowPlayingWidgetView.swift             // SwiftUI root; switches on style
Styles/
  AlbumDominantStyle.swift             // style A
  CompactBarStyle.swift                // style B
  MinimalStyle.swift                   // style C
Components/
  ArtworkView.swift                    // pulse animation
  HoverControlsView.swift              // play/pause/skip
  GlassBackground.swift                // NSVisualEffectView wrapper
```

### Types

```swift
public struct NowPlayingTrack: Equatable, Sendable {
    public let title: String
    public let artist: String?
    public let album: String?
    public let composer: String?
    public let artwork: Artwork?
    public let source: NowPlayingSource
    public let isPlaying: Bool
    public let isAdvertisement: Bool
    public let updatedAt: Date

    public enum Artwork: Equatable, Sendable {
        case data(Data)              // raw bitmap (Apple Music, MediaRemote)
        case url(URL)                // remote URL (Spotify) — fetched + cached by ViewModel
    }
}

public protocol NowPlayingProvider: Actor {
    nonisolated var source: NowPlayingSource { get }
    func start() async
    func stop() async
    var tracks: AsyncStream<NowPlayingTrack?> { get }
}

public protocol NowPlayingControls {
    func send(_ command: NowPlayingControlCommand) async
}
```

### Coordinator priority

`NowPlayingCoordinator` runs each provider's stream concurrently and merges into one `AsyncStream<NowPlayingTrack?>` consumed by the ViewModel. Selection rule each tick:

1. If a higher-priority provider reports `isPlaying == true` within the last 2 seconds, pick it.
2. Otherwise, pick the most recently updated provider that reports `isPlaying == true`.
3. If no provider is playing, emit `nil`.

Priority order: Apple Music > Spotify > MediaRemote. Apple Music wins ties because its metadata is richest (composer, full artwork). The 2-second window in rule 1 is the grace period: when the user pauses Apple Music and immediately starts Spotify, the coordinator holds Apple Music's source briefly so the widget doesn't flicker between sources for ambient inter-track pauses.

### Data flow

```
SystemAudioCaptureService ─────────────────▶ AudioFeatures stream ─┐
                                                                    │
AppleMusicProvider  (NSAppleScript poll, 1s) ─┐                    │
SpotifyProvider     (NSAppleScript poll, 1s) ─┤                    ▼
MediaRemoteProvider (MR notifications)        ├▶ NowPlayingCoordinator (actor)
                                              │       │
                                              │       └─▶ merged AsyncStream<NowPlayingTrack?>
                                              │                  │
                                              │                  ▼
                                              │           NowPlayingViewModel
                                              │           ├─ artwork NSCache (memory only)
                                              │           ├─ debounce 200ms
                                              │           └─ @Published track / @Published audio
                                              │                  │
                                              ▼                  ▼
                                        Coordinator stop    NowPlayingWidgetView (SwiftUI)
                                        when widget off            │
                                                                   ▼
                                                           NowPlayingWindowController
```

### Polling and notifications

| Provider | Mechanism | Cadence |
|---|---|---|
| `AppleMusicProvider` | `NSAppleScript` IPC, batched query for name/artist/album/composer/artwork/playerState | 1 second |
| `SpotifyProvider` | `NSAppleScript` IPC, batched query for name/artist/album/artwork URL/playerState/spotify URL | 1 second |
| `MediaRemoteProvider` | `MRMediaRemoteRegisterForNowPlayingNotifications` → `kMRMediaRemoteNowPlayingInfoDidChangeNotification` | Event-driven, plus 5-second fallback poll via `MRMediaRemoteGetNowPlayingInfo` |

AppleScript is invoked via `NSAppleScript` compiled once and reused per provider; the compiled scripts pull all fields in one IPC round-trip. CPU cost is expected to be negligible (< 0.5%) — to be verified during implementation.

### MediaRemote dynamic loading

`MediaRemote.framework` is loaded with `dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)` and three symbols resolved with `dlsym`:

- `MRMediaRemoteGetNowPlayingInfo`
- `MRMediaRemoteRegisterForNowPlayingNotifications`
- `MRMediaRemoteUnregisterForNowPlayingNotifications`

Resolved through a `MediaRemoteSymbols` struct so tests can inject a mock. Any `dlsym` failure leaves the symbol nil and the provider permanently silent — the coordinator handles `nil` from a provider exactly like "not playing."

### Coordinator lifecycle

The coordinator is started and stopped from `NowPlayingPreferences.isEnabled`. When off, all providers' streams are torn down and AppleScript timers cancelled. Resource cost when disabled: zero.

On `NSWorkspace.willSleepNotification` the coordinator pauses (cancels its task tree). On `NSWorkspace.didWakeNotification` it resumes and forces a one-shot poll on every provider so the displayed track is immediate after wake.

## Edge Cases

| Case | Handling |
|---|---|
| Music.app or Spotify.app not installed | `NSAppleScript` returns a "doesn't understand" error → provider stays silent, logged once |
| Apple Music with no library yet | AppleScript error → provider returns `nil` until library exists |
| Pause | Widget fades out after 5s grace |
| Spotify advertisement (track id prefix `spotify:ad:`) | Track flagged `isAdvertisement = true`; widget shows "Advertisement" placeholder, controls disabled |
| Artwork download fails (Spotify URL 4xx/5xx) | Fallback to gradient seeded from `hash(albumName + artist)` |
| Fast skipping | 200ms debounce on coordinator output; prior artwork kept while new one loads |
| MediaRemote API removed/changed by macOS update | `dlsym` returns nil → provider permanently `nil`. Apple Music and Spotify still work |
| Widget off-screen (display disconnected) | At launch, clamp saved position to a visible display; if originally on a now-missing display, move to main |
| Multi-display | `position` stored as `[displayID: CGPoint]`. If preferred display disappears, fall back to main |
| System sleep / wake | Coordinator pauses on `willSleep`, resumes on `didWake` with one-shot poll |
| App relaunch | Preferences (style, per-display position, isEnabled, reactivity, keepVisibleWhilePaused) persisted via existing `PresetStore` pattern in `LocalPackageLibrary` location |

## Permissions

`Info.plist` additions:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>Luno reads the currently playing track from Music and Spotify so the wallpaper widget can show what you're listening to.</string>
```

Flow:

1. User enables the widget in the library window.
2. A sheet explains why permission is needed and offers "Open System Settings" + "Later".
3. On the first AppleScript invocation, macOS shows its native Automation dialog. User grants or denies.
4. If denied for one app (e.g. Spotify) but granted for another (Apple Music), the coordinator runs only the permitted providers.
5. If denied for both, the widget shows a `Permission needed →` line that, when clicked, opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Automation`.

`MediaRemoteProvider` requires no extra permission. It either works or returns nil.

## Library Window UI

Adds a new section "Now Playing widget" under the existing controls:

- Toggle: Enable widget.
- Segmented control: Style A / B / C with thumbnail previews.
- Toggle: React to music.
- Toggle: Keep visible while paused.
- Button: Reset position.
- Status line: shows which providers are currently active (e.g., "Apple Music ✓, Spotify (permission needed)").

## Testing Strategy

| Level | Subject | Approach |
|---|---|---|
| Unit | `NowPlayingTrack` | Equatable behavior, Codable round-trip for preference snapshots |
| Unit | `NowPlayingCoordinator` priority logic | Inject three mock `NowPlayingProvider` actors, drive scenarios (Apple Music only, Spotify only, both playing, fast switch, ad), assert merged stream |
| Unit | AppleScript response parsing | Fixture strings + parser; covers missing composer, missing artwork, ad track id |
| Unit | `MediaRemoteSymbols` wrapper | Inject mock symbol table; verify `dlsym` failure path leaves provider silent |
| Integration | `AppleMusicProvider` end-to-end | `XCTSkipIf` when Music.app isn't installed or no library; otherwise launch, query, assert non-nil track shape |
| Integration | `SpotifyProvider` end-to-end | Same pattern |
| Manual QA | UI snapshot of all 3 styles × 3 states (default+pulse, hover, no-composer) | Visual check |
| Manual QA | Pause/resume fade timings, drag, multi-display | Visual check |

Tests live in `LunoEngineCoreTests/NowPlaying/`. A new `LunoAppTests` target may be added later if SwiftUI snapshot testing is adopted; not in scope here.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Apple further restricts `MediaRemote.framework` in a future macOS update | High over time | The whole MR path is a clean fallback that can return nil; Apple Music + Spotify keep working without it |
| AppleScript permission UX is confusing for first-time users | Medium | In-app sheet pre-explains the system dialog; status line shows current state |
| Polling at 1s for two apps measurably hurts battery | Low | Verify with `powermetrics`; if needed, drop to 2s when on battery |
| Album-art download for Spotify causes a noticeable flicker on slow networks | Low | Keep last artwork visible until new one is fully loaded |
| Audio reactivity feels distracting | Medium | Default strength 0.5, user toggle to disable |

## Open Questions

None — all decisions resolved in brainstorming. Implementation can begin.
