# Repository Guidelines

## Project Structure & Module Organization

`app/` contains the native macOS AppKit product. `app/Package.swift` defines the Swift Package; `app/ContainerGUI/App/` handles lifecycle and window construction, `Core/` contains CLI execution, Codable models, typed commands, and polling state, and `UI/` contains pages, sheets, inspectors, reusable components, theming, and localization support. Localized strings live in `app/ContainerGUI/Resources/`. `app/ExceptionCatcher/` bridges Objective-C exception handling. `design/` is the browser-only visual prototype and is not production code; keep prototype HTML, scripts, and styles in `design/assets/`.

## Build, Test, and Development Commands

Run commands from `app/`:

- `swift build` — compile the debug executable and surface Swift diagnostics.
- `./Scripts/build.sh` — build a release executable and assemble `app/build/Container.app`.
- `./Scripts/dev.sh` — build the app bundle and launch it.
- `swift test` — run package tests; no test target currently exists.

Development requires macOS 15+ and the Apple `container` CLI.

## Coding Style & Naming Conventions

Use 4-space indentation in Swift and Objective-C. Follow Swift API conventions: `PascalCase` for types and `camelCase` for members. Keep CLI decoding models `Codable`, place new commands in `Core/Commands.swift`, route shared observable state through `Store`, and use `L("key")` for user-facing strings. Keep page, sheet, inspector, and component code in its designated `UI/` directory. No formatter or linter is configured; avoid bulk formatting so review diffs remain focused.

## Testing Guidelines

There is no automated test suite yet. At minimum, run `swift build` for every change and smoke-test affected screens with the real `container` CLI. When adding tests, use Swift Testing or XCTest, name files `*Tests.swift`, methods `test...`, and run `swift test --filter <TestName>`.

## Commit & Pull Request Guidelines

This repository has no commit history yet. Use short, imperative subjects (for example, `Add volume deletion confirmation`) and explain non-obvious implementation details in the body. PRs should state the user-facing change, testing performed, screenshots or screen recordings for UI work, and linked issues where applicable.

## Security & Configuration Tips

Do not commit `.env` files or CLI credentials. Destructive container operations must require explicit confirmation, and production behavior should use the real CLI rather than mocked data.
