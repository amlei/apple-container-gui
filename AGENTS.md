# Repository Guidelines

Container GUI is a native macOS desktop client for Apple's `container` CLI, built with AppKit and SwiftUI. Read this file before contributing.

## Project Structure & Module Organization

Production code lives in `app/` (Swift Package Manager):

- `app/ContainerGUI/App/` — app lifecycle (`main`, `AppDelegate`, main window).
- `app/ContainerGUI/Core/` — `CLIRunner` (subprocess wrapper), `Models` (Codable CLI output), `Commands` (typed CLI commands), and `Store` (shared observable state with 5s polling + `NotificationCenter`).
- `app/ContainerGUI/UI/` — `Pages` (overview, containers, images, volumes, networks, machines, k8s, settings), `Sheets`, `Inspector`, `Components`, and `Support` (theme, `L()` localization, formatting).
- `app/ContainerGUI/Resources/` — localized strings in `en.lproj` and `zh-Hans.lproj`.
- `app/ExceptionCatcher/` — Objective-C bridge that surfaces exceptions AppKit would otherwise swallow.
- `app/Scripts/` — `build.sh` (release build + app bundle + ad-hoc codesign) and `dev.sh` (build + launch).
- `design/` — browser-only visual prototype; not production code. Prototype UI/UX changes there and confirm before implementing in `app/`.

## Build, Test, and Development Commands

Run from `app/`. Requires macOS 15+ and the `container` CLI (auto-detected at `/usr/local/bin/container`).

- `swift build` — compile the debug executable and surface diagnostics.
- `./Scripts/build.sh` — release build and assemble `app/build/Container.app`.
- `./Scripts/dev.sh` — build, then launch the app bundle.
- `swift test` — run package tests (no test target exists yet).

## Coding Style & Naming Conventions

- 4-space indentation in Swift and Objective-C. No formatter or linter is configured; don't bulk-format, so review diffs stay focused.
- Swift API conventions: `PascalCase` types, `camelCase` members and enum cases (e.g., `Route.overview`).
- CLI JSON models are `Codable`; add new commands to `Core/Commands.swift`; route shared state through `Store`.
- Never hard-code user-facing strings: use `L("key")` and add the key to both `Localizable.strings` files.
- Keep pages, sheets, inspectors, and components in their designated `UI/` subfolder.

## Testing Guidelines

No automated test suite exists yet. At minimum run `swift build` for every change and smoke-test affected screens against the real CLI. When adding tests, use Swift Testing or XCTest, name files `*Tests.swift` and methods `test...`, then run `swift test --filter <TestName>`.

## Commit & Pull Request Guidelines

Use short, imperative subjects (e.g., `Add volume deletion confirmation`) and explain non-obvious implementation details in the body. PRs must state the user-facing change, testing performed, screenshots or screen recordings for UI work, and any linked issues.

## Security & Configuration Tips

Never commit `.env` files or CLI credentials. Destructive operations (delete, purge) require explicit confirmation; production behavior must use the real CLI, not mocked data.
