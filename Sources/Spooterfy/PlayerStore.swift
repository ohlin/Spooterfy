import AppKit
import Combine
import SwiftUI

/// Polls Spotify and holds everything the window shows.
@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var current: Item?
    @Published private(set) var previous: Item?
    @Published private(set) var upNext: [Item] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var progressMs = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var problem: String?

    let auth: SpotifyAuth
    private let api: SpotifyAPI
    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var artworkURL: URL?
    private let artworkCache = NSCache<NSURL, NSImage>()
    /// When the last progress value was observed, so the UI can interpolate.
    private(set) var progressStamp = Date()

    init(auth: SpotifyAuth) {
        self.auth = auth
        self.api = SpotifyAPI(auth: auth)

        auth.$isSignedIn
            .removeDuplicates()
            .sink { [weak self] signedIn in
                guard let self else { return }
                if signedIn { self.startPolling() } else { self.stopPolling(); self.clear() }
            }
            .store(in: &cancellables)

        // Poll faster while the window is in front.
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.poke() }
            .store(in: &cancellables)
    }

    // MARK: Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.loadInitialPrevious()
            while !Task.isCancelled {
                await self?.refresh()
                let interval: Double = NSApp.isActive ? 2 : 4
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Refresh soon, e.g. right after a command or when the app comes forward.
    func poke(after delay: Double = 0) {
        guard auth.isSignedIn else { return }
        Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            await refresh()
        }
    }

    private func refresh() async {
        do {
            async let playbackReq = api.playback()
            async let queueReq = api.queue()
            let (playback, queue) = try await (playbackReq, queueReq)

            let item = playback?.item ?? queue?.currentlyPlaying
            if let item, item.id != current?.id {
                // Whatever was showing becomes "previous" the moment the track changes.
                if let current { previous = current }
                withAnimation(.easeInOut(duration: 0.35)) { current = item }
                loadArtwork(item.artworkURL)
            } else if item == nil, current != nil {
                withAnimation { current = nil }
                loadArtwork(nil)
            }

            isPlaying = playback?.isPlaying ?? false
            progressMs = playback?.progressMs ?? 0
            progressStamp = Date()

            let next = Array((queue?.queue ?? []).prefix(30))
            if next != upNext { withAnimation(.easeInOut(duration: 0.25)) { upNext = next } }

            problem = current == nil ? "Nothing playing on Spotify right now." : nil
            MediaKeys.shared.update(item: current, isPlaying: isPlaying, progressMs: progressMs)
        } catch SpotifyError.notSignedIn {
            clear()
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            problem = error.localizedDescription
        }
    }

    private func loadInitialPrevious() async {
        guard let recent = try? await api.recentlyPlayed(limit: 3) else { return }
        let currentID = (try? await api.playback())?.item?.id
        if previous == nil {
            previous = recent.first { $0.id != currentID }
        }
    }

    private func clear() {
        current = nil
        previous = nil
        upNext = []
        isPlaying = false
        artwork = nil
        artworkURL = nil
        problem = nil
        MediaKeys.shared.update(item: nil, isPlaying: false, progressMs: 0)
    }

    // MARK: Artwork

    private func loadArtwork(_ url: URL?) {
        artworkURL = url
        guard let url else {
            withAnimation(.easeInOut(duration: 0.4)) { artwork = nil }
            return
        }
        if let cached = artworkCache.object(forKey: url as NSURL) {
            withAnimation(.easeInOut(duration: 0.4)) { artwork = cached }
            return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data) else { return }
            artworkCache.setObject(image, forKey: url as NSURL)
            // Ignore a slow download for a track we've already moved past.
            guard artworkURL == url else { return }
            withAnimation(.easeInOut(duration: 0.4)) { artwork = image }
        }
    }

    // MARK: Commands

    func playPause() { send(isPlaying ? .pause : .play) }
    func next() { send(.next) }
    func previousTrack() { send(.previous) }

    func send(_ cmd: PlayerCommand) {
        // Optimistic: flip play state immediately so the UI and media keys feel instant.
        switch cmd {
        case .play: isPlaying = true
        case .pause: isPlaying = false
        default: break
        }
        Task {
            do {
                try await api.command(cmd)
            } catch {
                // 403 = free account, 404 = no active device, or not signed in yet.
                SpotifyAppleScript.run(cmd)
            }
            poke(after: 0.4)
            poke(after: 1.2)
        }
    }
}

#if DEBUG
extension PlayerStore {
    func loadSample(current: Item, previous: Item, upNext: [Item], artwork: NSImage) {
        self.current = current
        self.previous = previous
        self.upNext = upNext
        self.artwork = artwork
        self.isPlaying = false
        self.progressMs = (current.durationMs ?? 0) / 3
    }

    func stopPollingForSnapshots() { stopPolling() }
}
#endif
