import Foundation

@main
enum AccountSyncProbe {
    static func main() {
        do {
            let snapshot = try CodexAccountUsageClient().fetchRateLimits()
            guard let window = snapshot.windows.max(by: { $0.windowMinutes < $1.windowMinutes }) else {
                fatalError("Account response did not include a rate-limit window")
            }
            print("source=account")
            print("plan=\(snapshot.planType ?? "unknown")")
            print("window=\(window.shortLabel)")
            print("used=\(UsageFormatters.percent(window.usedPercent))")
            print("remaining=\(UsageFormatters.percent(window.remainingPercent))")
            print("resets_at=\(Int(window.resetsAt.timeIntervalSince1970))")
        } catch {
            fatalError("Account sync failed: \(error.localizedDescription)")
        }
    }
}
