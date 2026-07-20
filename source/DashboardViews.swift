import AppKit
import SwiftUI

private enum MeterPalette {
    static let purple = Color(red: 0.43, green: 0.24, blue: 0.94)
    static let violet = Color(red: 0.64, green: 0.38, blue: 0.98)
    static let blue = Color(red: 0.22, green: 0.46, blue: 0.94)
    static let amber = Color(red: 0.94, green: 0.58, blue: 0.22)
}

struct DashboardView: View {
    @ObservedObject var store: UsageStore
    let onOpenCodex: () -> Void
    let onOpenDetails: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            dashboardHeader

            if let message = store.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }

            OverviewCard(snapshot: store.snapshot)
            RateLimitsCard(store: store)
            HeatmapCard(snapshot: store.snapshot)

            HStack(spacing: 9) {
                footerButton("打开 Codex", systemImage: "macwindow", action: onOpenCodex)
                footerButton("详细统计", systemImage: "chart.bar.xaxis", action: onOpenDetails)
                footerButton("设置", systemImage: "gearshape", action: onOpenSettings)
                footerButton("退出", systemImage: "power", action: onQuit)
            }
        }
        .padding(14)
        .frame(width: 446)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    MeterPalette.purple.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var dashboardHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [MeterPalette.violet, MeterPalette.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Meter")
                    .font(.system(size: 17, weight: .semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let reset = store.snapshot.primaryDisplayWindow?.resetsAt {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("下次重置")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(UsageFormatters.resetTime(reset))
                        .font(.caption.weight(.medium))
                }
            }

            Button(action: store.refresh) {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .help("刷新数据")
        }
    }

    private var headerSubtitle: String {
        if store.isRefreshing && store.snapshot.updatedAt == .distantPast {
            return "正在同步账号额度与本机 Token…"
        }

        switch store.accountQuotaState {
        case .waiting:
            return store.snapshot.updatedAt == .distantPast ? "尚未读取数据" : "等待账号额度同步"
        case .syncing:
            return "正在同步账号额度…"
        case .synced(let date):
            return "账号额度更新于 \(timeOnly(date))"
        case .fallback(let date, _):
            if let date {
                return "账号同步待重试 · 快照 \(timeOnly(date))"
            }
            return "账号同步待重试"
        }
    }

    private func timeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func footerButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct OverviewCard: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 18) {
            ringSection
                .frame(width: 132)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Label("今日 Tokens", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(UsageFormatters.tokens(snapshot.todayUsage.total))
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                TokenSegments(usage: snapshot.todayUsage)

                HStack(spacing: 10) {
                    legend("输入", color: MeterPalette.blue)
                    legend("缓存", color: MeterPalette.purple)
                    legend("输出", color: MeterPalette.amber)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .meterCard()
    }

    private var ringSection: some View {
        let window = snapshot.primaryDisplayWindow
        let progress = (window?.remainingPercent ?? 0) / 100

        return ZStack {
            Circle()
                .stroke(MeterPalette.purple.opacity(0.13), lineWidth: 11)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [MeterPalette.purple, MeterPalette.violet, MeterPalette.purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: MeterPalette.purple.opacity(0.28), radius: 5)

            VStack(spacing: 1) {
                Text(window?.shortLabel ?? "—")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MeterPalette.purple)
                Text(window.map { UsageFormatters.percent($0.remainingPercent) } ?? "—")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("剩余")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 112, height: 112)
        .accessibilityLabel("Codex 用量窗口剩余")
        .accessibilityValue(window.map { UsageFormatters.percent($0.remainingPercent) } ?? "暂无数据")
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct TokenSegments: View {
    let usage: TokenUsage

    var body: some View {
        GeometryReader { proxy in
            let values = [usage.uncachedInput, usage.cachedInput, usage.output]
            let total = max(1, values.reduce(0, +))
            let available = max(0, proxy.size.width - 4)

            HStack(spacing: 2) {
                segment(width: available * Double(values[0]) / Double(total), color: MeterPalette.blue)
                segment(width: available * Double(values[1]) / Double(total), color: MeterPalette.purple)
                segment(width: available * Double(values[2]) / Double(total), color: MeterPalette.amber)
            }
            .background(Color.primary.opacity(0.07), in: Capsule())
        }
        .frame(height: 8)
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: max(0, width), height: 8)
    }
}

private struct RateLimitsCard: View {
    @ObservedObject var store: UsageStore

    private var snapshot: UsageSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Codex 用量窗口", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let plan = snapshot.rateLimits?.planType, !plan.isEmpty {
                    Text(plan.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                sourceBadge
            }

            if let windows = snapshot.rateLimits?.windows, !windows.isEmpty {
                ForEach(windows) { window in
                    RateWindowRow(window: window)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("等待 Codex 写入最新用量窗口。Token 统计仍可使用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(15)
        .meterCard()
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch store.accountQuotaState {
        case .synced:
            badge("账号实时", color: .green)
        case .syncing:
            badge("同步中", color: MeterPalette.purple)
        case .fallback(_, let reason):
            if snapshot.rateLimits?.source == .accountAPI {
                badge("账号缓存", color: .orange)
                    .help(reason)
            } else {
                badge("本地快照·跨端可能缺失", color: .orange)
                    .help(reason)
            }
        case .waiting:
            badge("等待同步", color: .secondary)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct RateWindowRow: View {
    let window: RateLimitWindow

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(window.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text("· 重置 \(UsageFormatters.resetTime(window.resetsAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("已用 \(UsageFormatters.percent(window.usedPercent))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MeterPalette.purple)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MeterPalette.blue, MeterPalette.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * min(1, max(0, window.usedPercent / 100)))
                }
            }
            .frame(height: 7)
        }
    }
}

private enum UsageChartMode: String, CaseIterable, Identifiable {
    case daily = "每日"
    case weekly = "每周"
    case cumulative = "累计"

    var id: String { rawValue }
}

private struct UsageHover: Equatable {
    var id: String
    var text: String
}

private struct CumulativeUsagePoint: Identifiable {
    var day: DailyUsage
    var total: Int64
    var id: Date { day.date }
}

private struct HeatmapCard: View {
    let snapshot: UsageSnapshot
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode: UsageChartMode = .daily
    @State private var hovered: UsageHover?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("近 90 天用量", systemImage: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("本机日志估算")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Picker("统计粒度", selection: $mode) {
                ForEach(UsageChartMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 205)
            .onChange(of: mode) { _ in hovered = nil }

            ZStack(alignment: .top) {
                Group {
                    switch mode {
                    case .daily:
                        dailyChart
                    case .weekly:
                        weeklyChart
                    case .cumulative:
                        cumulativeChart
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let hovered {
                    Text(hovered.text)
                        .font(.system(size: 11.5, weight: .medium))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                }
            }
            .frame(height: 123)
            .animation(.easeOut(duration: 0.12), value: hovered)

            HStack {
                Text(footerSummary)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("少")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(level: Double(level) / 4))
                        .frame(width: 12, height: 12)
                }
                Text("多")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Token 与项目统计来自本机 sessions；账号额度另行实时同步。")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
        }
        .padding(15)
        .meterCard()
    }

    private var dailyChart: some View {
        HStack(alignment: .top, spacing: 7) {
            VStack(spacing: 3) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 15)
                }
            }
            heatmapGrid
            Spacer(minLength: 0)
        }
    }

    private var heatmapGrid: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let currentMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let gridStart = calendar.date(byAdding: .day, value: -(13 * 7), to: currentMonday) ?? currentMonday
        let usageByDay = Dictionary(uniqueKeysWithValues: snapshot.days.map {
            (calendar.startOfDay(for: $0.date), $0.usage.total)
        })
        let positiveValues = usageByDay.values.filter { $0 > 0 }.sorted()
        let firstDay = snapshot.days.first.map { calendar.startOfDay(for: $0.date) } ?? today

        return HStack(spacing: 3) {
            ForEach(0..<14, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        let offset = week * 7 + weekdayIndex
                        let date = calendar.date(byAdding: .day, value: offset, to: gridStart) ?? gridStart
                        let value = usageByDay[date] ?? 0
                        let isAvailable = date >= firstDay && date <= today
                        let item = UsageHover(
                            id: "day-\(date.timeIntervalSince1970)",
                            text: dailyTooltip(date: date, value: value, isAvailable: isAvailable)
                        )
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isAvailable ? heatColor(value: value, distribution: positiveValues) : Color.primary.opacity(0.035))
                            .frame(width: 15, height: 15)
                            .contentShape(Rectangle())
                            .onHover { isInside in
                                updateHover(item, isInside: isInside, isAvailable: isAvailable)
                            }
                            .help(item.text)
                    }
                }
            }
        }
    }

    private var weeklyChart: some View {
        let weeks = snapshot.weeklyUsage
        let maximum = max(1, weeks.map(\.usage.total).max() ?? 0)

        return GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(weeks) { week in
                    let ratio = Double(week.usage.total) / Double(maximum)
                    let item = UsageHover(
                        id: "week-\(week.startDate.timeIntervalSince1970)",
                        text: weeklyTooltip(week)
                    )
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [MeterPalette.purple, MeterPalette.violet],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(5, (proxy.size.height - 18) * ratio))
                            .opacity(week.usage.total == 0 ? 0.15 : 1)
                        Text(weekLabel(week.startDate))
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onHover { updateHover(item, isInside: $0, isAvailable: true) }
                    .help(item.text)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var cumulativeChart: some View {
        let points = cumulativePoints
        let maximum = max(1, points.last?.total ?? 0)

        return GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(points) { point in
                    let ratio = Double(point.total) / Double(maximum)
                    let item = UsageHover(
                        id: "total-\(point.day.date.timeIntervalSince1970)",
                        text: cumulativeTooltip(point)
                    )
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [MeterPalette.blue, MeterPalette.purple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: max(2, (proxy.size.height - 13) * ratio))
                        .contentShape(Rectangle())
                        .onHover { updateHover(item, isInside: $0, isAvailable: true) }
                        .help(item.text)
                }
            }
            .padding(.horizontal, 2)
            .overlay(alignment: .bottomLeading) {
                HStack {
                    Text(shortDate(points.first?.day.date))
                    Spacer()
                    Text(shortDate(points.last?.day.date))
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var cumulativePoints: [CumulativeUsagePoint] {
        var total: Int64 = 0
        return snapshot.days.map { day in
            total += day.usage.total
            return CumulativeUsagePoint(day: day, total: total)
        }
    }

    private var footerSummary: String {
        switch mode {
        case .daily:
            return "90 天合计 \(UsageFormatters.tokens(snapshot.trailingNinetyDayUsage.total))"
        case .weekly:
            return "本周 \(UsageFormatters.tokens(snapshot.weeklyUsage.last?.usage.total ?? 0))"
        case .cumulative:
            return "累计 \(UsageFormatters.tokens(snapshot.trailingNinetyDayUsage.total))"
        }
    }

    private func heatColor(value: Int64, distribution: [Int64]) -> Color {
        guard value > 0, !distribution.isEmpty else { return heatColor(level: 0) }
        let rank = distribution.lastIndex(where: { $0 <= value }) ?? 0
        let percentile = Double(rank + 1) / Double(distribution.count)
        return heatColor(level: percentile)
    }

    private func heatColor(level: Double) -> Color {
        let clamped = min(1, max(0, level))
        if colorScheme == .dark {
            switch clamped {
            case 0:
                return Color.white.opacity(0.055)
            case ..<0.25:
                return Color(red: 0.19, green: 0.13, blue: 0.34)
            case ..<0.50:
                return Color(red: 0.31, green: 0.20, blue: 0.61)
            case ..<0.75:
                return Color(red: 0.46, green: 0.27, blue: 0.91)
            default:
                return Color(red: 0.70, green: 0.51, blue: 1.00)
            }
        }

        switch clamped {
        case 0:
            return Color.black.opacity(0.055)
        case ..<0.25:
            return Color(red: 0.89, green: 0.85, blue: 0.98)
        case ..<0.50:
            return Color(red: 0.72, green: 0.62, blue: 0.95)
        case ..<0.75:
            return Color(red: 0.50, green: 0.34, blue: 0.89)
        default:
            return Color(red: 0.31, green: 0.13, blue: 0.70)
        }
    }

    private func updateHover(_ item: UsageHover, isInside: Bool, isAvailable: Bool) {
        guard isAvailable else { return }
        if isInside {
            hovered = item
        } else if hovered?.id == item.id {
            hovered = nil
        }
    }

    private func dailyTooltip(date: Date, value: Int64, isAvailable: Bool) -> String {
        guard isAvailable else { return "无统计" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: date)) 使用了 \(tooltipTokens(value)) 个 Token"
    }

    private func weeklyTooltip(_ week: WeeklyUsage) -> String {
        "\(shortDate(week.startDate))–\(shortDate(week.endDate)) 使用了 \(tooltipTokens(week.usage.total)) 个 Token"
    }

    private func cumulativeTooltip(_ point: CumulativeUsagePoint) -> String {
        "截至 \(shortDate(point.day.date)) 累计 \(tooltipTokens(point.total)) 个 Token"
    }

    private func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func tooltipTokens(_ value: Int64) -> String {
        let number = Double(max(0, value))
        if number >= 100_000_000 {
            return String(format: "%.2f 亿", number / 100_000_000)
        }
        if number >= 10_000 {
            return String(format: "%.1f 万", number / 10_000)
        }
        return String(Int64(number))
    }
}

struct SettingsView: View {
    @ObservedObject private var store: UsageStore
    @State private var path: String
    @State private var interval: Double
    @State private var showMenuPercentage: Bool

    init(store: UsageStore) {
        self.store = store
        _path = State(initialValue: store.sessionsPath)
        _interval = State(initialValue: store.refreshInterval)
        _showMenuPercentage = State(initialValue: store.showMenuPercentage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Codex Meter 设置")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 7) {
                Text("Codex sessions 目录")
                    .font(.headline)
                HStack {
                    TextField("~/.codex/sessions", text: $path)
                        .textFieldStyle(.roundedBorder)
                    Button("选择…", action: chooseFolder)
                }
            }

            HStack {
                Text("自动刷新")
                Spacer()
                Picker("", selection: $interval) {
                    Text("1 分钟").tag(60.0)
                    Text("5 分钟").tag(300.0)
                    Text("15 分钟").tag(900.0)
                }
                .labelsHidden()
                .frame(width: 120)
            }

            Toggle("在菜单栏显示最长窗口的剩余百分比", isOn: $showMenuPercentage)

            Text("Token 只读取本地会话日志；额度通过本机 Codex App Server 使用现有登录状态向 OpenAI 查询。应用不读取 auth.json，也不保存任何凭据。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("重建统计缓存") {
                    store.rebuildCache()
                }
                Spacer()
                Button("应用") {
                    store.applySettings(
                        path: path,
                        refreshInterval: interval,
                        showMenuPercentage: showMenuPercentage
                    )
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

private extension View {
    func meterCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.94))
                .shadow(color: Color.black.opacity(0.055), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.075), lineWidth: 1)
        )
    }
}
