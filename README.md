# Funki

A tiny macOS menu bar app that shows whether you are online.

Funki does one thing: it checks whether the internet is actually reachable, not
just whether Wi-Fi is connected, and shows the answer in the menu bar. It is
written in Swift with AppKit, has no third-party dependencies and is built to
run for weeks without you noticing it.

## What it does

| Menu bar icon | Meaning | What Funki is doing |
| --- | --- | --- |
| Antenna | Online | One small request every 30 seconds |
| Red, crossed-out antenna | Offline, but a network is connected | Retries every second until the internet is back |
| Red, crossed-out antenna | Offline, no network at all | Nothing. macOS tells Funki when a network appears |
| Dimmed antenna | Paused | Nothing |

The menu shows the current status and the reason when you are offline, and lets
you pause the checks, open the settings and start Funki at login. Opening the
menu triggers a fresh check.

*Launch at Login* registers Funki as a login item through `SMAppService`, the
standard macOS mechanism. If macOS wants your approval first, Funki opens the
Login Items settings and shows a dash instead of a checkmark until you allow it.

## How it works

**Network changes are events, not polling.** Funki listens to `NWPathMonitor`.
Joining a Wi-Fi network, plugging in a cable or connecting a VPN triggers a
check immediately. Losing the last network sets the status to offline without a
single request.

**A probe confirms real connectivity.** A connected network does not mean the
internet works, so Funki requests `http://captive.apple.com`, the server macOS
uses for the same purpose, and expects Apple's `Success` page. Redirects are not
followed, so a captive portal that answers in Apple's place counts as offline.

**Getting back online is detected fast.** While the connection is down, Funki
probes back to back: one second after a probe that failed quickly, and right
away after one that ran into its three second timeout. Every probe is a fresh
attempt, so a recovered connection is noticed within about a second when probes
fail quickly, and within three seconds when they time out.

**Going offline needs a second opinion.** A single failed probe is retried
before the status changes, so one lost request does not make the icon flicker.

**Nothing accumulates.** There is one `URLSession` without cache, cookies or
credential storage, one probe at a time, and no history. Only the response
headers are read, plus Apple's 69 byte body. While online the timer has a
tolerance of a sixth of the interval so macOS can batch the wakeup with others.
Memory use stays at about 13 MB, whether Funki has been idling online or
retrying every second.

## Install

Funki runs on macOS 14 or later, on Apple silicon and Intel.

**Download:** grab `Funki-<version>.zip` from the
[latest release](https://github.com/danielstgt/funki/releases/latest), unzip it
and move `Funki.app` to your Applications folder.

The releases are ad-hoc signed, not notarized. On first launch macOS refuses to
open the app. Open **System Settings › Privacy & Security**, scroll down to
*Security*, click **Open Anyway** next to the Funki notice and confirm.
Alternatively, clear the quarantine flag in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/Funki.app
```

**Or build it yourself** with `make install`, see [Build](#build).

## Settings

Choose *Settings…* in the menu.

| Setting | Default | Notes |
| --- | --- | --- |
| Server | `http://captive.apple.com` | Leave empty for the default |
| Check every … seconds while online | 30 | At least 5 |
| Retry every … seconds while offline | 1 | At least 1 |

*Reset to Defaults* fills in the defaults for all three. Like every other
change, it takes effect when you save.

A custom server can be any `http` or `https` URL. A bare host name is treated
as `https`.

- A `2xx` response counts as online. Over `https` a redirect does too, because
  the server has proven its identity. Over plain `http` a redirect counts as
  offline, since that is how captive portals intercept requests.
- Prefer `https` or an endpoint made for this purpose. Funki cannot verify the
  body of a custom address, so a captive portal that answers a plain `http`
  request with `200` would look like being online.

## Build

Funki targets macOS 14 or later and is developed and tested on macOS 27 with
Xcode 27. Building it takes Swift 6 or later.

```sh
git clone https://github.com/danielstgt/funki.git
cd funki
make install
```

| Command | What it does |
| --- | --- |
| `make` | Builds `build/Funki.app`, universal and ad-hoc signed |
| `make run` | Builds and launches it |
| `make install` | Builds and copies it to `/Applications` |
| `make zip` | Builds `build/Funki-<version>.zip` for a release |
| `make clean` | Removes the build output |

Everything is plain Swift Package Manager. The Makefile only assembles the
`.app` bundle, draws the icon with `Scripts/generate-icon.swift` and signs it.
Pass `SIGN_IDENTITY="Developer ID Application: …"` to sign with your own
certificate.

You can also open `Package.swift` in Xcode. Running it from there starts the
executable without its bundle, which is fine for debugging, but *Launch at
Login* only works in the bundled app.

## Privacy

Funki sends a plain `GET` request to the configured server and nothing else. It
asks for no permissions and is signed without entitlements. There is no
analytics, no update check and no data stored apart from your settings.

Status changes are written to the system log, which helps when something looks
wrong:

```sh
log stream --level info --predicate 'subsystem == "io.github.danielstgt.funki"'
```

## License

[MIT](LICENSE)
