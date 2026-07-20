# Changelog

## 1.2.0 - 2026-07-20

- Add daily, weekly, and cumulative views for the 90-day local usage history.
- Show immediate token details when hovering usage cells or bars.
- Add a resizable detailed-statistics window with 7/30/90-day project rankings.
- Group local sessions by their recorded working directory without reading conversation content.
- Show per-project totals, shares, active days, and most recent activity.
- Keep the existing Open Codex action alongside Details, Settings, and Quit.
- Upgrade the scanner cache schema so existing installations rebuild project metadata once.

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
