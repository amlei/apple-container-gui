# Container GUI

A native macOS desktop client for Apple's [`container`](https://github.com/apple/container) CLI, built with AppKit and SwiftUI.

The app lets you manage containers, images, volumes, networks, machines, and Kubernetes clusters directly from a native window: run/pull/build images, inspect and stream container logs, watch live CPU/memory/network metrics, open a terminal, and manage local resources — all backed by the real `container` CLI (no mock data).

The `design/` folder is the browser-based visual prototype (HTML/JS/CSS) used as the design reference; `app/` is the production macOS application.

## Requirements

- macOS 15 or later
- Apple `container` CLI (auto-detected at `/usr/local/bin/container`, `/opt/homebrew/bin/container`, or `/usr/bin/container`)

## Build & Run

From `app/`:

```bash
./Scripts/dev.sh      # debug build + launch
# or
./Scripts/build.sh    # release build -> app/build/Container.app
open build/Container.app
```

## Features

- **Overview** — running counts, disk-usage bars (with reclaimable stripes), system service status & versions
- **Containers** — filter/search, start/stop/kill/delete, detail drawer with info · logs (follow/boot/tail) · monitoring charts · PTY terminal
- **Images** — pull, build, tag, push, save/load tar, layer history
- **Volumes** — create (size/journal mode), delete
- **Networks** — create (v4/v6/internal), delete, macOS 26 note
- **Machines** — create/configure/start/stop/set-default, shell & logs drawers
- **Kubernetes** — create clusters, load images, write kubeconfig (experimental)
- **Settings** — theme (auto/light/dark), language, service controls, kernel, DNS, registry logins, keyboard-shortcut rebinding
- Full localization (简体中文 / English) and light/dark appearance

## Project Structure

```
apple-container-gui/
├── app/                       # Production macOS app (Swift Package)
│   ├── Package.swift
│   ├── ContainerGUI/
│   │   ├── App/               # lifecycle, menus, main window, sidebar
│   │   ├── Core/              # CLIRunner, Models, Commands, Store, Keymap
│   │   ├── UI/                # Pages, Sheets, Inspector, Components, Support
│   │   └── Resources/         # en / zh-Hans localizations
│   ├── ExceptionCatcher/      # Objective-C exception bridge
│   └── Scripts/               # build.sh / dev.sh
├── design/                    # Browser visual prototype (design reference)
└── assets/                    # Project assets (logo)
```

## Development

- Run `swift build` from `app/` for every change and smoke-test affected screens against the real CLI.
- No automated test target exists yet; when adding one, use Swift Testing/XCTest and run `swift test --filter <TestName>`.
- User-facing strings use `L("key")` and must be added to both `en.lproj` and `zh-Hans.lproj` `Localizable.strings`.
- Page UI mirrors `design/`; keep new view code in its designated `UI/` subfolder.

## License

MIT
