# Now Playing Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a floating macOS window that shows the currently playing track (title, artist, album, composer, artwork) from Apple Music, Spotify, and MediaRemote, sharing Luno's existing audio reactivity stream so the widget pulses in sync with the wallpaper.

**Architecture:** Three independent providers (Apple Music via NSAppleScript, Spotify via NSAppleScript, MediaRemote via private framework loaded with dlopen) feed a `NowPlayingCoordinator` actor that applies priority rules and emits a merged `AsyncStream<NowPlayingTrack?>`. A `NowPlayingPipeline` adds 200 ms debounce + artwork caching. A SwiftUI widget (3 styles: album-dominant, compact bar, minimal) lives in a borderless `.floating` NSWindow, subscribes to the pipeline plus the existing `AudioFeatures`, and renders pulse / glow reactions.

**Tech Stack:** Swift 6, SwiftPM, macOS 15+, SwiftUI, AppKit (`NSWindow`, `NSVisualEffectView`, `NSTrackingArea`), `NSAppleScript`, `Observation` framework, `MediaRemote.framework` (private, dlopen'd), `XCTest`.

**Reference spec:** `docs/superpowers/specs/2026-05-13-now-playing-widget-design.md`

**Test convention:** XCTest. Run `swift test` from the repo root. Filter with `swift test --filter LunoEngineCoreTests.<ClassName>/<methodName>`.

**Commit convention:** Each task ends with one commit. Use `feat(now-playing):`, `test(now-playing):`, or `chore(now-playing):` prefixes.

---

## Phase 1 — Core types

### Task 1: NowPlayingSource enum

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingSource.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingSourceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingSourceTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingSourceTests: XCTestCase {
    func testRawValuesAreStableForPersistence() {
        XCTAssertEqual(NowPlayingSource.appleMusic.rawValue, "appleMusic")
        XCTAssertEqual(NowPlayingSource.spotify.rawValue, "spotify")
        XCTAssertEqual(NowPlayingSource.mediaRemote.rawValue, "mediaRemote")
    }

    func testCaseIterableOrderMatchesPriority() {
        XCTAssertEqual(NowPlayingSource.allCases, [.appleMusic, .spotify, .mediaRemote])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingSourceTests`
Expected: build fails with "cannot find 'NowPlayingSource' in scope"

- [ ] **Step 3: Implement the enum**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingSource.swift`:

```swift
import Foundation

public enum NowPlayingSource: String, Codable, Sendable, CaseIterable {
    case appleMusic
    case spotify
    case mediaRemote
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingSourceTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingSource.swift \
        Tests/LunoEngineCoreTests/NowPlaying/NowPlayingSourceTests.swift
git commit -m "feat(now-playing): add NowPlayingSource enum"
```

---

### Task 2: NowPlayingTrack struct + Artwork enum

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingTrack.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingTrackTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingTrackTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingTrackTests: XCTestCase {
    func testTracksAreEqualWhenAllFieldsMatch() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let a = NowPlayingTrack(
            title: "Clair de Lune",
            artist: "Lang Lang",
            album: "Suite bergamasque",
            composer: "Claude Debussy",
            artwork: .url(URL(string: "https://example.com/a.jpg")!),
            source: .appleMusic,
            isPlaying: true,
            isAdvertisement: false,
            updatedAt: timestamp
        )
        let b = NowPlayingTrack(
            title: "Clair de Lune",
            artist: "Lang Lang",
            album: "Suite bergamasque",
            composer: "Claude Debussy",
            artwork: .url(URL(string: "https://example.com/a.jpg")!),
            source: .appleMusic,
            isPlaying: true,
            isAdvertisement: false,
            updatedAt: timestamp
        )
        XCTAssertEqual(a, b)
    }

    func testArtworkDataRoundTrips() {
        let payload = Data([0x01, 0x02, 0x03])
        let artwork = NowPlayingTrack.Artwork.data(payload)
        XCTAssertEqual(artwork, .data(payload))
        XCTAssertNotEqual(artwork, .data(Data([0x01, 0x02])))
    }

    func testCodableRoundTripPreservesAllFields() throws {
        let track = NowPlayingTrack(
            title: "Aja",
            artist: "Steely Dan",
            album: "Aja",
            composer: nil,
            artwork: .data(Data([0xDE, 0xAD])),
            source: .spotify,
            isPlaying: true,
            isAdvertisement: false,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let encoded = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(NowPlayingTrack.self, from: encoded)
        XCTAssertEqual(decoded, track)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingTrackTests`
Expected: build fails with "cannot find 'NowPlayingTrack' in scope"

- [ ] **Step 3: Implement the type**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingTrack.swift`:

```swift
import Foundation

public struct NowPlayingTrack: Codable, Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var composer: String?
    public var artwork: Artwork?
    public var source: NowPlayingSource
    public var isPlaying: Bool
    public var isAdvertisement: Bool
    public var updatedAt: Date

    public init(
        title: String,
        artist: String?,
        album: String?,
        composer: String?,
        artwork: Artwork?,
        source: NowPlayingSource,
        isPlaying: Bool,
        isAdvertisement: Bool,
        updatedAt: Date
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.composer = composer
        self.artwork = artwork
        self.source = source
        self.isPlaying = isPlaying
        self.isAdvertisement = isAdvertisement
        self.updatedAt = updatedAt
    }

    public enum Artwork: Codable, Equatable, Sendable {
        case data(Data)
        case url(URL)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingTrackTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingTrack.swift \
        Tests/LunoEngineCoreTests/NowPlaying/NowPlayingTrackTests.swift
git commit -m "feat(now-playing): add NowPlayingTrack value type"
```

---

### Task 3: NowPlayingControlCommand enum

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingControlCommand.swift`

- [ ] **Step 1: Implement (no behavior — just an enum, no test needed beyond compile)**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingControlCommand.swift`:

```swift
import Foundation

public enum NowPlayingControlCommand: String, Sendable {
    case play
    case pause
    case playPause
    case nextTrack
    case previousTrack
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingControlCommand.swift
git commit -m "feat(now-playing): add NowPlayingControlCommand"
```

---

### Task 4: NowPlayingProvider and NowPlayingControls protocols

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingProvider.swift`
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingControls.swift`

- [ ] **Step 1: Write protocols**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingProvider.swift`:

```swift
import Foundation

public protocol NowPlayingProvider: Sendable {
    var source: NowPlayingSource { get }
    var tracks: AsyncStream<NowPlayingTrack?> { get }
    func start() async
    func stop() async
}
```

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingControls.swift`:

```swift
import Foundation

public protocol NowPlayingControls: Sendable {
    func send(_ command: NowPlayingControlCommand) async throws
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingProvider.swift \
        Sources/LunoEngineCore/NowPlaying/NowPlayingControls.swift
git commit -m "feat(now-playing): add provider + controls protocols"
```

---

### Task 5: NowPlayingClock + FakeClock test helper

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingClock.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/FakeNowPlayingClock.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingClockTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingClockTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingClockTests: XCTestCase {
    func testFakeClockReturnsConfiguredTime() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let clock = FakeNowPlayingClock(start: start)
        XCTAssertEqual(clock.now(), start)
    }

    func testFakeClockAdvancesByInterval() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let clock = FakeNowPlayingClock(start: start)
        clock.advance(by: 5)
        XCTAssertEqual(clock.now(), start.addingTimeInterval(5))
    }
}
```

Create `Tests/LunoEngineCoreTests/NowPlaying/FakeNowPlayingClock.swift`:

```swift
import Foundation
@testable import LunoEngineCore

final class FakeNowPlayingClock: NowPlayingClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self._now = start
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _now.addTimeInterval(interval)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingClockTests`
Expected: build fails with "cannot find 'NowPlayingClock' in scope"

- [ ] **Step 3: Implement the clock protocol**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingClock.swift`:

```swift
import Foundation

public protocol NowPlayingClock: Sendable {
    func now() -> Date
}

public struct SystemNowPlayingClock: NowPlayingClock {
    public init() {}
    public func now() -> Date { Date() }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingClockTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingClock.swift \
        Tests/LunoEngineCoreTests/NowPlaying/FakeNowPlayingClock.swift \
        Tests/LunoEngineCoreTests/NowPlaying/NowPlayingClockTests.swift
git commit -m "feat(now-playing): add NowPlayingClock abstraction"
```

---

## Phase 2 — Coordinator

### Task 6: NowPlayingCoordinator priority logic

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingCoordinator.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/MockNowPlayingProvider.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingCoordinatorTests.swift`

- [ ] **Step 1: Write the mock provider helper**

Create `Tests/LunoEngineCoreTests/NowPlaying/MockNowPlayingProvider.swift`:

```swift
import Foundation
@testable import LunoEngineCore

final class MockNowPlayingProvider: NowPlayingProvider, @unchecked Sendable {
    let source: NowPlayingSource
    let tracks: AsyncStream<NowPlayingTrack?>
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation

    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(source: NowPlayingSource) {
        self.source = source
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    func start() async { startCount += 1 }
    func stop() async { stopCount += 1 }

    func emit(_ track: NowPlayingTrack?) {
        continuation.yield(track)
    }

    func finish() {
        continuation.finish()
    }
}

extension NowPlayingTrack {
    static func fixture(
        title: String = "Title",
        source: NowPlayingSource,
        isPlaying: Bool = true,
        updatedAt: Date
    ) -> NowPlayingTrack {
        NowPlayingTrack(
            title: title,
            artist: "Artist",
            album: "Album",
            composer: nil,
            artwork: nil,
            source: source,
            isPlaying: isPlaying,
            isAdvertisement: false,
            updatedAt: updatedAt
        )
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingCoordinatorTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingCoordinatorTests: XCTestCase {
    func testEmitsTrackFromOnlyPlayingProvider() async throws {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let spotify = MockNowPlayingProvider(source: .spotify)
        let coordinator = NowPlayingCoordinator(providers: [spotify], clock: clock)

        var iterator = coordinator.tracks.makeAsyncIterator()
        await coordinator.start()

        let track = NowPlayingTrack.fixture(source: .spotify, updatedAt: clock.now())
        spotify.emit(track)

        let received = await iterator.next() ?? nil
        XCTAssertEqual(received, track)

        await coordinator.stop()
        XCTAssertEqual(spotify.stopCount, 1)
    }

    func testAppleMusicWinsOverSpotifyWhenBothPlaying() async throws {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let am = MockNowPlayingProvider(source: .appleMusic)
        let sp = MockNowPlayingProvider(source: .spotify)
        let coordinator = NowPlayingCoordinator(providers: [am, sp], clock: clock)

        var iterator = coordinator.tracks.makeAsyncIterator()
        await coordinator.start()

        let spotifyTrack = NowPlayingTrack.fixture(title: "Spotify Song", source: .spotify, updatedAt: clock.now())
        sp.emit(spotifyTrack)
        let first = await iterator.next() ?? nil
        XCTAssertEqual(first?.title, "Spotify Song")

        let amTrack = NowPlayingTrack.fixture(title: "Apple Music Song", source: .appleMusic, updatedAt: clock.now())
        am.emit(amTrack)
        let second = await iterator.next() ?? nil
        XCTAssertEqual(second?.title, "Apple Music Song")

        await coordinator.stop()
    }

    func testEmitsNilWhenNoProviderIsPlaying() async throws {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let am = MockNowPlayingProvider(source: .appleMusic)
        let coordinator = NowPlayingCoordinator(providers: [am], clock: clock)

        var iterator = coordinator.tracks.makeAsyncIterator()
        await coordinator.start()

        let playing = NowPlayingTrack.fixture(source: .appleMusic, isPlaying: true, updatedAt: clock.now())
        am.emit(playing)
        _ = await iterator.next()

        let paused = NowPlayingTrack.fixture(source: .appleMusic, isPlaying: false, updatedAt: clock.now())
        am.emit(paused)
        let after = await iterator.next() ?? nil
        XCTAssertNil(after)

        await coordinator.stop()
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingCoordinatorTests`
Expected: build fails with "cannot find 'NowPlayingCoordinator' in scope"

- [ ] **Step 4: Implement the coordinator**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingCoordinator.swift`:

```swift
import Foundation

public actor NowPlayingCoordinator {
    public nonisolated let tracks: AsyncStream<NowPlayingTrack?>

    private nonisolated let outputContinuation: AsyncStream<NowPlayingTrack?>.Continuation
    private let providers: [any NowPlayingProvider]
    private let clock: NowPlayingClock
    private let priorityOrder: [NowPlayingSource]
    private let priorityHoldSeconds: TimeInterval

    private var lastByProvider: [NowPlayingSource: NowPlayingTrack] = [:]
    private var lastEmitted: NowPlayingTrack?
    private var pumpTask: Task<Void, Never>?

    public init(
        providers: [any NowPlayingProvider],
        clock: NowPlayingClock = SystemNowPlayingClock(),
        priorityOrder: [NowPlayingSource] = [.appleMusic, .spotify, .mediaRemote],
        priorityHoldSeconds: TimeInterval = 2.0
    ) {
        self.providers = providers
        self.clock = clock
        self.priorityOrder = priorityOrder
        self.priorityHoldSeconds = priorityHoldSeconds
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.outputContinuation = captured
    }

    public func start() async {
        for provider in providers { await provider.start() }

        pumpTask = Task { [weak self] in
            guard let self else { return }
            await self.pumpAll()
        }
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        for provider in providers { await provider.stop() }
        outputContinuation.finish()
    }

    private func pumpAll() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                let source = provider.source
                let stream = provider.tracks
                group.addTask { [weak self] in
                    for await track in stream {
                        await self?.handle(source: source, track: track)
                    }
                }
            }
        }
    }

    private func handle(source: NowPlayingSource, track: NowPlayingTrack?) {
        if let track {
            lastByProvider[source] = track
        } else {
            lastByProvider.removeValue(forKey: source)
        }
        let resolved = resolve()
        if resolved != lastEmitted {
            lastEmitted = resolved
            outputContinuation.yield(resolved)
        }
    }

    private func resolve() -> NowPlayingTrack? {
        let now = clock.now()

        for source in priorityOrder {
            if let track = lastByProvider[source],
               track.isPlaying,
               now.timeIntervalSince(track.updatedAt) <= priorityHoldSeconds {
                return track
            }
        }

        let playing = priorityOrder.compactMap { lastByProvider[$0] }.filter { $0.isPlaying }
        return playing.max(by: { $0.updatedAt < $1.updatedAt })
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingCoordinatorTests`
Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingCoordinator.swift \
        Tests/LunoEngineCoreTests/NowPlaying/MockNowPlayingProvider.swift \
        Tests/LunoEngineCoreTests/NowPlaying/NowPlayingCoordinatorTests.swift
git commit -m "feat(now-playing): add NowPlayingCoordinator with priority routing"
```

---

### Task 7: Coordinator priority-hold (Apple Music keeps source briefly after pause)

**Files:**
- Modify: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingCoordinatorTests.swift`

- [ ] **Step 1: Add the failing test**

Append to `NowPlayingCoordinatorTests.swift` inside the class:

```swift
func testHigherPriorityProviderKeepsHoldWithinWindow() async throws {
    let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
    let am = MockNowPlayingProvider(source: .appleMusic)
    let sp = MockNowPlayingProvider(source: .spotify)
    let coordinator = NowPlayingCoordinator(
        providers: [am, sp],
        clock: clock,
        priorityHoldSeconds: 2.0
    )

    var iterator = coordinator.tracks.makeAsyncIterator()
    await coordinator.start()

    let amTrack = NowPlayingTrack.fixture(title: "AM", source: .appleMusic, updatedAt: clock.now())
    am.emit(amTrack)
    _ = await iterator.next()

    // 1s later — within hold window. Spotify starts.
    clock.advance(by: 1)
    let spTrack = NowPlayingTrack.fixture(title: "SP", source: .spotify, updatedAt: clock.now())
    sp.emit(spTrack)
    // No new emission expected because Apple Music is still inside its hold window.

    clock.advance(by: 1.5) // total 2.5s since AM emission — past the hold window
    let spTrack2 = NowPlayingTrack.fixture(title: "SP-late", source: .spotify, updatedAt: clock.now())
    sp.emit(spTrack2)
    let received = await iterator.next() ?? nil
    XCTAssertEqual(received?.title, "SP-late")

    await coordinator.stop()
}
```

- [ ] **Step 2: Run the test to verify it fails (or already passes)**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingCoordinatorTests/testHigherPriorityProviderKeepsHoldWithinWindow`
Expected: passes if Task 6's implementation already honors the hold; if it fails, recheck `resolve()`.

If it fails, the bug is that step 1 of the loop in `resolve()` is missing the time check. Inspect and fix.

- [ ] **Step 3: Commit**

```bash
git add Tests/LunoEngineCoreTests/NowPlaying/NowPlayingCoordinatorTests.swift
git commit -m "test(now-playing): cover priority-hold window in coordinator"
```

---

## Phase 3 — Apple Music provider

### Task 8: AppleScript abstraction + RawTrackInfo

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/RawTrackInfo.swift`
- Create: `Sources/LunoEngineCore/NowPlaying/AppleScriptRunner.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/RawTrackInfoTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/RawTrackInfoTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class RawTrackInfoTests: XCTestCase {
    func testEquatable() {
        let a = RawTrackInfo(
            title: "T",
            artist: "A",
            album: "L",
            composer: "C",
            artworkData: Data([0x01]),
            artworkURL: nil,
            trackID: "1",
            isPlaying: true
        )
        let b = a
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.RawTrackInfoTests`
Expected: build fails with "cannot find 'RawTrackInfo' in scope"

- [ ] **Step 3: Implement RawTrackInfo + the runner protocol**

Create `Sources/LunoEngineCore/NowPlaying/RawTrackInfo.swift`:

```swift
import Foundation

public struct RawTrackInfo: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var composer: String?
    public var artworkData: Data?
    public var artworkURL: URL?
    public var trackID: String?
    public var isPlaying: Bool

    public init(
        title: String,
        artist: String?,
        album: String?,
        composer: String?,
        artworkData: Data?,
        artworkURL: URL?,
        trackID: String?,
        isPlaying: Bool
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.composer = composer
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.trackID = trackID
        self.isPlaying = isPlaying
    }
}
```

Create `Sources/LunoEngineCore/NowPlaying/AppleScriptRunner.swift`:

```swift
import Foundation

public enum AppleScriptRunnerError: Error, Equatable {
    case appNotInstalled
    case permissionDenied
    case scriptError(String)
}

public protocol AppleScriptRunner: Sendable {
    /// Returns nil when the target app reports "not playing" cleanly.
    /// Throws `appNotInstalled` if the app isn't present, `permissionDenied` for AE -1743,
    /// `scriptError` for any other AppleScript failure.
    func fetchTrack() async throws -> RawTrackInfo?

    func sendControl(_ command: NowPlayingControlCommand) async throws
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter LunoEngineCoreTests.RawTrackInfoTests`
Expected: 1 test passes; whole package builds.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/RawTrackInfo.swift \
        Sources/LunoEngineCore/NowPlaying/AppleScriptRunner.swift \
        Tests/LunoEngineCoreTests/NowPlaying/RawTrackInfoTests.swift
git commit -m "feat(now-playing): add RawTrackInfo + AppleScriptRunner protocol"
```

---

### Task 9: AppleMusicProvider with mock runner

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/AppleMusicProvider.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/AppleMusicProviderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/AppleMusicProviderTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class MockAppleScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [Result<RawTrackInfo?, Error>] = []
    private(set) var sentCommands: [NowPlayingControlCommand] = []

    func enqueue(_ result: Result<RawTrackInfo?, Error>) {
        lock.lock(); defer { lock.unlock() }
        queue.append(result)
    }

    func fetchTrack() async throws -> RawTrackInfo? {
        lock.lock()
        let next = queue.isEmpty ? .success(nil) : queue.removeFirst()
        lock.unlock()
        return try next.get()
    }

    func sendControl(_ command: NowPlayingControlCommand) async throws {
        lock.lock(); defer { lock.unlock() }
        sentCommands.append(command)
    }
}

final class AppleMusicProviderTests: XCTestCase {
    func testEmitsTrackWhenRunnerReportsPlaying() async throws {
        let runner = MockAppleScriptRunner()
        let info = RawTrackInfo(
            title: "Clair de Lune",
            artist: "Lang Lang",
            album: "Suite bergamasque",
            composer: "Claude Debussy",
            artworkData: Data([0xAA]),
            artworkURL: nil,
            trackID: "1",
            isPlaying: true
        )
        runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.title, "Clair de Lune")
        XCTAssertEqual(track??.composer, "Claude Debussy")
        XCTAssertEqual(track??.source, .appleMusic)
        XCTAssertEqual(track??.artwork, .data(Data([0xAA])))
    }

    func testEmitsNilWhenRunnerReportsNotPlaying() async throws {
        let runner = MockAppleScriptRunner()
        runner.enqueue(.success(nil))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertNil(track ?? nil)
    }

    func testForwardsControlCommands() async throws {
        let runner = MockAppleScriptRunner()
        let provider = AppleMusicProvider(runner: runner, clock: SystemNowPlayingClock(), pollInterval: 60)
        try await provider.send(.playPause)
        try await provider.send(.nextTrack)
        XCTAssertEqual(runner.sentCommands, [.playPause, .nextTrack])
    }

    func testIgnoresAppNotInstalledError() async throws {
        let runner = MockAppleScriptRunner()
        runner.enqueue(.failure(AppleScriptRunnerError.appNotInstalled))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(runner: runner, clock: clock, pollInterval: 0.01)

        // Should not crash and should not emit anything for the failure.
        // Verify by enqueueing a valid track right after; provider should emit that one.
        let info = RawTrackInfo(
            title: "Aja",
            artist: "Steely Dan",
            album: "Aja",
            composer: nil,
            artworkData: nil,
            artworkURL: nil,
            trackID: "2",
            isPlaying: true
        )
        runner.enqueue(.success(info))

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.title, "Aja")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.AppleMusicProviderTests`
Expected: build fails with "cannot find 'AppleMusicProvider' in scope"

- [ ] **Step 3: Implement the provider**

Create `Sources/LunoEngineCore/NowPlaying/AppleMusicProvider.swift`:

```swift
import Foundation

public final class AppleMusicProvider: NowPlayingProvider, NowPlayingControls, @unchecked Sendable {
    public let source: NowPlayingSource = .appleMusic
    public let tracks: AsyncStream<NowPlayingTrack?>

    private let runner: AppleScriptRunner
    private let clock: NowPlayingClock
    private let pollInterval: TimeInterval
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation
    private let lock = NSLock()
    private var pollTask: Task<Void, Never>?
    private var lastEmitted: NowPlayingTrack?

    public init(
        runner: AppleScriptRunner,
        clock: NowPlayingClock = SystemNowPlayingClock(),
        pollInterval: TimeInterval = 1.0
    ) {
        self.runner = runner
        self.clock = clock
        self.pollInterval = pollInterval
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    public func start() async {
        lock.lock(); defer { lock.unlock() }
        pollTask?.cancel()
        let runner = runner
        let clock = clock
        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let result: Result<RawTrackInfo?, Error>
                do {
                    let info = try await runner.fetchTrack()
                    result = .success(info)
                } catch {
                    result = .failure(error)
                }

                await self?.handle(result: result, now: clock.now())
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stop() async {
        lock.lock()
        pollTask?.cancel()
        pollTask = nil
        lock.unlock()
        continuation.finish()
    }

    public func send(_ command: NowPlayingControlCommand) async throws {
        try await runner.sendControl(command)
    }

    private func handle(result: Result<RawTrackInfo?, Error>, now: Date) {
        switch result {
        case .failure:
            return
        case .success(let raw):
            let track = raw.map { mapToTrack($0, now: now) }
            lock.lock()
            let changed = track != lastEmitted
            if changed { lastEmitted = track }
            lock.unlock()
            if changed { continuation.yield(track) }
        }
    }

    private func mapToTrack(_ raw: RawTrackInfo, now: Date) -> NowPlayingTrack {
        let artwork: NowPlayingTrack.Artwork?
        if let data = raw.artworkData {
            artwork = .data(data)
        } else if let url = raw.artworkURL {
            artwork = .url(url)
        } else {
            artwork = nil
        }
        return NowPlayingTrack(
            title: raw.title,
            artist: raw.artist,
            album: raw.album,
            composer: raw.composer,
            artwork: artwork,
            source: source,
            isPlaying: raw.isPlaying,
            isAdvertisement: false,
            updatedAt: now
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.AppleMusicProviderTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/AppleMusicProvider.swift \
        Tests/LunoEngineCoreTests/NowPlaying/AppleMusicProviderTests.swift
git commit -m "feat(now-playing): add AppleMusicProvider with polling + controls"
```

---

### Task 10: Real NSAppleScriptRunner for Music.app

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/MusicAppScriptRunner.swift`

This task ships the production runner. Integration testing requires Music.app on the developer's machine; we do not commit an automated integration test (run by hand during QA in Task 26).

- [ ] **Step 1: Implement the runner**

Create `Sources/LunoEngineCore/NowPlaying/MusicAppScriptRunner.swift`:

```swift
import Foundation

public final class MusicAppScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.luno.applescript.music")
    private let fetchScript: NSAppleScript?
    private let lock = NSLock()

    public init() {
        let source = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing or player state is paused then
                    set isPlayingFlag to (player state is playing) as integer
                    set trk to current track
                    set trackName to (name of trk as string)
                    try
                        set trackArtist to (artist of trk as string)
                    on error
                        set trackArtist to ""
                    end try
                    try
                        set trackAlbum to (album of trk as string)
                    on error
                        set trackAlbum to ""
                    end try
                    try
                        set trackComposer to (composer of trk as string)
                    on error
                        set trackComposer to ""
                    end try
                    try
                        set trackPID to (persistent ID of trk as string)
                    on error
                        set trackPID to ""
                    end try
                    set artData to ""
                    try
                        set artList to artworks of trk
                        if (count of artList) > 0 then
                            set artData to (data of item 1 of artList as string)
                        end if
                    on error
                        set artData to ""
                    end try
                    return {trackName, trackArtist, trackAlbum, trackComposer, trackPID, isPlayingFlag, artData}
                end if
            end tell
        end if
        return {}
        """
        self.fetchScript = NSAppleScript(source: source)
        var compileError: NSDictionary?
        _ = self.fetchScript?.compileAndReturnError(&compileError)
    }

    public func fetchTrack() async throws -> RawTrackInfo? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let script = self.fetchScript else {
                    continuation.resume(throwing: AppleScriptRunnerError.scriptError("script not compiled"))
                    return
                }
                var error: NSDictionary?
                let descriptor = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                    return
                }
                continuation.resume(returning: Self.parse(descriptor))
            }
        }
    }

    public func sendControl(_ command: NowPlayingControlCommand) async throws {
        let action: String
        switch command {
        case .play: action = "play"
        case .pause: action = "pause"
        case .playPause: action = "playpause"
        case .nextTrack: action = "next track"
        case .previousTrack: action = "previous track"
        }
        let source = """
        if application "Music" is running then
            tell application "Music" to \(action)
        end if
        """
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptRunnerError.scriptError("invalid script for \(command)")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func parse(_ descriptor: NSAppleEventDescriptor) -> RawTrackInfo? {
        guard descriptor.numberOfItems >= 6 else { return nil }
        let name = descriptor.atIndex(1)?.stringValue ?? ""
        guard !name.isEmpty else { return nil }
        let artist = descriptor.atIndex(2)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let album = descriptor.atIndex(3)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let composer = descriptor.atIndex(4)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let trackID = descriptor.atIndex(5)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let playingFlag = descriptor.atIndex(6)?.int32Value ?? 0
        var artData: Data?
        if descriptor.numberOfItems >= 7,
           let artString = descriptor.atIndex(7)?.stringValue,
           !artString.isEmpty,
           let decoded = Data(base64Encoded: artString) {
            artData = decoded
        }
        return RawTrackInfo(
            title: name,
            artist: artist,
            album: album,
            composer: composer,
            artworkData: artData,
            artworkURL: nil,
            trackID: trackID,
            isPlaying: playingFlag == 1
        )
    }

    private static func mapError(_ error: NSDictionary) -> AppleScriptRunnerError {
        let code = (error["NSAppleScriptErrorNumber"] as? Int) ?? 0
        if code == -1743 {
            return .permissionDenied
        }
        if code == -1728 {
            return .appNotInstalled
        }
        let message = (error["NSAppleScriptErrorMessage"] as? String) ?? "unknown AppleScript error \(code)"
        return .scriptError(message)
    }
}
```

> Note: the AppleScript above returns artwork data as a base64 string. The Music.app `data of artwork` term returns binary; we wrap it with `as string` so the descriptor crosses the bridge cleanly. If empirical testing in Task 26 shows this doesn't decode correctly, fall back to returning the artwork through the file system via `tell application "Music" to set theData to data of artwork 1 of trk; tell application "Finder" to ...` (full alternative provided in the spec under "Risks", not in this plan).

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/MusicAppScriptRunner.swift
git commit -m "feat(now-playing): add MusicAppScriptRunner (production AppleScript impl)"
```

---

## Phase 4 — Spotify provider

### Task 11: SpotifyProvider with mock runner + ad detection

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/SpotifyProvider.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/SpotifyProviderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/SpotifyProviderTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class SpotifyProviderTests: XCTestCase {
    func testEmitsTrackWithArtworkURL() async throws {
        let runner = MockAppleScriptRunner()
        let info = RawTrackInfo(
            title: "Aja",
            artist: "Steely Dan",
            album: "Aja",
            composer: nil,
            artworkData: nil,
            artworkURL: URL(string: "https://i.scdn.co/image/abc.jpg")!,
            trackID: "spotify:track:abc",
            isPlaying: true
        )
        runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = SpotifyProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.source, .spotify)
        XCTAssertEqual(track??.artwork, .url(URL(string: "https://i.scdn.co/image/abc.jpg")!))
        XCTAssertFalse(track??.isAdvertisement ?? true)
    }

    func testMarksAdvertisementWhenTrackIDHasAdPrefix() async throws {
        let runner = MockAppleScriptRunner()
        let info = RawTrackInfo(
            title: "Ad",
            artist: nil,
            album: nil,
            composer: nil,
            artworkData: nil,
            artworkURL: nil,
            trackID: "spotify:ad:12345",
            isPlaying: true
        )
        runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = SpotifyProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertTrue(track??.isAdvertisement ?? false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.SpotifyProviderTests`
Expected: build fails with "cannot find 'SpotifyProvider' in scope"

- [ ] **Step 3: Implement the provider**

Create `Sources/LunoEngineCore/NowPlaying/SpotifyProvider.swift`:

```swift
import Foundation

public final class SpotifyProvider: NowPlayingProvider, NowPlayingControls, @unchecked Sendable {
    public let source: NowPlayingSource = .spotify
    public let tracks: AsyncStream<NowPlayingTrack?>

    private let runner: AppleScriptRunner
    private let clock: NowPlayingClock
    private let pollInterval: TimeInterval
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation
    private let lock = NSLock()
    private var pollTask: Task<Void, Never>?
    private var lastEmitted: NowPlayingTrack?

    public init(
        runner: AppleScriptRunner,
        clock: NowPlayingClock = SystemNowPlayingClock(),
        pollInterval: TimeInterval = 1.0
    ) {
        self.runner = runner
        self.clock = clock
        self.pollInterval = pollInterval
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    public func start() async {
        lock.lock(); defer { lock.unlock() }
        pollTask?.cancel()
        let runner = runner
        let clock = clock
        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let result: Result<RawTrackInfo?, Error>
                do {
                    let info = try await runner.fetchTrack()
                    result = .success(info)
                } catch {
                    result = .failure(error)
                }
                await self?.handle(result: result, now: clock.now())
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stop() async {
        lock.lock()
        pollTask?.cancel()
        pollTask = nil
        lock.unlock()
        continuation.finish()
    }

    public func send(_ command: NowPlayingControlCommand) async throws {
        try await runner.sendControl(command)
    }

    private func handle(result: Result<RawTrackInfo?, Error>, now: Date) {
        switch result {
        case .failure:
            return
        case .success(let raw):
            let track = raw.map { mapToTrack($0, now: now) }
            lock.lock()
            let changed = track != lastEmitted
            if changed { lastEmitted = track }
            lock.unlock()
            if changed { continuation.yield(track) }
        }
    }

    private func mapToTrack(_ raw: RawTrackInfo, now: Date) -> NowPlayingTrack {
        let artwork: NowPlayingTrack.Artwork?
        if let data = raw.artworkData {
            artwork = .data(data)
        } else if let url = raw.artworkURL {
            artwork = .url(url)
        } else {
            artwork = nil
        }
        let isAd = raw.trackID?.hasPrefix("spotify:ad:") == true
        return NowPlayingTrack(
            title: raw.title,
            artist: raw.artist,
            album: raw.album,
            composer: nil, // Spotify does not expose composer
            artwork: artwork,
            source: source,
            isPlaying: raw.isPlaying,
            isAdvertisement: isAd,
            updatedAt: now
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.SpotifyProviderTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/SpotifyProvider.swift \
        Tests/LunoEngineCoreTests/NowPlaying/SpotifyProviderTests.swift
git commit -m "feat(now-playing): add SpotifyProvider with ad detection"
```

---

### Task 12: SpotifyAppScriptRunner (production AppleScript impl)

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/SpotifyAppScriptRunner.swift`

- [ ] **Step 1: Implement**

Create `Sources/LunoEngineCore/NowPlaying/SpotifyAppScriptRunner.swift`:

```swift
import Foundation

public final class SpotifyAppScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.luno.applescript.spotify")
    private let fetchScript: NSAppleScript?

    public init() {
        let source = """
        if application "Spotify" is running then
            tell application "Spotify"
                set playState to player state as string
                if playState is "playing" or playState is "paused" then
                    set isPlayingFlag to ((playState is "playing") as integer)
                    set trk to current track
                    set trackName to (name of trk as string)
                    try
                        set trackArtist to (artist of trk as string)
                    on error
                        set trackArtist to ""
                    end try
                    try
                        set trackAlbum to (album of trk as string)
                    on error
                        set trackAlbum to ""
                    end try
                    try
                        set trackArtURL to (artwork url of trk as string)
                    on error
                        set trackArtURL to ""
                    end try
                    try
                        set trackSpotID to (spotify url of trk as string)
                    on error
                        set trackSpotID to ""
                    end try
                    return {trackName, trackArtist, trackAlbum, trackSpotID, isPlayingFlag, trackArtURL}
                end if
            end tell
        end if
        return {}
        """
        self.fetchScript = NSAppleScript(source: source)
        var compileError: NSDictionary?
        _ = self.fetchScript?.compileAndReturnError(&compileError)
    }

    public func fetchTrack() async throws -> RawTrackInfo? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let script = self.fetchScript else {
                    continuation.resume(throwing: AppleScriptRunnerError.scriptError("script not compiled"))
                    return
                }
                var error: NSDictionary?
                let descriptor = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                    return
                }
                continuation.resume(returning: Self.parse(descriptor))
            }
        }
    }

    public func sendControl(_ command: NowPlayingControlCommand) async throws {
        let action: String
        switch command {
        case .play: action = "play"
        case .pause: action = "pause"
        case .playPause: action = "playpause"
        case .nextTrack: action = "next track"
        case .previousTrack: action = "previous track"
        }
        let source = """
        if application "Spotify" is running then
            tell application "Spotify" to \(action)
        end if
        """
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptRunnerError.scriptError("invalid script for \(command)")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func parse(_ descriptor: NSAppleEventDescriptor) -> RawTrackInfo? {
        guard descriptor.numberOfItems >= 5 else { return nil }
        let name = descriptor.atIndex(1)?.stringValue ?? ""
        guard !name.isEmpty else { return nil }
        let artist = descriptor.atIndex(2)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let album = descriptor.atIndex(3)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let trackID = descriptor.atIndex(4)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let playingFlag = descriptor.atIndex(5)?.int32Value ?? 0
        let artURL: URL? = {
            guard descriptor.numberOfItems >= 6,
                  let urlString = descriptor.atIndex(6)?.stringValue,
                  !urlString.isEmpty,
                  let url = URL(string: urlString) else { return nil }
            return url
        }()
        return RawTrackInfo(
            title: name,
            artist: artist,
            album: album,
            composer: nil,
            artworkData: nil,
            artworkURL: artURL,
            trackID: trackID,
            isPlaying: playingFlag == 1
        )
    }

    private static func mapError(_ error: NSDictionary) -> AppleScriptRunnerError {
        let code = (error["NSAppleScriptErrorNumber"] as? Int) ?? 0
        if code == -1743 { return .permissionDenied }
        if code == -1728 { return .appNotInstalled }
        let message = (error["NSAppleScriptErrorMessage"] as? String) ?? "unknown AppleScript error \(code)"
        return .scriptError(message)
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/SpotifyAppScriptRunner.swift
git commit -m "feat(now-playing): add SpotifyAppScriptRunner (production AppleScript impl)"
```

---

## Phase 5 — MediaRemote provider

### Task 13: MediaRemoteSymbols dlopen wrapper

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/MediaRemoteSymbols.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/MediaRemoteSymbolsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/MediaRemoteSymbolsTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class MediaRemoteSymbolsTests: XCTestCase {
    func testSymbolsAreAvailableOnHostMachine() {
        // This is a smoke test. On macOS hosts where the framework still loads,
        // the resolver finds the three symbols. If macOS 15.4+ has revoked access,
        // the function pointers will be nil — which is the correct fallback path.
        let symbols = MediaRemoteSymbols.load()
        // Either both registration symbols load or none of them do.
        XCTAssertEqual(symbols.registerForNotifications == nil,
                       symbols.unregisterForNotifications == nil)
    }

    func testEmptySymbolsReportUnavailable() {
        let empty = MediaRemoteSymbols(
            getNowPlayingInfo: nil,
            registerForNotifications: nil,
            unregisterForNotifications: nil
        )
        XCTAssertFalse(empty.isAvailable)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.MediaRemoteSymbolsTests`
Expected: build fails with "cannot find 'MediaRemoteSymbols' in scope"

- [ ] **Step 3: Implement**

Create `Sources/LunoEngineCore/NowPlaying/MediaRemoteSymbols.swift`:

```swift
import Foundation

public typealias MRGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
public typealias MRRegisterFunction = @convention(c) () -> Void
public typealias MRUnregisterFunction = @convention(c) () -> Void

public struct MediaRemoteSymbols: Sendable {
    public let getNowPlayingInfo: MRGetNowPlayingInfoFunction?
    public let registerForNotifications: MRRegisterFunction?
    public let unregisterForNotifications: MRUnregisterFunction?

    public init(
        getNowPlayingInfo: MRGetNowPlayingInfoFunction?,
        registerForNotifications: MRRegisterFunction?,
        unregisterForNotifications: MRUnregisterFunction?
    ) {
        self.getNowPlayingInfo = getNowPlayingInfo
        self.registerForNotifications = registerForNotifications
        self.unregisterForNotifications = unregisterForNotifications
    }

    public var isAvailable: Bool {
        getNowPlayingInfo != nil
    }

    public static func load() -> MediaRemoteSymbols {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            return MediaRemoteSymbols(getNowPlayingInfo: nil, registerForNotifications: nil, unregisterForNotifications: nil)
        }
        defer { /* leak handle for process lifetime */ _ = handle }

        func resolve<T>(_ name: String) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        let get: MRGetNowPlayingInfoFunction? = resolve("MRMediaRemoteGetNowPlayingInfo")
        let reg: MRRegisterFunction? = resolve("MRMediaRemoteRegisterForNowPlayingNotifications")
        let unreg: MRUnregisterFunction? = resolve("MRMediaRemoteUnregisterForNowPlayingNotifications")

        return MediaRemoteSymbols(
            getNowPlayingInfo: get,
            registerForNotifications: reg,
            unregisterForNotifications: unreg
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.MediaRemoteSymbolsTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/MediaRemoteSymbols.swift \
        Tests/LunoEngineCoreTests/NowPlaying/MediaRemoteSymbolsTests.swift
git commit -m "feat(now-playing): add MediaRemoteSymbols dlopen wrapper"
```

---

### Task 14: MediaRemoteProvider

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/MediaRemoteProvider.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/MediaRemoteProviderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/MediaRemoteProviderTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class MediaRemoteProviderTests: XCTestCase {
    func testStaysSilentWhenSymbolsUnavailable() async throws {
        let symbols = MediaRemoteSymbols(
            getNowPlayingInfo: nil,
            registerForNotifications: nil,
            unregisterForNotifications: nil
        )
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = MediaRemoteProvider(symbols: symbols, clock: clock, pollInterval: 0.01)

        await provider.start()
        // Stop quickly; no crashes, no controls produced.
        await provider.stop()

        // Ensure send commands throw rather than crash.
        do {
            try await provider.send(.playPause)
            XCTFail("Expected unavailable error")
        } catch MediaRemoteProvider.UnavailableError.frameworkUnavailable {
            // expected
        }
    }

    func testParsesInfoDictionaryIntoTrack() {
        let info: [String: Any] = [
            "kMRMediaRemoteNowPlayingInfoTitle": "Clair de Lune",
            "kMRMediaRemoteNowPlayingInfoArtist": "Lang Lang",
            "kMRMediaRemoteNowPlayingInfoAlbum": "Suite bergamasque",
            "kMRMediaRemoteNowPlayingInfoComposer": "Claude Debussy",
            "kMRMediaRemoteNowPlayingInfoArtworkData": Data([0xCC, 0xDD]),
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": Double(1.0)
        ]
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 2_000))
        let track = MediaRemoteProvider.makeTrack(from: info, now: clock.now())
        XCTAssertEqual(track?.title, "Clair de Lune")
        XCTAssertEqual(track?.composer, "Claude Debussy")
        XCTAssertEqual(track?.source, .mediaRemote)
        XCTAssertTrue(track?.isPlaying ?? false)
        XCTAssertEqual(track?.artwork, .data(Data([0xCC, 0xDD])))
    }

    func testReturnsNilWhenInfoHasNoTitle() {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 2_000))
        XCTAssertNil(MediaRemoteProvider.makeTrack(from: [:], now: clock.now()))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.MediaRemoteProviderTests`
Expected: build fails with "cannot find 'MediaRemoteProvider' in scope"

- [ ] **Step 3: Implement**

Create `Sources/LunoEngineCore/NowPlaying/MediaRemoteProvider.swift`:

```swift
import Foundation

public final class MediaRemoteProvider: NowPlayingProvider, NowPlayingControls, @unchecked Sendable {
    public enum UnavailableError: Error, Equatable {
        case frameworkUnavailable
    }

    public let source: NowPlayingSource = .mediaRemote
    public let tracks: AsyncStream<NowPlayingTrack?>

    private let symbols: MediaRemoteSymbols
    private let clock: NowPlayingClock
    private let pollInterval: TimeInterval
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation
    private let queue = DispatchQueue(label: "com.luno.mediaremote.poll")
    private let lock = NSLock()
    private var pollTask: Task<Void, Never>?
    private var observerToken: NSObjectProtocol?
    private var lastEmitted: NowPlayingTrack?

    public init(
        symbols: MediaRemoteSymbols = MediaRemoteSymbols.load(),
        clock: NowPlayingClock = SystemNowPlayingClock(),
        pollInterval: TimeInterval = 5.0
    ) {
        self.symbols = symbols
        self.clock = clock
        self.pollInterval = pollInterval
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    public func start() async {
        guard symbols.isAvailable else { return }
        symbols.registerForNotifications?()

        observerToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshOnce()
        }

        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshOnce()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stop() async {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
        symbols.unregisterForNotifications?()
        lock.lock()
        pollTask?.cancel()
        pollTask = nil
        lock.unlock()
        continuation.finish()
    }

    public func send(_ command: NowPlayingControlCommand) async throws {
        // MediaRemote control is not part of this provider's public surface.
        // The widget disables control buttons when active source is .mediaRemote.
        throw UnavailableError.frameworkUnavailable
    }

    private func refreshOnce() {
        guard let getInfo = symbols.getNowPlayingInfo else { return }
        let now = clock.now()
        getInfo(queue) { [weak self] info in
            guard let self else { return }
            let track = MediaRemoteProvider.makeTrack(from: info, now: now)
            self.lock.lock()
            let changed = track != self.lastEmitted
            if changed { self.lastEmitted = track }
            self.lock.unlock()
            if changed { self.continuation.yield(track) }
        }
    }

    static func makeTrack(from info: [String: Any], now: Date) -> NowPlayingTrack? {
        guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty else {
            return nil
        }
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
        let composer = info["kMRMediaRemoteNowPlayingInfoComposer"] as? String
        let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
        let artwork: NowPlayingTrack.Artwork? = artworkData.map { .data($0) }

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            composer: composer,
            artwork: artwork,
            source: .mediaRemote,
            isPlaying: rate > 0,
            isAdvertisement: false,
            updatedAt: now
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.MediaRemoteProviderTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/MediaRemoteProvider.swift \
        Tests/LunoEngineCoreTests/NowPlaying/MediaRemoteProviderTests.swift
git commit -m "feat(now-playing): add MediaRemoteProvider (notification + fallback poll)"
```

---

## Phase 6 — Preferences

### Task 15: NowPlayingPreferences store

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingPreferencesStoreTests: XCTestCase {
    func testRoundTripsAllFields() throws {
        let directory = try temporaryDirectory()
        let store = NowPlayingPreferencesStore(fileURL: directory.appending(path: "now-playing.json"))

        let prefs = NowPlayingPreferences(
            isEnabled: true,
            style: .compactBar,
            audioReactivityEnabled: true,
            keepVisibleWhilePaused: false,
            positionsByDisplay: ["1": NowPlayingPreferences.Position(x: 1200, y: 80)]
        )
        try store.save(prefs)

        let loaded = try store.load()
        XCTAssertEqual(loaded, prefs)
    }

    func testLoadReturnsDefaultsWhenFileMissing() throws {
        let directory = try temporaryDirectory()
        let store = NowPlayingPreferencesStore(fileURL: directory.appending(path: "now-playing.json"))
        XCTAssertEqual(try store.load(), .defaults)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingPreferencesStoreTests`
Expected: build fails.

- [ ] **Step 3: Implement**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift`:

```swift
import Foundation

public struct NowPlayingPreferences: Codable, Equatable, Sendable {
    public enum Style: String, Codable, Sendable, CaseIterable {
        case albumDominant
        case compactBar
        case minimal
    }

    public struct Position: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    public var isEnabled: Bool
    public var style: Style
    public var audioReactivityEnabled: Bool
    public var keepVisibleWhilePaused: Bool
    public var positionsByDisplay: [String: Position]

    public init(
        isEnabled: Bool,
        style: Style,
        audioReactivityEnabled: Bool,
        keepVisibleWhilePaused: Bool,
        positionsByDisplay: [String: Position]
    ) {
        self.isEnabled = isEnabled
        self.style = style
        self.audioReactivityEnabled = audioReactivityEnabled
        self.keepVisibleWhilePaused = keepVisibleWhilePaused
        self.positionsByDisplay = positionsByDisplay
    }

    public static let defaults = NowPlayingPreferences(
        isEnabled: false,
        style: .compactBar,
        audioReactivityEnabled: true,
        keepVisibleWhilePaused: false,
        positionsByDisplay: [:]
    )
}

public struct NowPlayingPreferencesStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> NowPlayingPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(NowPlayingPreferences.self, from: data)
    }

    public func save(_ preferences: NowPlayingPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingPreferencesStoreTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift \
        Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift
git commit -m "feat(now-playing): add NowPlayingPreferences + store"
```

---

## Phase 7 — Pipeline (debounce + artwork fetch)

### Task 16: ArtworkFetcher protocol + memory cache

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/ArtworkFetcher.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/ArtworkFetcherTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/ArtworkFetcherTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class StubURLLoader: ArtworkURLLoader, @unchecked Sendable {
    var results: [URL: Result<Data, Error>] = [:]
    private(set) var fetchedURLs: [URL] = []

    func loadData(from url: URL) async throws -> Data {
        fetchedURLs.append(url)
        if let result = results[url] {
            return try result.get()
        }
        throw URLError(.cannotConnectToHost)
    }
}

final class ArtworkFetcherTests: XCTestCase {
    func testReturnsCachedDataAfterFirstFetch() async throws {
        let loader = StubURLLoader()
        let url = URL(string: "https://example.com/art.jpg")!
        loader.results[url] = .success(Data([0xAA, 0xBB]))
        let fetcher = ArtworkFetcher(loader: loader)

        let first = try await fetcher.data(for: url)
        let second = try await fetcher.data(for: url)

        XCTAssertEqual(first, Data([0xAA, 0xBB]))
        XCTAssertEqual(second, Data([0xAA, 0xBB]))
        XCTAssertEqual(loader.fetchedURLs.count, 1, "Second fetch must hit cache")
    }

    func testThrowsWhenLoaderFails() async {
        let loader = StubURLLoader()
        let url = URL(string: "https://example.com/missing.jpg")!
        loader.results[url] = .failure(URLError(.fileDoesNotExist))
        let fetcher = ArtworkFetcher(loader: loader)
        do {
            _ = try await fetcher.data(for: url)
            XCTFail("Expected error")
        } catch {
            // ok
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.ArtworkFetcherTests`
Expected: build fails with "cannot find 'ArtworkFetcher' in scope"

- [ ] **Step 3: Implement**

Create `Sources/LunoEngineCore/NowPlaying/ArtworkFetcher.swift`:

```swift
import Foundation

public protocol ArtworkURLLoader: Sendable {
    func loadData(from url: URL) async throws -> Data
}

public struct URLSessionArtworkLoader: ArtworkURLLoader {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func loadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public actor ArtworkFetcher {
    private let loader: ArtworkURLLoader
    private var cache: [URL: Data] = [:]
    private let cacheLimit: Int

    public init(loader: ArtworkURLLoader = URLSessionArtworkLoader(), cacheLimit: Int = 64) {
        self.loader = loader
        self.cacheLimit = cacheLimit
    }

    public func data(for url: URL) async throws -> Data {
        if let cached = cache[url] { return cached }
        let data = try await loader.loadData(from: url)
        cache[url] = data
        if cache.count > cacheLimit {
            // Evict an arbitrary entry. Memory pressure handling, not LRU.
            if let key = cache.keys.first(where: { $0 != url }) {
                cache.removeValue(forKey: key)
            }
        }
        return data
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.ArtworkFetcherTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/ArtworkFetcher.swift \
        Tests/LunoEngineCoreTests/NowPlaying/ArtworkFetcherTests.swift
git commit -m "feat(now-playing): add ArtworkFetcher with memory cache"
```

---

### Task 17: NowPlayingPipeline — artwork resolution + dedup

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingPipeline.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPipelineTests.swift`

The pipeline subscribes to the coordinator's stream and resolves `.url` artworks into `.data` by calling the fetcher. It also dedups by (title, artist, album, isPlaying) so repeated identical tracks don't refire downstream. The output is `AsyncStream<ResolvedNowPlayingTrack?>` where artwork is always either `Data` or `nil`. (Debounce was considered but is unnecessary — the coordinator already emits only on change.)

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPipelineTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingPipelineTests: XCTestCase {
    func testResolvesURLArtworkIntoData() async throws {
        let loader = StubURLLoader()
        let url = URL(string: "https://example.com/art.jpg")!
        loader.results[url] = .success(Data([0xDE, 0xAD]))
        let fetcher = ArtworkFetcher(loader: loader)

        let upstream = AsyncStream<NowPlayingTrack?> { continuation in
            continuation.yield(NowPlayingTrack(
                title: "Aja",
                artist: "Steely Dan",
                album: "Aja",
                composer: nil,
                artwork: .url(url),
                source: .spotify,
                isPlaying: true,
                isAdvertisement: false,
                updatedAt: Date(timeIntervalSince1970: 100)
            ))
            continuation.finish()
        }

        let pipeline = NowPlayingPipeline(upstream: upstream, fetcher: fetcher)
        var iter = pipeline.output.makeAsyncIterator()
        let resolved = await iter.next() ?? nil
        XCTAssertEqual(resolved?.artworkData, Data([0xDE, 0xAD]))
        XCTAssertEqual(resolved?.title, "Aja")
    }

    func testDedupsIdenticalConsecutiveTracks() async throws {
        let fetcher = ArtworkFetcher(loader: StubURLLoader())
        let upstream = AsyncStream<NowPlayingTrack?> { continuation in
            let track = NowPlayingTrack(title: "X", artist: "Y", album: "Z", composer: nil, artwork: nil, source: .appleMusic, isPlaying: true, isAdvertisement: false, updatedAt: Date(timeIntervalSince1970: 1))
            continuation.yield(track)
            continuation.yield(track)
            continuation.finish()
        }
        let pipeline = NowPlayingPipeline(upstream: upstream, fetcher: fetcher)
        var iter = pipeline.output.makeAsyncIterator()
        let first = await iter.next() ?? nil
        let second = await iter.next() // stream finishes — outer is nil, no second resolved
        XCTAssertEqual(first?.title, "X")
        XCTAssertNil(second)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingPipelineTests`
Expected: build fails with "cannot find 'NowPlayingPipeline' in scope"

- [ ] **Step 3: Implement**

Create `Sources/LunoEngineCore/NowPlaying/NowPlayingPipeline.swift`:

```swift
import Foundation

public struct ResolvedNowPlayingTrack: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var composer: String?
    public var artworkData: Data?
    public var source: NowPlayingSource
    public var isPlaying: Bool
    public var isAdvertisement: Bool
    public var updatedAt: Date

    public init(track: NowPlayingTrack, artworkData: Data?) {
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.composer = track.composer
        self.artworkData = artworkData
        self.source = track.source
        self.isPlaying = track.isPlaying
        self.isAdvertisement = track.isAdvertisement
        self.updatedAt = track.updatedAt
    }
}

public final class NowPlayingPipeline: @unchecked Sendable {
    public let output: AsyncStream<ResolvedNowPlayingTrack?>
    private let continuation: AsyncStream<ResolvedNowPlayingTrack?>.Continuation
    private let fetcher: ArtworkFetcher
    private let lock = NSLock()
    private var pumpTask: Task<Void, Never>?
    private var lastEmittedKey: String?

    public init(upstream: AsyncStream<NowPlayingTrack?>, fetcher: ArtworkFetcher) {
        self.fetcher = fetcher
        var captured: AsyncStream<ResolvedNowPlayingTrack?>.Continuation!
        self.output = AsyncStream { captured = $0 }
        self.continuation = captured

        pumpTask = Task { [weak self] in
            for await track in upstream {
                await self?.emit(track)
            }
            self?.continuation.finish()
        }
    }

    deinit {
        pumpTask?.cancel()
    }

    private func emit(_ track: NowPlayingTrack?) async {
        guard let track else {
            lock.lock()
            let lastKey = lastEmittedKey
            lastEmittedKey = nil
            lock.unlock()
            if lastKey != nil {
                continuation.yield(nil)
            }
            return
        }

        var data: Data?
        switch track.artwork {
        case .data(let d): data = d
        case .url(let url):
            data = try? await fetcher.data(for: url)
        case .none: data = nil
        }

        let resolved = ResolvedNowPlayingTrack(track: track, artworkData: data)
        let key = "\(resolved.title)|\(resolved.artist ?? "")|\(resolved.album ?? "")|\(resolved.isPlaying)"
        lock.lock()
        let changed = key != lastEmittedKey
        if changed { lastEmittedKey = key }
        lock.unlock()
        if changed { continuation.yield(resolved) }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter LunoEngineCoreTests.NowPlayingPipelineTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingPipeline.swift \
        Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPipelineTests.swift
git commit -m "feat(now-playing): add NowPlayingPipeline with debounce + artwork resolution"
```

---

## Phase 8 — Widget UI (manual QA, no unit tests)

These tasks build SwiftUI/AppKit code in `LunoApp`. There is no `LunoAppTests` target; verification is the manual QA checklist in Task 24.

### Task 18: GlassBackground + ArtworkView + HoverControlsView

**Files:**
- Create: `Sources/LunoApp/NowPlayingWidget/Components/GlassBackground.swift`
- Create: `Sources/LunoApp/NowPlayingWidget/Components/ArtworkView.swift`
- Create: `Sources/LunoApp/NowPlayingWidget/Components/HoverControlsView.swift`

- [ ] **Step 1: GlassBackground**

Create `Sources/LunoApp/NowPlayingWidget/Components/GlassBackground.swift`:

```swift
import AppKit
import SwiftUI

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
```

- [ ] **Step 2: ArtworkView**

Create `Sources/LunoApp/NowPlayingWidget/Components/ArtworkView.swift`:

```swift
import AppKit
import SwiftUI

struct ArtworkView: View {
    let imageData: Data?
    let pulseAmplitude: Double // 0...1
    let cornerRadius: CGFloat

    @State private var animatedScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.42, blue: 0.61),
                             Color(red: 0.36, green: 0.17, blue: 0.37)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .scaleEffect(animatedScale)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onChange(of: pulseAmplitude) { _, new in
            let target = 1.0 + min(max(new, 0), 1) * 0.03
            withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) {
                animatedScale = target
            }
        }
    }
}
```

- [ ] **Step 3: HoverControlsView**

Create `Sources/LunoApp/NowPlayingWidget/Components/HoverControlsView.swift`:

```swift
import SwiftUI

struct HoverControlsView: View {
    enum Layout { case overlayCenter, horizontalRight, singleRight }
    let layout: Layout
    let canSkip: Bool
    let enabled: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: layout == .overlayCenter ? 14 : 10) {
            if canSkip {
                button("backward.fill") { onCommand(.previous) }
            }
            button("playpause.fill") { onCommand(.playPause) }
            if canSkip {
                button("forward.fill") { onCommand(.next) }
            }
        }
        .opacity(enabled ? 1.0 : 0.3)
        .allowsHitTesting(enabled)
    }

    private func button(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

enum NowPlayingControlIntent {
    case playPause, next, previous
}
```

- [ ] **Step 4: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoApp/NowPlayingWidget/Components
git commit -m "feat(now-playing): add SwiftUI widget building blocks"
```

---

### Task 19: Three style views + root NowPlayingWidgetView

**Files:**
- Create: `Sources/LunoApp/NowPlayingWidget/Styles/AlbumDominantStyle.swift`
- Create: `Sources/LunoApp/NowPlayingWidget/Styles/CompactBarStyle.swift`
- Create: `Sources/LunoApp/NowPlayingWidget/Styles/MinimalStyle.swift`
- Create: `Sources/LunoApp/NowPlayingWidget/NowPlayingWidgetView.swift`

- [ ] **Step 1: AlbumDominantStyle**

Create `Sources/LunoApp/NowPlayingWidget/Styles/AlbumDominantStyle.swift`:

```swift
import SwiftUI

struct AlbumDominantStyle: View {
    let title: String
    let artist: String?
    let album: String?
    let composer: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 8)
                    .frame(width: 152, height: 152)
                if isHovering {
                    Color.black.opacity(0.45)
                        .frame(width: 152, height: 152)
                        .cornerRadius(8)
                    HoverControlsView(layout: .overlayCenter, canSkip: true, enabled: canControl, onCommand: onCommand)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if let secondary = secondaryLine {
                    Text(secondary).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                if let composer, !composer.isEmpty {
                    Text(composer).font(.system(size: 10).italic()).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
            }
            .frame(width: 152, alignment: .leading)
        }
        .padding(14)
    }

    private var secondaryLine: String? {
        switch (artist, album) {
        case let (artist?, album?): return "\(artist) · \(album)"
        case let (artist?, nil): return artist
        case let (nil, album?): return album
        default: return nil
        }
    }
}
```

- [ ] **Step 2: CompactBarStyle**

Create `Sources/LunoApp/NowPlayingWidget/Styles/CompactBarStyle.swift`:

```swift
import SwiftUI

struct CompactBarStyle: View {
    let title: String
    let artist: String?
    let album: String?
    let composer: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 6)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if let secondary = secondaryLine {
                    Text(secondary).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                if let composer, !composer.isEmpty {
                    Text(composer).font(.system(size: 10).italic()).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isHovering ? 0.3 : 1.0)
            if isHovering {
                HoverControlsView(layout: .horizontalRight, canSkip: true, enabled: canControl, onCommand: onCommand)
            }
        }
        .padding(10)
    }

    private var secondaryLine: String? {
        switch (artist, album) {
        case let (artist?, album?): return "\(artist) · \(album)"
        case let (artist?, nil): return artist
        case let (nil, album?): return album
        default: return nil
        }
    }
}
```

- [ ] **Step 3: MinimalStyle**

Create `Sources/LunoApp/NowPlayingWidget/Styles/MinimalStyle.swift`:

```swift
import SwiftUI

struct MinimalStyle: View {
    let title: String
    let artist: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 4)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if let artist {
                    Text(artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isHovering {
                HoverControlsView(layout: .singleRight, canSkip: false, enabled: canControl, onCommand: onCommand)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
    }
}
```

- [ ] **Step 4: NowPlayingWidgetView root**

Create `Sources/LunoApp/NowPlayingWidget/NowPlayingWidgetView.swift`:

```swift
import SwiftUI

struct NowPlayingWidgetView: View {
    let style: NowPlayingPreferences.Style
    let track: ResolvedNowPlayingTrack
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        Group {
            switch style {
            case .albumDominant:
                AlbumDominantStyle(
                    title: displayTitle,
                    artist: track.artist,
                    album: track.album,
                    composer: track.composer,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            case .compactBar:
                CompactBarStyle(
                    title: displayTitle,
                    artist: track.artist,
                    album: track.album,
                    composer: track.composer,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            case .minimal:
                MinimalStyle(
                    title: displayTitle,
                    artist: track.artist,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            }
        }
        .background(GlassBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private var displayTitle: String {
        track.isAdvertisement ? "Advertisement" : track.title
    }
}

extension NowPlayingPreferences.Style {
    var widgetSize: CGSize {
        switch self {
        case .albumDominant: return CGSize(width: 180, height: 216)
        case .compactBar: return CGSize(width: 280, height: 72)
        case .minimal: return CGSize(width: 240, height: 52)
        }
    }
}
```

- [ ] **Step 5: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/LunoApp/NowPlayingWidget/Styles \
        Sources/LunoApp/NowPlayingWidget/NowPlayingWidgetView.swift
git commit -m "feat(now-playing): add three widget styles and root view"
```

---

### Task 20: NowPlayingViewModel — orchestrates pipeline + audio + preferences

**Files:**
- Create: `Sources/LunoApp/NowPlayingWidget/NowPlayingViewModel.swift`

- [ ] **Step 1: Implement**

Create `Sources/LunoApp/NowPlayingWidget/NowPlayingViewModel.swift`:

```swift
import AppKit
import LunoEngineCore
import Observation
import SwiftUI

@MainActor
@Observable
final class NowPlayingViewModel {
    var track: ResolvedNowPlayingTrack?
    var visible: Bool = false
    var isHovering: Bool = false
    var pulseAmplitude: Double = 0
    var preferences: NowPlayingPreferences
    var permissionState: PermissionState = .unknown
    var activeSource: NowPlayingSource? { track?.source }

    enum PermissionState { case unknown, granted, deniedAppleMusic, deniedSpotify, deniedBoth }

    private let coordinator: NowPlayingCoordinator
    private let pipeline: NowPlayingPipeline
    private let preferencesStore: NowPlayingPreferencesStore
    private let audioFeaturesProvider: @MainActor () -> AudioFeatures
    private var consumerTask: Task<Void, Never>?
    private var animationTimer: Timer?
    private var fadeOutTask: Task<Void, Never>?

    private let fadeOutGrace: TimeInterval = 5.0

    init(
        coordinator: NowPlayingCoordinator,
        pipeline: NowPlayingPipeline,
        preferencesStore: NowPlayingPreferencesStore,
        preferences: NowPlayingPreferences,
        audioFeaturesProvider: @escaping @MainActor () -> AudioFeatures
    ) {
        self.coordinator = coordinator
        self.pipeline = pipeline
        self.preferencesStore = preferencesStore
        self.preferences = preferences
        self.audioFeaturesProvider = audioFeaturesProvider
    }

    func start() {
        consumerTask?.cancel()
        consumerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await resolved in pipeline.output {
                handle(resolved: resolved)
            }
        }
        startAnimationTimer()
        Task { await coordinator.start() }
    }

    func stop() {
        consumerTask?.cancel()
        consumerTask = nil
        animationTimer?.invalidate()
        animationTimer = nil
        fadeOutTask?.cancel()
        fadeOutTask = nil
        Task { await coordinator.stop() }
    }

    func send(_ intent: NowPlayingControlIntent) {
        let command: NowPlayingControlCommand
        switch intent {
        case .playPause: command = .playPause
        case .next: command = .nextTrack
        case .previous: command = .previousTrack
        }
        guard let active = activeSource else { return }
        Task {
            do {
                try await sendCommand(command, to: active)
            } catch {
                // ignore — controls are best-effort
            }
        }
    }

    func update(preferences: NowPlayingPreferences) {
        self.preferences = preferences
        try? preferencesStore.save(preferences)
    }

    private func sendCommand(_ command: NowPlayingControlCommand, to source: NowPlayingSource) async throws {
        // Resolve the matching provider's controls. The coordinator does not expose
        // providers; the AppDelegate wires control senders into the ViewModel.
        // (Implemented in Task 22.)
        try controlSender?(command, source) ?? ()
    }

    var controlSender: ((NowPlayingControlCommand, NowPlayingSource) async throws -> Void)?

    private func handle(resolved: ResolvedNowPlayingTrack?) {
        fadeOutTask?.cancel()
        fadeOutTask = nil

        if let resolved, resolved.isPlaying {
            track = resolved
            withAnimation(.easeOut(duration: 0.3)) { visible = true }
            return
        }

        if let resolved, !resolved.isPlaying {
            track = resolved
            scheduleFadeOut()
            return
        }

        // resolved == nil → no source playing
        scheduleFadeOut()
    }

    private func scheduleFadeOut() {
        if preferences.keepVisibleWhilePaused {
            return
        }
        fadeOutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(fadeOutGrace))
            if !isHovering {
                withAnimation(.easeIn(duration: 0.4)) { visible = false }
            }
        }
    }

    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let features = audioFeaturesProvider()
                let base = Double(features.bass)
                let hovered = isHovering ? 0.3 : 1.0
                let strength = preferences.audioReactivityEnabled ? 0.5 : 0
                pulseAmplitude = base * strength * hovered
            }
        }
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/NowPlayingWidget/NowPlayingViewModel.swift
git commit -m "feat(now-playing): add NowPlayingViewModel"
```

---

### Task 21: NowPlayingWindowController — floating NSWindow, drag, fade

**Files:**
- Create: `Sources/LunoApp/NowPlayingWidget/NowPlayingWindowController.swift`

- [ ] **Step 1: Implement**

Create `Sources/LunoApp/NowPlayingWidget/NowPlayingWindowController.swift`:

```swift
import AppKit
import LunoEngineCore
import SwiftUI

@MainActor
final class NowPlayingWindowController: NSWindowController {
    private let viewModel: NowPlayingViewModel
    private var hostingView: NSHostingView<RootContainer>?

    init(viewModel: NowPlayingViewModel) {
        self.viewModel = viewModel
        let window = NowPlayingFloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false
        super.init(window: window)

        let root = RootContainer(viewModel: viewModel, windowController: self)
        let host = NSHostingView(rootView: root)
        host.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = host
        hostingView = host
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func show() {
        applySavedPosition()
        applySizeForCurrentStyle()
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func applySizeForCurrentStyle() {
        guard let window else { return }
        let size = viewModel.preferences.style.widgetSize
        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true, animate: false)
    }

    func saveCurrentPosition() {
        guard let window, let screen = window.screen else { return }
        let displayID = screen.lunoDisplayID.map { String($0) } ?? "main"
        var prefs = viewModel.preferences
        prefs.positionsByDisplay[displayID] = NowPlayingPreferences.Position(
            x: Double(window.frame.origin.x),
            y: Double(window.frame.origin.y)
        )
        viewModel.update(preferences: prefs)
    }

    private func applySavedPosition() {
        guard let window else { return }
        let displays = NSScreen.screens.compactMap(\.lunoDisplayID).map(String.init)
        let preferredKey = displays.first { viewModel.preferences.positionsByDisplay[$0] != nil }
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let frame = mainScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let position: NSPoint
        if let key = preferredKey, let saved = viewModel.preferences.positionsByDisplay[key] {
            position = NSPoint(x: saved.x, y: saved.y)
        } else {
            let size = viewModel.preferences.style.widgetSize
            position = NSPoint(
                x: frame.maxX - size.width - 24,
                y: frame.minY + 24
            )
        }

        let size = viewModel.preferences.style.widgetSize
        let clamped = clamp(point: position, size: size, into: frame)
        window.setFrame(NSRect(origin: clamped, size: size), display: true)
    }

    private func clamp(point: NSPoint, size: CGSize, into frame: NSRect) -> NSPoint {
        let x = min(max(point.x, frame.minX), frame.maxX - size.width)
        let y = min(max(point.y, frame.minY), frame.maxY - size.height)
        return NSPoint(x: x, y: y)
    }
}

@MainActor
private final class NowPlayingFloatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RootContainer: View {
    @Bindable var viewModel: NowPlayingViewModel
    weak var windowController: NowPlayingWindowController?

    var body: some View {
        Group {
            if viewModel.visible, let track = viewModel.track {
                NowPlayingWidgetView(
                    style: viewModel.preferences.style,
                    track: track,
                    pulseAmplitude: viewModel.pulseAmplitude,
                    isHovering: viewModel.isHovering,
                    canControl: track.source != .mediaRemote && !track.isAdvertisement,
                    onCommand: { intent in viewModel.send(intent) }
                )
                .onHover { hovering in viewModel.isHovering = hovering }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            guard let window = windowController?.window else { return }
                            var origin = window.frame.origin
                            origin.x += value.translation.width
                            origin.y -= value.translation.height
                            window.setFrameOrigin(origin)
                        }
                        .onEnded { _ in
                            windowController?.saveCurrentPosition()
                        }
                )
                .opacity(viewModel.visible ? 1 : 0)
            } else {
                Color.clear
            }
        }
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/NowPlayingWidget/NowPlayingWindowController.swift
git commit -m "feat(now-playing): add NowPlayingWindowController (floating window + drag)"
```

---

## Phase 9 — App integration

### Task 22: AppDelegate wiring + library window section + permissions sheet

**Files:**
- Modify: `Sources/LunoApp/AppDelegate.swift`
- Modify: `Sources/LunoApp/LibraryWindowController.swift`

- [ ] **Step 1: Extend `LunoAppPaths` and `AppDelegate` to construct the providers, coordinator, pipeline, and window controller**

Replace the existing `LunoAppPaths` struct in `Sources/LunoApp/AppDelegate.swift` (currently lines 292-313) so it also tracks the now-playing preferences file:

```swift
private struct LunoAppPaths {
    var root: URL
    var packages: URL
    var presets: URL
    var assignments: URL
    var nowPlayingPreferences: URL

    static func `default`() throws -> LunoAppPaths {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "Luno", directoryHint: .isDirectory)

        return LunoAppPaths(
            root: root,
            packages: root.appending(path: "Packages", directoryHint: .isDirectory),
            presets: root.appending(path: "presets.json"),
            assignments: root.appending(path: "assignments.json"),
            nowPlayingPreferences: root.appending(path: "now-playing.json")
        )
    }
}
```

- [ ] **Step 2: Add now-playing properties to `AppDelegate`**

Inside `AppDelegate` (after the `audioCapture` property near line 19), add:

```swift
    private var nowPlayingPreferencesStore: NowPlayingPreferencesStore?
    private var nowPlayingPreferences: NowPlayingPreferences = .defaults
    private var appleMusicRunner = MusicAppScriptRunner()
    private var spotifyRunner = SpotifyAppScriptRunner()
    private var nowPlayingCoordinator: NowPlayingCoordinator?
    private var nowPlayingPipeline: NowPlayingPipeline?
    private var nowPlayingViewModel: NowPlayingViewModel?
    private var nowPlayingWindowController: NowPlayingWindowController?
    private var appleMusicProvider: AppleMusicProvider?
    private var spotifyProvider: SpotifyProvider?
    private var mediaRemoteProvider: MediaRemoteProvider?
```

- [ ] **Step 3: Initialize the preferences store + load prefs in `applicationDidFinishLaunching`**

In `applicationDidFinishLaunching`, after `assignmentStore = DisplayAssignmentStore(...)`, add:

```swift
            let prefsStore = NowPlayingPreferencesStore(fileURL: paths.nowPlayingPreferences)
            nowPlayingPreferencesStore = prefsStore
            nowPlayingPreferences = (try? prefsStore.load()) ?? .defaults
```

At the end of `applicationDidFinishLaunching` (after `try restoreAssignments()`), add:

```swift
            if nowPlayingPreferences.isEnabled {
                startNowPlaying()
            }
```

- [ ] **Step 4: Add `startNowPlaying()` / `stopNowPlaying()` methods**

Add at the end of `AppDelegate`, before the `LunoAppPaths` struct:

```swift
    fileprivate func startNowPlaying() {
        guard nowPlayingCoordinator == nil else { return }

        let am = AppleMusicProvider(runner: appleMusicRunner)
        let sp = SpotifyProvider(runner: spotifyRunner)
        let mr = MediaRemoteProvider()
        appleMusicProvider = am
        spotifyProvider = sp
        mediaRemoteProvider = mr

        let coordinator = NowPlayingCoordinator(providers: [am, sp, mr])
        nowPlayingCoordinator = coordinator
        let pipeline = NowPlayingPipeline(upstream: coordinator.tracks, fetcher: ArtworkFetcher())
        nowPlayingPipeline = pipeline

        guard let prefsStore = nowPlayingPreferencesStore else { return }

        let viewModel = NowPlayingViewModel(
            coordinator: coordinator,
            pipeline: pipeline,
            preferencesStore: prefsStore,
            preferences: nowPlayingPreferences,
            audioFeaturesProvider: { [weak self] in self?.audioFeatures ?? .silent }
        )
        viewModel.controlSender = { [weak self] command, source in
            guard let self else { return }
            switch source {
            case .appleMusic: try await self.appleMusicProvider?.send(command)
            case .spotify: try await self.spotifyProvider?.send(command)
            case .mediaRemote: return
            }
        }
        nowPlayingViewModel = viewModel

        let controller = NowPlayingWindowController(viewModel: viewModel)
        nowPlayingWindowController = controller
        viewModel.start()
        controller.show()
    }

    fileprivate func stopNowPlaying() {
        nowPlayingWindowController?.hide()
        nowPlayingViewModel?.stop()
        nowPlayingWindowController = nil
        nowPlayingViewModel = nil
        nowPlayingPipeline = nil
        nowPlayingCoordinator = nil
        appleMusicProvider = nil
        spotifyProvider = nil
        mediaRemoteProvider = nil
    }

    fileprivate func updateNowPlaying(preferences: NowPlayingPreferences) {
        let wasEnabled = nowPlayingPreferences.isEnabled
        nowPlayingPreferences = preferences
        try? nowPlayingPreferencesStore?.save(preferences)
        nowPlayingViewModel?.update(preferences: preferences)
        nowPlayingWindowController?.applySizeForCurrentStyle()
        if preferences.isEnabled && !wasEnabled {
            startNowPlaying()
        } else if !preferences.isEnabled && wasEnabled {
            stopNowPlaying()
        }
    }
```

- [ ] **Step 5: Handle sleep/wake**

In `applicationDidFinishLaunching`, after the existing `NotificationCenter.default.addObserver(...)` block, add:

```swift
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
```

Add the handler methods inside `AppDelegate`:

```swift
    @objc private func systemWillSleep() {
        Task { await nowPlayingCoordinator?.stop() }
    }

    @objc private func systemDidWake() {
        guard nowPlayingPreferences.isEnabled, let coordinator = nowPlayingCoordinator else { return }
        Task { await coordinator.start() }
    }
```

- [ ] **Step 6: Add the library window section + delegate callback**

In `Sources/LunoApp/LibraryWindowController.swift`, extend `LibraryWindowControllerDelegate` (line 7-17) with one new method:

```swift
    func libraryWindow(_ controller: LibraryWindowController, didChange nowPlayingPreferences: NowPlayingPreferences)
```

Add private state and a `configureNowPlaying(_:)` method on `LibraryWindowController`:

```swift
    private var nowPlayingPreferences: NowPlayingPreferences = .defaults
    private let nowPlayingEnableSwitch = NSSwitch()
    private let nowPlayingStylePopup = NSPopUpButton()
    private let nowPlayingReactivitySwitch = NSSwitch()
    private let nowPlayingKeepVisibleSwitch = NSSwitch()

    func configureNowPlaying(_ preferences: NowPlayingPreferences) {
        self.nowPlayingPreferences = preferences
        nowPlayingEnableSwitch.state = preferences.isEnabled ? .on : .off
        nowPlayingReactivitySwitch.state = preferences.audioReactivityEnabled ? .on : .off
        nowPlayingKeepVisibleSwitch.state = preferences.keepVisibleWhilePaused ? .on : .off
        let index = NowPlayingPreferences.Style.allCases.firstIndex(of: preferences.style) ?? 0
        nowPlayingStylePopup.selectItem(at: index)
    }
```

Then in `buildUI(in:)`, before the closing brace of the function, append a new section. Add this as a private helper called from `buildUI`:

```swift
    private func buildNowPlayingSection(in stack: NSStackView) {
        let heading = NSTextField(labelWithString: "Now Playing widget")
        heading.font = NSFont.boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        nowPlayingEnableSwitch.target = self
        nowPlayingEnableSwitch.action = #selector(nowPlayingToggleChanged(_:))
        let enableRow = labeled("Enable widget", control: nowPlayingEnableSwitch)
        stack.addArrangedSubview(enableRow)

        nowPlayingStylePopup.removeAllItems()
        nowPlayingStylePopup.addItems(withTitles: ["A — Album-art dominant", "B — Compact bar", "C — Minimal"])
        nowPlayingStylePopup.target = self
        nowPlayingStylePopup.action = #selector(nowPlayingStyleChanged(_:))
        let styleRow = labeled("Style", control: nowPlayingStylePopup)
        stack.addArrangedSubview(styleRow)

        nowPlayingReactivitySwitch.target = self
        nowPlayingReactivitySwitch.action = #selector(nowPlayingReactivityChanged(_:))
        let reactivityRow = labeled("React to music", control: nowPlayingReactivitySwitch)
        stack.addArrangedSubview(reactivityRow)

        nowPlayingKeepVisibleSwitch.target = self
        nowPlayingKeepVisibleSwitch.action = #selector(nowPlayingKeepVisibleChanged(_:))
        let keepVisibleRow = labeled("Keep visible while paused", control: nowPlayingKeepVisibleSwitch)
        stack.addArrangedSubview(keepVisibleRow)
    }

    private func labeled(_ title: String, control: NSControl) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    @objc private func nowPlayingToggleChanged(_ sender: NSSwitch) {
        nowPlayingPreferences.isEnabled = sender.state == .on
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }

    @objc private func nowPlayingStyleChanged(_ sender: NSPopUpButton) {
        let styles = NowPlayingPreferences.Style.allCases
        nowPlayingPreferences.style = styles[sender.indexOfSelectedItem]
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }

    @objc private func nowPlayingReactivityChanged(_ sender: NSSwitch) {
        nowPlayingPreferences.audioReactivityEnabled = sender.state == .on
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }

    @objc private func nowPlayingKeepVisibleChanged(_ sender: NSSwitch) {
        nowPlayingPreferences.keepVisibleWhilePaused = sender.state == .on
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }
```

Call `buildNowPlayingSection(in: stack)` once at the end of `buildUI`.

Then conform `AppDelegate` to the new delegate method:

```swift
    func libraryWindow(_ controller: LibraryWindowController, didChange nowPlayingPreferences: NowPlayingPreferences) {
        updateNowPlaying(preferences: nowPlayingPreferences)
    }
```

And in `AppDelegate.showLibrary()`, after `libraryWindowController?.configure(...)`, add:

```swift
        libraryWindowController?.configureNowPlaying(nowPlayingPreferences)
```

- [ ] **Step 7: Verify the package builds and the existing test suite still passes**

Run: `swift build && swift test`
Expected: build + all prior tests pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/LunoApp/AppDelegate.swift Sources/LunoApp/LibraryWindowController.swift
git commit -m "feat(now-playing): wire widget into AppDelegate + library window"
```

---

### Task 23: Add `NSAppleEventsUsageDescription` to bundle Info.plist

**Files:**
- Modify: `scripts/build-app.sh` (or whatever currently writes the bundle Info.plist)

- [ ] **Step 1: Locate the Info.plist build step**

Run: `cat scripts/build-app.sh`

Identify where `Info.plist` is generated or copied during `.app` bundling. The line will look like `plutil -create xml1 ...` or `cat > .../Info.plist`.

- [ ] **Step 2: Add the usage-description key**

Add this entry near the other CFBundle keys:

```
<key>NSAppleEventsUsageDescription</key>
<string>Luno reads the currently playing track from Music and Spotify so the wallpaper widget can show what you're listening to.</string>
```

If `build-app.sh` writes the plist via heredoc, append the key into that block. If it copies a `Resources/Info.plist`, edit the file directly and update the script's reference.

- [ ] **Step 3: Build the .app to verify**

Run: `scripts/build-app.sh`
Expected: `.app` builds. Inspect with `plutil -p .build/release/Luno.app/Contents/Info.plist | grep NSAppleEvents`.

- [ ] **Step 4: Commit**

```bash
git add scripts/build-app.sh
git commit -m "chore(now-playing): declare NSAppleEventsUsageDescription"
```

---

## Phase 10 — Manual QA

### Task 24: Manual QA checklist

**Files:**
- Create: `docs/superpowers/qa/2026-05-13-now-playing-widget-qa.md`

- [ ] **Step 1: Create the checklist**

Create `docs/superpowers/qa/2026-05-13-now-playing-widget-qa.md` with the following content:

```markdown
# Now Playing Widget — Manual QA Checklist

Date: 2026-05-13
Tester: ____________
macOS version: ____________

## Setup

- [ ] Build via `scripts/build-app.sh` and launch `.build/release/Luno.app`.
- [ ] Open Library window. Confirm "Now Playing widget" section appears with Enable / Style / Reactivity / Keep visible toggles.

## First-run permission

- [ ] Toggle "Enable widget" ON with no music playing.
- [ ] Start Apple Music. Expect macOS Automation permission dialog. Accept.
- [ ] Expect widget to appear within ~2 seconds.

## Apple Music (full metadata case)

- [ ] Play a classical track that has a composer (e.g., Debussy — Clair de Lune).
- [ ] Verify title, artist, album, composer all show.
- [ ] Verify album artwork displays.
- [ ] Hover. Verify play/pause/skip controls appear.
- [ ] Click pause. Verify widget shows paused state. Wait 5 seconds. Verify widget fades out.
- [ ] Click play. Verify widget fades back in.
- [ ] Switch tracks. Verify metadata updates within 1 second.

## Spotify

- [ ] Open Spotify, play any track.
- [ ] Verify title, artist, album show. Composer line should be hidden (Spotify doesn't provide composer).
- [ ] Verify artwork loads from URL (may take a moment on first track).
- [ ] Verify hover controls work.
- [ ] If you encounter an ad, verify widget shows "Advertisement" and controls are disabled.

## Source switching

- [ ] Play Apple Music. Verify Apple Music shown.
- [ ] Pause Apple Music. Within 2 seconds, start Spotify.
- [ ] Verify widget switches to Spotify within ~2 seconds without flicker.

## MediaRemote fallback (browser/YouTube)

- [ ] Quit Apple Music and Spotify.
- [ ] Play audio in Safari (e.g., YouTube).
- [ ] Verify widget either shows the YouTube tab info OR stays hidden (depending on macOS 15 MediaRemote behavior).
- [ ] If shown, verify controls are visually disabled (MediaRemote is read-only in this design).

## Style switching

- [ ] In Library, switch to Style A. Verify widget grows to 180×216 with large artwork.
- [ ] Switch to Style B. Verify horizontal bar 280×72.
- [ ] Switch to Style C. Verify minimal 240×52. Composer line is absent.

## Drag and persistence

- [ ] Drag widget to a different corner.
- [ ] Quit and relaunch Luno. Verify widget reopens at the new position.

## Multi-display

- [ ] Connect a second display. Drag widget to it.
- [ ] Disconnect the second display. Verify widget reappears on the primary display, clamped on screen.

## Reactivity

- [ ] With "React to music" ON, verify the album artwork pulses with the beat and the border glows with the bass.
- [ ] Turn off "React to music". Verify widget becomes still.

## Sleep/wake

- [ ] Put Mac to sleep with music playing. Wake. Verify widget is correct within 5 seconds.

## Permission denial path

- [ ] Reset Automation permission for Luno in System Settings → Privacy → Automation.
- [ ] Re-enable widget. Deny the dialog.
- [ ] Verify widget shows a "Permission needed →" hint (or stays hidden if no other source is playing).

## Resource sanity

- [ ] In Activity Monitor, observe Luno's CPU usage during normal playback. Confirm < 3% sustained.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/qa/2026-05-13-now-playing-widget-qa.md
git commit -m "docs(now-playing): add manual QA checklist"
```

---

## Verification

After all tasks complete:

- [ ] Run the full test suite: `swift test`
  - Expected: all tests pass (existing + ~20 new tests across NowPlaying types).
- [ ] Build the app: `scripts/build-app.sh`
  - Expected: `.app` builds without errors.
- [ ] Run through the QA checklist (Task 24) on at least one machine with Apple Music + Spotify installed.

---

## Out of scope (per spec, deferred)

- Lyrics / queue / playlists.
- Global keyboard shortcuts.
- Like / bookmark actions.
- Browser-tab DOM scraping.
- App Store distribution (MediaRemote is a private framework).
- SwiftUI snapshot testing target (`LunoAppTests`).
