# Changelog

## 1.1.0 - 2026-07-16

- Sync account-wide quota through Codex App Server, including usage from other Codex clients.
- Keep local sessions as the source for token totals and the 90-day heatmap.
- Fall back safely to the latest local rate-limit snapshot when account sync is unavailable.
- Label quota data as account live, account cache, or local fallback.
- Discover Codex from Desktop bundles, common install paths, PATH, NVM, and FNM.
- Add offline response parsing and an optional live account-sync probe.

## 1.0.0 - 2026-07-15

- Initial public release.
- Native macOS menu bar dashboard.
- Local token activity and dynamic Codex rate-limit windows.
- High-contrast 90-day usage heatmap.
- Incremental cache and configurable refresh interval.
- Universal Apple Silicon and Intel build.
