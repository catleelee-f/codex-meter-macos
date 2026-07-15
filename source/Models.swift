import Foundation

struct TokenUsage: Codable, Equatable {
    var input: Int64 = 0
    var cachedInput: Int64 = 0
    var output: Int64 = 0

    static let zero = TokenUsage()

    var total: Int64 {
        max(0, input) + max(0, output)
    }

    var uncachedInput: Int64 {
        max(0, input - cachedInput)
    }

    mutating func add(_ other: TokenUsage) {
        input += other.input
        cachedInput += other.cachedInput
        output += other.output
    }

    func adding(_ other: TokenUsage) -> TokenUsage {
        var result = self
        result.add(other)
        return result
    }

    func delta(from previous: TokenUsage?) -> TokenUsage {
        guard let previous else { return self }

        let counterReset = input < previous.input
            || cachedInput < previous.cachedInput
            || output < previous.output
            || total < previous.total

        if counterReset {
            return self
        }

        return TokenUsage(
            input: max(0, input - previous.input),
            cachedInput: max(0, cachedInput - previous.cachedInput),
            output: max(0, output - previous.output)
        )
    }
}

struct RateLimitWindow: Codable, Equatable, Identifiable {
    var role: String
    var usedPercent: Double
    var windowMinutes: Int
    var resetsAt: Date

    var id: String {
        "\(role)-\(windowMinutes)"
    }

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    var shortLabel: String {
        switch windowMinutes {
        case 300:
            return "5h"
        case 10_080:
            return "7d"
        default:
            if windowMinutes % 10_080 == 0 {
                return "\(windowMinutes / 10_080)w"
            }
            if windowMinutes % 1_440 == 0 {
                return "\(windowMinutes / 1_440)d"
            }
            if windowMinutes % 60 == 0 {
                return "\(windowMinutes / 60)h"
            }
            return "\(windowMinutes)m"
        }
    }

    var displayName: String {
        switch windowMinutes {
        case 300:
            return "5 小时窗口"
        case 10_080:
            return "7 天窗口"
        default:
            if windowMinutes % 10_080 == 0 {
                return "\(windowMinutes / 10_080) 周窗口"
            }
            if windowMinutes % 1_440 == 0 {
                return "\(windowMinutes / 1_440) 天窗口"
            }
            if windowMinutes % 60 == 0 {
                return "\(windowMinutes / 60) 小时窗口"
            }
            return "\(windowMinutes) 分钟窗口"
        }
    }
}

struct RateLimitSnapshot: Codable, Equatable {
    var timestamp: Date
    var planType: String?
    var windows: [RateLimitWindow]
}

struct DailyUsage: Identifiable, Equatable {
    var date: Date
    var usage: TokenUsage

    var id: Date { date }
}

struct UsageSnapshot: Equatable {
    var days: [DailyUsage]
    var rateLimits: RateLimitSnapshot?
    var scannedFileCount: Int
    var scannedBytes: Int64
    var updatedAt: Date

    static let empty = UsageSnapshot(
        days: [],
        rateLimits: nil,
        scannedFileCount: 0,
        scannedBytes: 0,
        updatedAt: .distantPast
    )

    var todayUsage: TokenUsage {
        days.first(where: { Calendar.current.isDateInToday($0.date) })?.usage ?? .zero
    }

    var trailingSevenDayUsage: TokenUsage {
        aggregate(last: 7)
    }

    var trailingNinetyDayUsage: TokenUsage {
        aggregate(last: 90)
    }

    var primaryDisplayWindow: RateLimitWindow? {
        rateLimits?.windows.max(by: { $0.windowMinutes < $1.windowMinutes })
    }

    private func aggregate(last count: Int) -> TokenUsage {
        days.suffix(count).reduce(.zero) { partial, day in
            partial.adding(day.usage)
        }
    }
}

enum UsageFormatters {
    static func tokens(_ value: Int64) -> String {
        let number = Double(max(0, value))
        switch number {
        case 1_000_000_000...:
            return compact(number / 1_000_000_000, suffix: "B")
        case 1_000_000...:
            return compact(number / 1_000_000, suffix: "M")
        case 1_000...:
            return compact(number / 1_000, suffix: "K")
        default:
            return String(Int64(number))
        }
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", min(100, max(0, value)))
    }

    static func resetTime(_ date: Date, relativeTo now: Date = Date()) -> String {
        guard date > now else { return "等待 Codex 更新" }

        let calendar = Calendar.current
        let time = DateFormatter()
        time.locale = Locale(identifier: "zh_CN")
        time.dateFormat = "HH:mm"

        if calendar.isDateInToday(date) {
            return "今天 \(time.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "明天 \(time.string(from: date))"
        }

        let full = DateFormatter()
        full.locale = Locale(identifier: "zh_CN")
        full.dateFormat = "M月d日 HH:mm"
        return full.string(from: date)
    }

    static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: value)
    }

    private static func compact(_ value: Double, suffix: String) -> String {
        if value >= 100 || value.rounded() == value {
            return String(format: "%.0f%@", value, suffix)
        }
        if value >= 10 {
            return String(format: "%.1f%@", value, suffix)
        }
        return String(format: "%.2f%@", value, suffix)
    }
}
