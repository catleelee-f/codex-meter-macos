import Foundation

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
