import Foundation

let accountResponse = Data(#"""
{"id":2601,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":63,"windowDurationMins":10080,"resetsAt":1784674864},"secondary":null,"planType":"plus"},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":63,"windowDurationMins":10080,"resetsAt":1784674864},"secondary":null,"planType":"plus"}}}}
"""#.utf8)
let accountSnapshot = try CodexAccountUsageClient.parseResponse(
    accountResponse,
    fetchedAt: Date(timeIntervalSince1970: 1_784_160_000)
)
guard accountSnapshot.source == .accountAPI,
      accountSnapshot.planType == "plus",
      accountSnapshot.windows.count == 1,
      accountSnapshot.windows[0].windowMinutes == 10_080,
      accountSnapshot.windows[0].usedPercent == 63,
      accountSnapshot.windows[0].remainingPercent == 37 else {
    fatalError("Account rate-limit response parsing failed")
}
print("account_remaining=\(UsageFormatters.percent(accountSnapshot.windows[0].remainingPercent))")

let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
    ?? (NSHomeDirectory() as NSString).appendingPathComponent(".codex")
let sessionsURL = URL(
    fileURLWithPath: (codexHome as NSString).appendingPathComponent("sessions"),
    isDirectory: true
)

do {
    let snapshot = try CodexLogScanner(rootURL: sessionsURL).scan(historyDays: 90)
    let windows = snapshot.rateLimits?.windows
        .map { "\($0.shortLabel)=used:\(UsageFormatters.percent($0.usedPercent))" }
        .joined(separator: ", ") ?? "none"

    print("files=\(snapshot.scannedFileCount)")
    print("bytes=\(snapshot.scannedBytes)")
    print("today_tokens=\(snapshot.todayUsage.total)")
    print("ninety_day_tokens=\(snapshot.trailingNinetyDayUsage.total)")
    print("rate_windows=\(windows)")

    guard snapshot.scannedFileCount > 0 else {
        fatalError("Expected at least one Codex session file")
    }
    guard snapshot.trailingNinetyDayUsage.total > 0 else {
        fatalError("Expected non-zero token usage")
    }
    guard snapshot.rateLimits?.windows.isEmpty == false else {
        fatalError("Expected at least one rate-limit window")
    }
} catch {
    fatalError("Scanner failed: \(error.localizedDescription)")
}
