<p align="center">
  <img src=".github/icon.png" width="128" height="128" alt="Funki app icon">
</p>

<h1 align="center">Funki</h1>

<p align="center">
  A tiny macOS menu bar app that shows whether you are online.
</p>

<p align="center">
  <a href="https://github.com/danielstgt/funki/releases/latest"><b>Download</b></a>
  &nbsp;·&nbsp;
  <a href="#install">Install</a>
  &nbsp;·&nbsp;
  <a href="#build-from-source">Build from source</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/danielstgt/funki/issues">Report a bug</a>
</p>

<br>

Funki checks whether the internet is actually reachable, not just whether Wi-Fi
is connected, and shows the answer in the menu bar.

| Menu bar icon | Status |
| --- | --- |
| Antenna | Online |
| Red, crossed-out antenna | Offline |
| Dimmed antenna | Paused |

The menu shows the latency of the last 60 checks as a small graph, and lets you
pause the checks or launch Funki at login.

- **Fast.** A network change triggers a check right away, and a restored
  connection shows up within seconds.
- **Light.** One small request every 30 seconds while online, none at all
  without a network. About 13 MB of memory.
- **Private.** No analytics, no update check, no permissions, nothing stored
  apart from your settings. Funki only talks to `captive.apple.com`, the server
  macOS uses for the same check, or to a server you choose.

## Install

Requires macOS 14 or later, on Apple silicon or Intel.

1. Download `Funki-<version>.zip` from the
   [latest release](https://github.com/danielstgt/funki/releases/latest), unzip
   it and move `Funki.app` to Applications.
2. Funki is not notarized, so macOS blocks the first launch. Open
   **System Settings › Privacy & Security** and click **Open Anyway**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Funki.app
   ```

## Settings

Under *Settings…* in the menu you can change the server, the check interval
while online (30 seconds) and the retry interval while offline (1 second).
A custom server can be any `http` or `https` URL. Prefer `https`: over plain
`http`, a captive portal could pass for being online.

## Build from source

Requires Swift 6 or later.

```sh
git clone https://github.com/danielstgt/funki.git
cd funki
make install
```

`make run` builds and launches Funki, `make zip` creates a release archive.

## License

[MIT](LICENSE)
