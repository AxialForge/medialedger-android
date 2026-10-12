# Changelog

## 0.3.1
- Fixes sign-in failing with "HTTP 308" when the address redirects (for example http to https). Redirects are followed and the new address is remembered.

## 0.3.0
- Native app: sign-in with two-factor, bottom navigation, and a native Home with counts, Continue watching and Next up, in the server's colors.
- Every other server page opens inside the app as a web page (sidebar hidden) until it gets a native screen.
- More tab: all pages, check for updates, sign out (also how to change server addresses).

## 0.2.3
- Menu button (bottom right): check for updates, reload, change server addresses.

## 0.2.2
- New MediaLedger logo: launcher icon and setup screen.

## 0.2.1
- Fixes a blank screen when the server redirects (for example http to https, or to another port).

## 0.2.0
- Shows the server's own web UI full screen, so the app matches the server.
- Home address first, then an optional Tailscale address; the first one that answers is used.
- Fixes the sidebar not opening on phones (a later CSS rule overrode the drawer's fixed position).
- Built-in updater: checks GitHub Releases on launch and installs a newer MediaLedger.apk after confirmation.
