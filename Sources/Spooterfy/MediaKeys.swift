import AppKit
import MediaPlayer

/// While Spooterfy is the frontmost app it claims "Now Playing", so macOS
/// routes the keyboard's play/pause, next and previous keys to it, and it
/// forwards them to Spotify. When the app loses focus it lets go again.
@MainActor
final class MediaKeys {
    static let shared = MediaKeys()

    weak var store: PlayerStore?
    private var targets: [(MPRemoteCommand, Any)] = []
    private var lastItem: Item?
    private var lastIsPlaying = false
    private var lastProgressMs = 0

    private init() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MediaKeys.shared.claim() }
        }
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MediaKeys.shared.release() }
        }
    }

    private var isClaimed: Bool { !targets.isEmpty }

    func claim() {
        guard !isClaimed else { return }
        let center = MPRemoteCommandCenter.shared()
        func add(_ command: MPRemoteCommand, _ action: @escaping @MainActor (PlayerStore) -> Void) {
            command.isEnabled = true
            let token = command.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let store = self?.store else { return }
                    action(store)
                }
                return .success
            }
            targets.append((command, token))
        }
        add(center.togglePlayPauseCommand) { $0.playPause() }
        add(center.playCommand) { $0.send(.play) }
        add(center.pauseCommand) { $0.send(.pause) }
        add(center.nextTrackCommand) { $0.next() }
        add(center.previousTrackCommand) { $0.previousTrack() }
        publish()
    }

    func release() {
        for (command, token) in targets {
            command.removeTarget(token)
            command.isEnabled = false
        }
        targets.removeAll()
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = nil
        info.playbackState = .stopped
    }

    func update(item: Item?, isPlaying: Bool, progressMs: Int) {
        lastItem = item
        lastIsPlaying = isPlaying
        lastProgressMs = progressMs
        if isClaimed { publish() }
    }

    private func publish() {
        let info = MPNowPlayingInfoCenter.default()
        guard let item = lastItem else {
            info.nowPlayingInfo = [MPMediaItemPropertyTitle: "Spooterfy"]
            info.playbackState = .paused
            return
        }
        var dict: [String: Any] = [
            MPMediaItemPropertyTitle: item.name,
            MPMediaItemPropertyArtist: item.subtitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(lastProgressMs) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: lastIsPlaying ? 1.0 : 0.0,
        ]
        if let album = item.album?.name { dict[MPMediaItemPropertyAlbumTitle] = album }
        if let ms = item.durationMs { dict[MPMediaItemPropertyPlaybackDuration] = Double(ms) / 1000 }
        info.nowPlayingInfo = dict
        // On macOS this, not audio output, is what makes the app the media-key target.
        info.playbackState = lastIsPlaying ? .playing : .paused
    }
}
