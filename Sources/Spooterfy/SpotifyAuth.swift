import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

/// Sign-in with Spotify using Authorization Code + PKCE. Only a Client ID is
/// needed (no client secret), so it is safe to ship in a desktop app.
@MainActor
final class SpotifyAuth: NSObject, ObservableObject {
    static let redirectURI = "spooterfy://callback"
    static let scopes = [
        "user-read-currently-playing",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-recently-played",
    ]

    @Published private(set) var isSignedIn = false
    @Published var lastError: String?

    private var tokens: Tokens?
    private var webSession: ASWebAuthenticationSession?
    private var refreshTask: Task<String, Error>?

    var clientID: String {
        UserDefaults.standard.string(forKey: "clientID")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    override init() {
        super.init()
        tokens = TokenStore.load()
        isSignedIn = tokens != nil
    }

    // MARK: Sign in / out

    func signIn() {
        lastError = nil
        guard !clientID.isEmpty else {
            lastError = "Enter your Spotify Client ID first."
            return
        }
        let verifier = Self.randomVerifier()
        let challenge = Self.challenge(for: verifier)
        let state = UUID().uuidString

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "state", value: state),
            .init(name: "scope", value: Self.scopes.joined(separator: " ")),
        ]

        let session = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: "spooterfy") { [weak self] url, error in
            Task { @MainActor in
                guard let self else { return }
                self.webSession = nil
                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        self.lastError = error.localizedDescription
                    }
                    return
                }
                guard let url,
                      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                else { return }
                if let err = items.first(where: { $0.name == "error" })?.value {
                    self.lastError = "Spotify said: \(err)"
                    return
                }
                guard items.first(where: { $0.name == "state" })?.value == state,
                      let code = items.first(where: { $0.name == "code" })?.value
                else {
                    self.lastError = "Sign-in response didn't match. Try again."
                    return
                }
                await self.exchange(code: code, verifier: verifier)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webSession = session
        session.start()
    }

    func signOut() {
        tokens = nil
        TokenStore.clear()
        isSignedIn = false
    }

    // MARK: Tokens

    /// A valid access token, refreshing it first if it is about to expire.
    func accessToken() async throws -> String {
        guard let tokens else { throw SpotifyError.notSignedIn }
        if tokens.expiresAt.timeIntervalSinceNow > 60 { return tokens.accessToken }
        return try await refresh()
    }

    /// Forces a refresh (used after a 401). Concurrent callers share one request.
    @discardableResult
    func refresh() async throws -> String {
        if let refreshTask { return try await refreshTask.value }
        let task = Task<String, Error> { [weak self] in
            guard let self, let current = self.tokens else { throw SpotifyError.notSignedIn }
            let new = try await self.tokenRequest([
                "grant_type": "refresh_token",
                "refresh_token": current.refreshToken,
                "client_id": self.clientID,
            ], fallbackRefreshToken: current.refreshToken)
            return new.accessToken
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch SpotifyError.http(let status, _) where status == 400 || status == 401 {
            // Refresh token revoked or Client ID changed: start over.
            signOut()
            lastError = "Spotify sign-in expired. Connect again in Settings."
            throw SpotifyError.notSignedIn
        }
    }

    private func exchange(code: String, verifier: String) async {
        do {
            try await tokenRequest([
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": Self.redirectURI,
                "client_id": clientID,
                "code_verifier": verifier,
            ], fallbackRefreshToken: nil)
        } catch {
            lastError = "Couldn't finish sign-in: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func tokenRequest(_ form: [String: String], fallbackRefreshToken: String?) async throws -> Tokens {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = body.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw SpotifyError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        struct Response: Decodable {
            let access_token: String
            let expires_in: Double
            let refresh_token: String?
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        guard let refreshToken = r.refresh_token ?? fallbackRefreshToken else {
            throw SpotifyError.http(status, "No refresh token returned")
        }
        let t = Tokens(accessToken: r.access_token,
                       refreshToken: refreshToken,
                       expiresAt: Date().addingTimeInterval(r.expires_in))
        tokens = t
        TokenStore.save(t)
        isSignedIn = true
        lastError = nil
        return t
    }

    // MARK: PKCE helpers

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64url(Data(bytes))
    }

    private static func challenge(for verifier: String) -> String {
        base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension SpotifyAuth: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? NSWindow()
        }
    }
}

struct Tokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

/// Tokens live in ~/Library/Application Support/Spooterfy/tokens.json with
/// owner-only permissions. (Keychain would re-prompt after every unsigned rebuild.)
enum TokenStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Spooterfy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        return dir.appendingPathComponent("tokens.json")
    }

    static func load() -> Tokens? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Tokens.self, from: data)
    }

    static func save(_ tokens: Tokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

enum SpotifyError: LocalizedError {
    case notSignedIn
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not connected to Spotify."
        case .http(let status, let body): return "Spotify returned \(status). \(body.prefix(200))"
        }
    }
}

#if DEBUG
extension SpotifyAuth {
    func pretendSignedIn() { isSignedIn = true }
}
#endif
