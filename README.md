# Codex Meter for macOS

![Codex Meter screenshot](docs/screenshot.png)

A privacy-first macOS menu bar app for viewing local Codex token activity and the latest rate-limit snapshot written by Codex.

一个原生 macOS 菜单栏小工具，用于查看本机 Codex Token 活动、额度窗口和近 90 天热力图。

> Unofficial community project. Not affiliated with or endorsed by OpenAI.

## Features

- Native AppKit status item with a SwiftUI dashboard
- Remaining percentage for the longest available Codex usage window
- Today's input, cached-input, and output token activity
- Dynamic support for one or multiple rate-limit windows
- 90-day high-contrast usage heatmap
- Incremental local cache for fast refreshes
- Custom sessions directory and 1/5/15-minute refresh intervals
- Universal binary for Apple Silicon and Intel Macs
- No analytics, no account token access, and no data uploads

## Data and privacy

Codex Meter reads only local JSONL files under:

```text
~/.codex/sessions
```

- Token counts are local estimates derived from `total_token_usage` events. They are not billing records.
- Rate-limit percentages and reset times come from the latest local `rate_limits` snapshot.
- The app does not read `auth.json` and does not send data over the network.
- Codex session-log fields are not a public stable API and may change in future Codex versions.

## Install

1. Download `CodexMeter-macOS-universal.zip` from [Releases](../../releases/latest).
2. Unzip it and move `CodexMeter.app` to `/Applications`.
3. Launch the app. If Gatekeeper blocks this locally signed build, right-click it in Finder and choose **Open**.
4. The status item shows an icon and the remaining percentage for the longest available window.

Hold `Command` and drag the status item to reposition it.

## Build from source

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools

```bash
git clone https://github.com/catleelee-f/codex-meter-macos.git
cd codex-meter-macos
./scripts/build.sh
```

Artifacts are written to:

```text
outputs/CodexMeter.app
outputs/CodexMeter-macOS-universal.zip
```

To run the parser smoke test against your own local Codex sessions:

```bash
./scripts/test-parser.sh
```

## Architecture

- `source/CodexLogScanner.swift` — incremental JSONL scanner and cache
- `source/UsageStore.swift` — refresh scheduling and preferences
- `source/DashboardViews.swift` — dashboard, heatmap, and settings UI
- `source/AppDelegate.swift` — status item, popover, and app lifecycle
- `scripts/build.sh` — universal build, ad-hoc signing, and ZIP packaging

## Security

Please report vulnerabilities through GitHub's private vulnerability reporting when available. See [SECURITY.md](SECURITY.md).

## License

MIT License. See [LICENSE](LICENSE).
