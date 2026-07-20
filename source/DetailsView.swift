import SwiftUI

private enum DetailsPalette {
    static let purple = Color(red: 0.43, green: 0.24, blue: 0.94)
    static let violet = Color(red: 0.64, green: 0.38, blue: 0.98)
    static let blue = Color(red: 0.22, green: 0.46, blue: 0.94)
}

private enum ProjectPeriod: String, CaseIterable, Identifiable {
    case sevenDays = "7 天"
    case thirtyDays = "30 天"
    case ninetyDays = "90 天"

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }
}

private struct RankedProject: Identifiable {
    var project: ProjectUsage
    var usage: TokenUsage
    var activeDays: Int

    var id: String { project.id }
}

struct DetailsView: View {
    @ObservedObject var store: UsageStore
    let onOpenCodex: () -> Void
    @State private var period: ProjectPeriod = .ninetyDays

    private var rankedProjects: [RankedProject] {
        store.snapshot.projects.compactMap { project in
            let days = Array(project.days.suffix(period.dayCount))
            let usage = days.reduce(TokenUsage.zero) { partial, day in
                partial.adding(day.usage)
            }
            guard usage.total > 0 else { return nil }
            return RankedProject(
                project: project,
                usage: usage,
                activeDays: days.filter { $0.usage.total > 0 }.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.usage.total == rhs.usage.total {
                return lhs.project.name.localizedStandardCompare(rhs.project.name) == .orderedAscending
            }
            return lhs.usage.total > rhs.usage.total
        }
    }

    private var periodTotal: Int64 {
        rankedProjects.reduce(0) { $0 + $1.usage.total }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCards
                    rankingSection
                    dataBoundary
                }
                .padding(24)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), DetailsPalette.purple.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DetailsPalette.violet, DetailsPalette.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex 详细统计")
                    .font(.title2.weight(.semibold))
                Text("按本机会话的工作目录生成项目排行榜")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: store.refresh) {
                Label(store.isRefreshing ? "刷新中" : "刷新", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Button(action: onOpenCodex) {
                Label("打开 Codex", systemImage: "macwindow")
            }
            .buttonStyle(.borderedProminent)
            .tint(DetailsPalette.purple)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "今日",
                value: UsageFormatters.tokens(store.snapshot.todayUsage.total),
                detail: "Tokens",
                icon: "sun.max.fill",
                color: .orange
            )
            summaryCard(
                title: "近 7 天",
                value: UsageFormatters.tokens(store.snapshot.trailingSevenDayUsage.total),
                detail: "Tokens",
                icon: "calendar.badge.clock",
                color: DetailsPalette.blue
            )
            summaryCard(
                title: "近 90 天",
                value: UsageFormatters.tokens(store.snapshot.trailingNinetyDayUsage.total),
                detail: "Tokens",
                icon: "chart.xyaxis.line",
                color: DetailsPalette.purple
            )
            summaryCard(
                title: "活跃项目",
                value: "\(store.snapshot.projects.count)",
                detail: "本机目录",
                icon: "folder.fill",
                color: .green
            )
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        detail: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.075), lineWidth: 1)
        )
    }

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("项目用量排行榜")
                        .font(.title3.weight(.semibold))
                    Text("合计 \(UsageFormatters.tokens(periodTotal)) Tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("统计周期", selection: $period) {
                    ForEach(ProjectPeriod.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            if rankedProjects.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("该周期暂无可排行的本机项目数据")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 38)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rankedProjects.enumerated()), id: \.element.id) { index, item in
                        rankingRow(rank: index + 1, item: item)
                        if index < rankedProjects.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.075), lineWidth: 1)
                )
            }
        }
    }

    private func rankingRow(rank: Int, item: RankedProject) -> some View {
        let maximum = max(1, rankedProjects.first?.usage.total ?? 0)
        let share = periodTotal > 0 ? Double(item.usage.total) / Double(periodTotal) : 0

        return HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(rank <= 3 ? DetailsPalette.purple.opacity(0.16) : Color.primary.opacity(0.06))
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(rank <= 3 ? DetailsPalette.purple : .secondary)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.project.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(item.project.path == "(unknown)" ? "未在会话中记录 cwd" : item.project.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 10)
                    Text("\(UsageFormatters.tokens(item.usage.total)) Tokens")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.07))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [DetailsPalette.blue, DetailsPalette.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * Double(item.usage.total) / Double(maximum))
                    }
                }
                .frame(height: 7)

                HStack {
                    Text("占比 \(UsageFormatters.percent(share * 100))")
                    Text("活跃 \(item.activeDays) 天")
                    if let lastActive = item.project.lastActiveDate {
                        Text("最近 \(shortDate(lastActive))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var dataBoundary: some View {
        Label(
            "项目排行只读取本机 Codex sessions 中的 cwd 和 Token 计数，不包含 Hermes 等其他客户端的项目明细。",
            systemImage: "lock.shield"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
