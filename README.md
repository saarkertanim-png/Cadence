# Cadence — Deep, Blue and Mist
By TanimSarker. A native, installable music player for Android and iOS, built with Flutter (not a web app).

## Features
- Finds music on your device automatically (Android) and keeps the library cached. Add files yourself on both platforms.
- Album art extracted from file tags, shown in lists, the mini player and a blurred Now Playing background.
- Real playback with background audio, notification and lock-screen controls, gapless queue, shuffle and repeat.
- Animated wavy seek bar at the bottom of Now Playing, smooth transitions, 7 themes.
- Equalizer, loudness boost (Android), sleep timer with fade-out, playback speed, favorites, search, sorting.
- Audio info read from the file itself (FLAC and WAV sample rate, bit depth, channels). Unknown stays "Unknown".

- Resumes exactly where you left off (queue, song, position).
- Playlists: create, rename, reorder, delete; long-press a song for Play next, Add to queue, Add to playlist.
- Garden: every song grows its own generated flower the more you listen; the big Now Playing card shows it (tap to flip with album art).

## Build
Push to `main` (or run **Actions > Build Cadence > Run workflow**). Download from the run's Artifacts:
- `Cadence-android-apk`: release-mode APK, installable on any Android phone.
- `Cadence-ios-unsigned-ipa`: iOS needs signing. Install it with Sideloadly or AltStore using your Apple ID.

## Limits
- Not yet run by the author; the first build may need small fixes.
- The APK uses a test signing key. Play Store release needs your own keystore.
- iOS cannot scan storage; equalizer and loudness boost are Android-only.
- iOS install needs signing, so it cannot be installed straight from GitHub.
