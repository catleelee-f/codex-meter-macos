# Changelog

## 1.3.0 - 2026-09-16

- 新增 GitHub Actions，自动运行离线回归测试、Universal 构建、签名和压缩包检查。
- 新增合成日志测试，覆盖缓存、增量读取、截断、计数重置和汇总一致性。
- 完善中文贡献指南、隐私要求、发布流程和路线图。
- 本版重点是可验证的维护基础，保留现有应用功能。

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
