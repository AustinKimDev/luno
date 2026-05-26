import Foundation
import LunoEngineCore

@MainActor
final class NowPlayingSessionCoordinator {
    private(set) var preferences: NowPlayingPreferences
    var albumPalette: AlbumPalette = .fallback {
        didSet {
            nowPlayingViewModel?.albumPalette = albumPalette
        }
    }
    var bassLevelProvider: () -> Double = { 0 }
    var preferencesDidChange: ((NowPlayingPreferences) -> Void)?
    var artworkDidChange: ((Data?) -> Void)?
    var audioNeedsDidChange: (() -> Void)?

    private let preferencesStore: NowPlayingPreferencesStore
    private var appleMusicRunner = MusicAppScriptRunner()
    private var spotifyRunner = SpotifyAppScriptRunner()
    private var nowPlayingCoordinator: NowPlayingCoordinator?
    private var nowPlayingPipeline: NowPlayingPipeline?
    private var nowPlayingViewModel: NowPlayingViewModel?
    private var nowPlayingWindowController: NowPlayingWindowController?
    private var appleMusicProvider: AppleMusicProvider?
    private var spotifyProvider: SpotifyProvider?
    private var mediaRemoteProvider: MediaRemoteProvider?

    init(preferencesStore: NowPlayingPreferencesStore, preferences: NowPlayingPreferences) {
        self.preferencesStore = preferencesStore
        self.preferences = preferences
    }

    var needsAudio: Bool {
        nowPlayingViewModel != nil && preferences.audioReactivityEnabled
    }

    func start() {
        guard nowPlayingCoordinator == nil else { return }

        let appleMusicProvider = AppleMusicProvider(
            runner: appleMusicRunner,
            artworkURLResolver: ITunesSearchArtworkURLResolver()
        )
        let spotifyProvider = SpotifyProvider(runner: spotifyRunner)
        let mediaRemoteProvider = MediaRemoteProvider()
        self.appleMusicProvider = appleMusicProvider
        self.spotifyProvider = spotifyProvider
        self.mediaRemoteProvider = mediaRemoteProvider

        let coordinator = NowPlayingCoordinator(providers: [appleMusicProvider, spotifyProvider, mediaRemoteProvider])
        nowPlayingCoordinator = coordinator

        let pipeline = NowPlayingPipeline(upstream: coordinator.tracks, fetcher: ArtworkFetcher())
        nowPlayingPipeline = pipeline

        let viewModel = NowPlayingViewModel(
            coordinator: coordinator,
            pipeline: pipeline,
            preferencesStore: preferencesStore,
            preferences: preferences,
            bassLevelProvider: { [weak self] in
                self?.bassLevelProvider() ?? 0
            }
        )
        viewModel.albumPalette = albumPalette
        viewModel.onPreferencesChanged = { [weak self] preferences in
            self?.preferences = preferences
            self?.preferencesDidChange?(preferences)
            self?.audioNeedsDidChange?()
        }
        viewModel.onTrackChanged = { [weak self] track in
            self?.artworkDidChange?(track?.artworkData)
        }
        viewModel.controlSender = { [weak self] command, source in
            guard let self else { return }
            switch source {
            case .appleMusic:
                try await self.appleMusicProvider?.send(command)
            case .spotify:
                try await self.spotifyProvider?.send(command)
            case .mediaRemote:
                return
            }
        }
        nowPlayingViewModel = viewModel

        let windowController = NowPlayingWindowController(viewModel: viewModel)
        nowPlayingWindowController = windowController
        viewModel.start()
        windowController.show()
        audioNeedsDidChange?()
    }

    func stop() {
        nowPlayingWindowController?.hide()
        nowPlayingViewModel?.stop()
        nowPlayingWindowController = nil
        nowPlayingViewModel = nil
        nowPlayingPipeline = nil
        nowPlayingCoordinator = nil
        appleMusicProvider = nil
        spotifyProvider = nil
        mediaRemoteProvider = nil
        audioNeedsDidChange?()
    }

    func update(preferences: NowPlayingPreferences) {
        let wasEnabled = self.preferences.isEnabled
        self.preferences = preferences

        if let nowPlayingViewModel {
            nowPlayingViewModel.update(preferences: preferences)
            nowPlayingWindowController?.applySizeForCurrentStyle()
        } else {
            try? preferencesStore.save(preferences)
            preferencesDidChange?(preferences)
        }

        if preferences.isEnabled && !wasEnabled {
            start()
        } else if !preferences.isEnabled && wasEnabled {
            stop()
        }
        audioNeedsDidChange?()
    }
}
