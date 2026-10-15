# Spooterfy

A small macOS window that shows what Spotify is playing: big album artwork with the title and artist over it, the previous song in small type above, and what's up next below. It resizes to any size; in wide windows the list moves beside the artwork.

## Setup (once)

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create an app.
2. Tick **Web API**, and add this Redirect URI: `spooterfy://callback`
3. Copy the app's **Client ID**.
4. In Spooterfy, open **Settings** (⌘,), paste the Client ID, and click **Connect to Spotify**.

Spooterfy uses PKCE, so it needs no client secret. Sign-in tokens are stored in `~/Library/Application Support/Spooterfy/tokens.json`, readable only by your user account.

## Controls

- **Media keys** (play/pause, next, previous) control Spotify while Spooterfy is the focused app.
- **Space**, **⌘→** / **⌘←**, or hover over the artwork for buttons.
- With Spotify Premium, controls go through the Web API. Without it, or if no device is active, Spooterfy controls the Spotify app directly (macOS asks once for permission).
- **Settings → Keep window on top** pins the window above other apps and on every Space.

## Build

Requires Xcode 16+ / Swift 6 on macOS 14+.

```bash
./build.sh            # builds build/Spooterfy.app
./build.sh --install  # also copies it to /Applications
```
