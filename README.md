# MediaLedger Android

Android client for [MediaLedger](https://github.com/AxialForge/medialedger). The server holds all the data; this app
shows the server's own web UI in a full-screen WebView, so it always matches the server.

## Use

1. Install `MediaLedger.apk` from the latest [release](../../releases/latest) (allow "install unknown apps").
2. First launch: enter the home address (for example `https://medialedger.home`) and, optionally, a Tailscale address.
3. Sign in with your MediaLedger account.

The app checks this repo's releases on launch and offers to update itself.

## Build

```bash
flutter pub get
flutter build apk --release
```

## Release

1. Bump `version:` in `pubspec.yaml` (keep the `+10000` build number or higher) and add a `CHANGELOG.md` section.
2. Commit, then `git tag vX.Y.Z && git push origin main --tags`.
3. CI builds the APK and attaches it as `MediaLedger.apk`.

CI signs with the same key as local builds (secret `DEBUG_KEYSTORE_B64`), so updates install over existing copies.
