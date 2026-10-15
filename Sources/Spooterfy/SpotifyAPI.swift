import AppKit
import Foundation

/// A track or podcast episode, reduced to what the UI shows.
struct Item: Decodable, Equatable {
    struct Artist: Decodable, Equatable { let name: String }
    struct Image: Decodable, Equatable { let url: String; let width: Int? }
    struct Album: Decodable, Equatable { let name: String; let images: [Image] }
    struct Show: Decodable, Equatable { let name: String; let images: [Image]? }

    let id: String?
    let name: String
    let durationMs: Int?
    let artists: [Artist]?
    let album: Album?
    let show: Show?
    let images: [Image]?

    var subtitle: String {
        if let artists, !artists.isEmpty { return artists.map(\.name).joined(separator: ", ") }
        return show?.name ?? ""
    }

    /// The largest available artwork.
    var artworkURL: URL? {
        let all = album?.images ?? images ?? show?.images ?? []
        let best = all.max { ($0.width ?? 0) < ($1.width ?? 0) }
        return best.flatMap { URL(string: $0.url) }
    }
}

struct PlaybackState: Decodable {
    let isPlaying: Bool
    let progressMs: Int?
    let item: Item?
}

struct QueueResponse: Decodable {
    let currentlyPlaying: Item?
    let queue: [Item]
}

struct RecentlyPlayed: Decodable {
    struct Entry: Decodable { let track: Item }
    let items: [Entry]
}

@MainActor
final class SpotifyAPI {
    private let auth: SpotifyAuth
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(auth: SpotifyAuth) { self.auth = auth }

    /// nil when nothing is playing (Spotify answers 204).
    func playback() async throws -> PlaybackState? {
        guard let data = try await request("GET", "/me/player/currently-playing?additional_types=episode") else { return nil }
        return try decoder.decode(PlaybackState.self, from: data)
    }

    func queue() async throws -> QueueResponse? {
        guard let data = try await request("GET", "/me/player/queue") else { return nil }
        return try decoder.decode(QueueResponse.self, from: data)
    }

    func recentlyPlayed(limit: Int = 3) async throws -> [Item] {
        guard let data = try await request("GET", "/me/player/recently-played?limit=\(limit)") else { return [] }
        return try decoder.decode(RecentlyPlayed.self, from: data).items.map(\.track)
    }

    func command(_ cmd: PlayerCommand) async throws {
        switch cmd {
        case .play: _ = try await request("PUT", "/me/player/play")
        case .pause: _ = try await request("PUT", "/me/player/pause")
        case .next: _ = try await request("POST", "/me/player/next")
        case .previous: _ = try await request("POST", "/me/player/previous")
        case .seek(let ms): _ = try await request("PUT", "/me/player/seek?position_ms=\(ms)")
        }
    }

    /// Returns the body, or nil for an empty (204) response. Retries once after a 401.
    private func request(_ method: String, _ path: String, retried: Bool = false) async throws -> Data? {
        let token = try await auth.accessToken()
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1" + path)!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if method != "GET" { req.httpBody = Data() }

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            return data.isEmpty || status == 204 ? nil : data
        case 401 where !retried:
            try await auth.refresh()
            return try await request(method, path, retried: true)
        default:
            throw SpotifyError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
    }
}

enum PlayerCommand { case play, pause, next, previous, seek(ms: Int) }

/// Fallback for when the Web API refuses playback control (free accounts get
/// 403, and 404 means no active device): drive the local Spotify app instead.
enum SpotifyAppleScript {
    static func run(_ cmd: PlayerCommand) {
        let verb: String
        switch cmd {
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        case .seek(let ms): verb = "set player position to \(Double(ms) / 1000)"
        }
        let source = "if application \"Spotify\" is running then tell application \"Spotify\" to \(verb)"
        DispatchQueue.global(qos: .userInitiated).async {
            var err: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&err)
        }
    }
}
