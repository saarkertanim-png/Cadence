# Cadence — Deep, Blue and Mist
By TanimSarker. A local music player (web app wrapped as an Android app with Capacitor).

## Get the APK
1. Create a new GitHub repository and upload everything in this folder (keep the `.github` folder).
2. Open the **Actions** tab, choose **Build Cadence APK**, click **Run workflow** (it also runs on every push to `main`).
3. When it finishes, open the run and download **Cadence-debug-apk** from Artifacts. Unzip it and install `app-debug.apk` on your phone (allow "install unknown apps").

## Edit the app
The whole app is `www/index.html`. Change it, commit, and the workflow builds a new APK.

## Limits
- Debug-signed APK, fine for personal use, not for Play Store. Release signing needs a keystore stored in GitHub Secrets.
- Playback runs in Android WebView: no reliable background playback or lock-screen controls, no bit-perfect output, and codecs depend on the device.
- This build setup has not been run by the author; if the workflow fails, open the failed step's log.
