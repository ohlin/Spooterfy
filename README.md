# Spooterfy

> Spooterfy is just a lil' guy, you know? He likes album art and readable text, and if you do too, you just might get along. He survives on a steady diet of Apple chips and hand-crafted playlists.

A small, resizable macOS window that shows what's playing on Spotify.

- **Now playing:** the album artwork, big, with the song title and artist over it.
- **Previously played:** one small line above the artwork.
- **Up next:** your queue, below the artwork (or beside it in a wide window).
- **Liquid Glass:** the window is clear glass over your desktop, tinted with the album's colours, and looks the same focused or not.

Everything scales with the window, from a 140-point square up to full screen.

## Setup (once)

Spotify needs a "Client ID" to let an app read what you're playing. It's free:

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create an app.
2. Tick **Web API**, and add this Redirect URI: `spooterfy://callback`
3. Copy the app's **Client ID**.
4. In Spooterfy, open **Settings** (⌘,), paste the Client ID, and click **Connect to Spotify**.

You stay signed in after that.

## Using it

| Action | How |
| --- | --- |
| Play / pause | Media key, **Space**, or hover over the artwork |
| Next / previous song | Media keys, **⌘→** / **⌘←**, or hover over the artwork |
| Jump within the song | Click or drag the progress bar under the artwork |
| Open the song in Spotify | **S** (the lil' guy throws the artwork into Spotify) |
| Open the playlist in Spotify | **P** (if it's playing from a playlist; otherwise he shakes his head) |
| Big Boy Spooterfy Mode™ | **F** fills the screen (menu bar and Dock stay) with the biggest text; **F** or **Esc** puts it back |
| Close / minimise / full screen | **⌘W** / **⌘M** / **⌃⌘F** (the window has no title-bar buttons) |
| Move the window | Drag it from anywhere |

The media keys control Spotify while Spooterfy is the focused app.

With Spotify Premium, playback controls go through Spotify's Web API. Without Premium, or when no Spotify device is active, Spooterfy controls the Spotify app on your Mac directly. macOS asks once for permission.

## Settings

- **Glass when focused / in background:** Clear (Liquid Glass), Tinted (frosted) or Transparent (no glass). By default both are Clear, and the glass looks the same whether or not the window is focused.
- **Darkness:** darkens the glass so text stays readable over a bright desktop.
- **Tint glass with album colors:** washes the glass with the current album's colours.
- **Color text with album colors:** tints the song titles, artists and list with colours picked from the artwork, kept light enough to read. Off by default.
- **Text size:** ⌘+ and ⌘- step text from 80% to 175%; ⌘0 resets it.
- **Keep window on top:** keeps Spooterfy above other apps, including full-screen ones, on every desktop.
- **Show playback controls on hover**

## Privacy

Spooterfy talks only to Spotify. It signs in with PKCE, so it needs no client secret. Your Client ID is stored in the app's preferences. Your sign-in tokens are stored in `~/Library/Application Support/Spooterfy/tokens.json`, readable only by your user account. Neither is in this repository.

## Building

Requires macOS 26 or later and Xcode 26 or later (for Liquid Glass). Builds are for Apple silicon only.

```bash
./build.sh            # builds build/Spooterfy.app
./build.sh --install  # also copies it to /Applications
./build.sh --dmg      # also makes build/Spooterfy-<version>.dmg for a release
```

The app is ad-hoc signed. If you copy it to another Mac, right-click it and choose **Open** the first time.

For layout work, a debug build can render the main window at several sizes with sample data:

```bash
swift build && SPOOTERFY_SNAPSHOTS=/tmp/snaps .build/debug/Spooterfy
```

### Project layout

| File | What it does |
| --- | --- |
| `SpooterfyApp.swift` | App, window setup, Playback menu |
| `SpotifyAuth.swift` | Sign-in (Authorization Code + PKCE) and token storage |
| `SpotifyAPI.swift` | Web API calls, plus the AppleScript fallback |
| `PlayerStore.swift` | Polls Spotify and holds what the window shows |
| `NowPlayingView.swift` | The main window's layout |
| `SettingsView.swift` | Settings window |
| `MediaKeys.swift` | Routes the keyboard's media keys to Spotify while focused |
| `WindowGlass.swift` | Liquid Glass background and its settings |
| `AccentColor.swift` | Picks the progress bar colour from the album art |
| `AlbumTextColors.swift` | Picks text colours from the album art (Material Color Utilities) |
| `TextScale.swift` | Text size steps for ⌘+ / ⌘- |
| `BigMode.swift` | Big Boy Spooterfy Mode™ |
| `LilGuy.swift` | The lil' green guy and his artwork throw (S and P) |
| `Typography.swift` | Bundled Atkinson Hyperlegible fonts |
| `Resources/spooterfy.icon` | App icon, made in Icon Composer; `build.sh` compiles it with `actool` |

## Contributing

Spooterfy is a personal project, but forks and contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), and report security problems privately as described in [SECURITY.md](SECURITY.md).

## License

The code is MIT licensed; see [LICENSE](LICENSE). The bundled Atkinson Hyperlegible fonts belong to the Braille Institute; see [Resources/Fonts/README.md](Resources/Fonts/README.md). `Packages/MaterialColorUtilities` is a vendored subset of Google's Material Color Utilities under the Apache License 2.0; see [its README](Packages/MaterialColorUtilities/README.md).

Spooterfy isn't affiliated with or endorsed by Spotify.
