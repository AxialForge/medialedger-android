# MediaLedger Android — project notes for Claude

Flutter app that wraps the MediaLedger server's web UI (`src/renderer` in AxialForge/medialedger) in a WebView.
The server is the only source of data and UI; the app only stores server addresses and does self-updates.

## Non-negotiables
- Direction (decided 2026-10-11): grow into a fully native app, built on a hybrid base. Pages without a native screen open the server's web page inside the app (`lib/screens/web_page.dart`, sidebar and top bar hidden), so the app is never worse than the web UI. Each release replaces more pages.
- No paid services, no Play Store, no paid certificates. Sideloaded APK updated from GitHub Releases.
- Commits are authored by AxialForge, no Claude attribution (global rules apply).

## Commands
```bash
flutter analyze
flutter build apk --release                 # universal APK (what the updater downloads)
flutter build apk --release --split-per-abi # smaller per-ABI files for sending to a phone
```
Release: bump `pubspec.yaml` + `CHANGELOG.md`, `git tag vX.Y.Z && git push origin main --tags`; CI attaches `MediaLedger.apk`.

## Layout
`lib/api.dart` channel client (cookie session, address failover, trusts the saved hosts' certs) · `lib/theme.dart` server palette · `lib/screens/` login, shell (tabs), home, more (page lists), web_page, common (Loader, Poster) · `lib/updater.dart` GitHub Releases updater.

## Gotchas
- **Gradle fails with "Unable to establish loopback connection" in the sandboxed shell.** Run builds in the user's
  terminal panel (`run_in_terminal`), not Bash/PowerShell tools.
- **Terminal `cwd` must be inside the session folders**; use `cd '...'; flutter ...` in the command instead.
- **NDK/CMake are auto-installed by Gradle** into `C:\Android\sdk`; `sdkmanager` needs `'"ndk;28.2.13676358"'` quoting.
- **Version codes:** `--split-per-abi` adds 1000/2000/4000 to the build number. The `+10000` build number (now `+20000`) keeps the
  universal APK above any split build, otherwise installing it is a "downgrade".
- **Signing key = the local debug keystore** (`~/.android/debug.keystore`), mirrored in the `DEBUG_KEYSTORE_B64` secret.
  A different key makes updates fail with a signature mismatch; users would have to uninstall first.
- **ota_update needs core library desugaring** (`isCoreLibraryDesugaringEnabled` in `android/app/build.gradle.kts`).
- **flutter_inappwebview 1.1.3 breaks the build** with the current AGP (proguard-android.txt); use `webview_flutter`.
- **Server sidebar bug:** `.sidebar { position: relative }` after the mobile media query hid the phone drawer. Fixed in
  the server CSS (post-2.6.0) and worked around in the app via an injected style on page finish.
- **Emulator:** AVD `Pixel_10_Pro_XL_test`; `adb` in `C:\Android\sdk\platform-tools`. Enable WebView debugging
  (`AndroidWebViewController.enableDebugging(true)`) temporarily and use `adb forward` + CDP to inspect the page.
