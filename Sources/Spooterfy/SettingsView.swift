import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: SpotifyAuth
    @AppStorage("clientID") private var clientID = ""
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @AppStorage("showControlsOnHover") private var showControls = true
    @AppStorage("glassFocused") private var focusedStyle = GlassDefaults.focused
    @AppStorage("glassBackground") private var backgroundStyle = GlassDefaults.background
    @AppStorage("glassDarkness") private var darkness = GlassDefaults.darkness
    @AppStorage("albumGlow") private var albumGlow = GlassDefaults.albumGlow
    @AppStorage(TextScale.key) private var textScale = TextScale.standard
    @AppStorage("albumTextColors") private var albumTextColors = false

    var body: some View {
        Form {
            Section {
                TextField("Client ID", text: $clientID, prompt: Text("Paste your Spotify Client ID"))
                    .font(.atkinsonMono(.body))
                    .disabled(auth.isSignedIn)

                HStack {
                    if auth.isSignedIn {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") { auth.signOut() }
                    } else {
                        Label("Not connected", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Connect to Spotify") { auth.signIn() }
                            .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                if let error = auth.lastError {
                    Text(error).font(.atkinson(.callout)).foregroundStyle(.orange)
                }
            } header: {
                Text("Spotify")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Get a Client ID: open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard), create an app, tick **Web API**, and add this Redirect URI:")
                    HStack(spacing: 6) {
                        Text(SpotifyAuth.redirectURI)
                            .font(.atkinsonMono(.callout))
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SpotifyAuth.redirectURI, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy Redirect URI")
                    }
                    Text("Play/pause and skipping use the Web API with Spotify Premium, and fall back to controlling the Spotify app otherwise.")
                }
                .font(.atkinson(.callout))
                .foregroundStyle(.secondary)
            }

            Section {
                Picker("Glass when focused", selection: $focusedStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Glass in background", selection: $backgroundStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Darkness") {
                    HStack {
                        Image(systemName: "sun.max").foregroundStyle(.secondary)
                        Slider(value: $darkness, in: 0...0.9)
                        Image(systemName: "moon.fill").foregroundStyle(.secondary)
                    }
                }
                Toggle("Tint glass with album colors", isOn: $albumGlow)
                Toggle("Color text with album colors", isOn: $albumTextColors)
                if focusedStyle != GlassDefaults.focused || backgroundStyle != GlassDefaults.background || darkness != GlassDefaults.darkness || albumGlow != GlassDefaults.albumGlow {
                    Button("Reset to Defaults") {
                        focusedStyle = GlassDefaults.focused
                        backgroundStyle = GlassDefaults.background
                        darkness = GlassDefaults.darkness
                        albumGlow = GlassDefaults.albumGlow
                    }
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Tinted glass is frosted and easiest to read. Clear is lighter glass that still blurs. Transparent shows the desktop unblurred. By default both are Clear, and the glass looks the same whether or not the window is focused. Raise Darkness if text is hard to read over a bright desktop.")
                    .font(.atkinson(.callout))
                    .foregroundStyle(.secondary)
            }

            Section("Window") {
                LabeledContent("Text size") {
                    HStack(spacing: 10) {
                        Button { textScale = TextScale.smaller(than: textScale) } label: {
                            Image(systemName: "textformat.size.smaller")
                        }
                        .disabled(textScale <= TextScale.steps.first!)
                        .help("Make Text Smaller (⌘-)")
                        Text(TextScale.label(textScale))
                            .monospacedDigit()
                            .frame(minWidth: 44)
                        Button { textScale = TextScale.bigger(than: textScale) } label: {
                            Image(systemName: "textformat.size.larger")
                        }
                        .disabled(textScale >= TextScale.steps.last!)
                        .help("Make Text Bigger (⌘+)")
                    }
                }
                Toggle("Keep window on top", isOn: $alwaysOnTop)
                Toggle("Show playback controls on hover", isOn: $showControls)
            }
        }
        .formStyle(.grouped)
        .font(.atkinson(.body))
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
