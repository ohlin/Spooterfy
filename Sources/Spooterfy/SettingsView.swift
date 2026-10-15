import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: SpotifyAuth
    @AppStorage("clientID") private var clientID = ""
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @AppStorage("showControlsOnHover") private var showControls = true

    var body: some View {
        Form {
            Section {
                TextField("Client ID", text: $clientID, prompt: Text("Paste your Spotify Client ID"))
                    .font(.system(.body, design: .monospaced))
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
                    Text(error).font(.callout).foregroundStyle(.orange)
                }
            } header: {
                Text("Spotify")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Get a Client ID: open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard), create an app, tick **Web API**, and add this Redirect URI:")
                    HStack(spacing: 6) {
                        Text(SpotifyAuth.redirectURI)
                            .font(.system(.callout, design: .monospaced))
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
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section("Window") {
                Toggle("Keep window on top", isOn: $alwaysOnTop)
                Toggle("Show playback controls on hover", isOn: $showControls)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
