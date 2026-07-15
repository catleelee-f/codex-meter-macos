import Combine
import Foundation

final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var sessionsPath: String
    @Published private(set) var refreshInterval: TimeInterval
    @Published private(set) var showMenuPercentage: Bool

    private let defaults: UserDefaults
    private let scannerQueue = DispatchQueue(label: "local.codexmeter.scanner", qos: .userInitiated)
    private var timer: Timer?
    private var activeRequestID = UUID()

    private enum Keys {
        static let sessionsPath = "sessionsPath"
        static let refreshInterval = "refreshInterval"
        static let showMenuPercentage = "showMenuPercentage"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? (NSHomeDirectory() as NSString).appendingPathComponent(".codex")
        let defaultSessionsPath = (codexHome as NSString).appendingPathComponent("sessions")

        self.sessionsPath = defaults.string(forKey: Keys.sessionsPath) ?? defaultSessionsPath

        let savedInterval = defaults.double(forKey: Keys.refreshInterval)
        self.refreshInterval = savedInterval >= 60 ? savedInterval : 60

        if defaults.object(forKey: Keys.showMenuPercentage) == nil {
            self.showMenuPercentage = true
        } else {
            self.showMenuPercentage = defaults.bool(forKey: Keys.showMenuPercentage)
        }

        scheduleTimer()
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil
        let requestID = UUID()
        activeRequestID = requestID
        let rootURL = URL(fileURLWithPath: expandedPath(sessionsPath), isDirectory: true)

        scannerQueue.async { [weak self] in
            guard let self else { return }
            do {
                let result = try CodexLogScanner(rootURL: rootURL).scan(historyDays: 90)
                DispatchQueue.main.async {
                    guard self.activeRequestID == requestID else { return }
                    self.snapshot = result
                    self.isRefreshing = false
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.activeRequestID == requestID else { return }
                    self.errorMessage = error.localizedDescription
                    self.isRefreshing = false
                }
            }
        }
    }

    func applySettings(path: String, refreshInterval: TimeInterval, showMenuPercentage: Bool) {
        let normalizedPath = expandedPath(path.trimmingCharacters(in: .whitespacesAndNewlines))
        let safeInterval = max(60, refreshInterval)

        sessionsPath = normalizedPath
        self.refreshInterval = safeInterval
        self.showMenuPercentage = showMenuPercentage

        defaults.set(normalizedPath, forKey: Keys.sessionsPath)
        defaults.set(safeInterval, forKey: Keys.refreshInterval)
        defaults.set(showMenuPercentage, forKey: Keys.showMenuPercentage)
        scheduleTimer()
        refresh()
    }

    func rebuildCache() {
        do {
            try CodexLogScanner(
                rootURL: URL(fileURLWithPath: expandedPath(sessionsPath), isDirectory: true)
            ).clearCache()
            snapshot = .empty
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "无法重建缓存：\(error.localizedDescription)"
        }
    }

    var menuTitle: String {
        guard showMenuPercentage else { return "" }
        guard let window = snapshot.primaryDisplayWindow else { return "" }
        return "\(window.shortLabel) \(UsageFormatters.percent(window.remainingPercent))"
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
