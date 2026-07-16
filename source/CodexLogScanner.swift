import Foundation

private struct ScannerCache: Codable {
    var version: Int = 2
    var rootPath: String
    var files: [String: FileCheckpoint] = [:]
}

private struct FileCheckpoint: Codable {
    var scannedSize: Int64 = 0
    var modificationTime: TimeInterval = 0
    var lastTotal: TokenUsage?
    var daily: [String: TokenUsage] = [:]
    var latestRateLimits: RateLimitSnapshot?
}

private struct TokenEvent {
    var timestamp: Date
    var total: TokenUsage
    var rateLimits: RateLimitSnapshot?
}

enum CodexLogScannerError: LocalizedError {
    case missingSessionsDirectory(String)

    var errorDescription: String? {
        switch self {
        case .missingSessionsDirectory(let path):
            return "没有找到 Codex 会话目录：\(path)"
        }
    }
}

final class CodexLogScanner {
    private let rootURL: URL
    private let cacheURL: URL
    private let fileManager: FileManager
    private let calendar: Calendar
    private let marker = Data("token_count".utf8)

    init(
        rootURL: URL,
        cacheURL: URL = CodexLogScanner.defaultCacheURL(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.cacheURL = cacheURL
        self.fileManager = fileManager
        self.calendar = Calendar.current
    }

    func scan(historyDays: Int = 90, now: Date = Date()) throws -> UsageSnapshot {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CodexLogScannerError.missingSessionsDirectory(rootURL.path)
        }

        var cache = loadCache()
        if cache.version != 2 || cache.rootPath != rootURL.path {
            cache = ScannerCache(rootPath: rootURL.path)
        }

        let retentionDays = max(historyDays + 7, 100)
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? .distantPast
        let resources: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resources),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw CodexLogScannerError.missingSessionsDirectory(rootURL.path)
        }

        var files: [(url: URL, modified: Date, size: Int64)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "jsonl",
                  let values = try? url.resourceValues(forKeys: resources),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= cutoff else {
                continue
            }
            files.append((url, modified, Int64(values.fileSize ?? 0)))
        }
        files.sort(by: { $0.url.path < $1.url.path })

        var activePaths = Set<String>()
        var scannedBytes: Int64 = 0

        for file in files {
            let path = file.url.path
            activePaths.insert(path)
            scannedBytes += file.size

            var checkpoint = cache.files[path] ?? FileCheckpoint()
            let unchanged = checkpoint.scannedSize == file.size
                && abs(checkpoint.modificationTime - file.modified.timeIntervalSince1970) < 0.001
            if unchanged {
                continue
            }

            let needsFullScan = file.size < checkpoint.scannedSize
                || (file.size == checkpoint.scannedSize && checkpoint.modificationTime > 0)
            if needsFullScan {
                checkpoint = FileCheckpoint()
            }

            checkpoint = try scanFile(
                file.url,
                from: checkpoint.scannedSize,
                checkpoint: checkpoint,
                retentionCutoff: cutoff
            )

            let refreshedValues = try? file.url.resourceValues(forKeys: resources)
            checkpoint.scannedSize = Int64(refreshedValues?.fileSize ?? Int(checkpoint.scannedSize))
            checkpoint.modificationTime = (refreshedValues?.contentModificationDate ?? file.modified).timeIntervalSince1970
            checkpoint.daily = checkpoint.daily.filter { key, _ in
                guard let date = day(from: key) else { return false }
                return date >= calendar.startOfDay(for: cutoff)
            }
            cache.files[path] = checkpoint
        }

        cache.files = cache.files.filter { activePaths.contains($0.key) }
        saveCache(cache)

        var aggregate: [String: TokenUsage] = [:]
        for checkpoint in cache.files.values {
            for (key, usage) in checkpoint.daily {
                aggregate[key, default: .zero].add(usage)
            }
        }

        let startDay = calendar.date(
            byAdding: .day,
            value: -(max(1, historyDays) - 1),
            to: calendar.startOfDay(for: now)
        ) ?? calendar.startOfDay(for: now)

        var days: [DailyUsage] = []
        for offset in 0..<max(1, historyDays) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            days.append(DailyUsage(date: date, usage: aggregate[dayKey(for: date)] ?? .zero))
        }

        let rateLimits = cache.files.values
            .compactMap(\.latestRateLimits)
            .max(by: { $0.timestamp < $1.timestamp })

        return UsageSnapshot(
            days: days,
            rateLimits: rateLimits,
            scannedFileCount: files.count,
            scannedBytes: scannedBytes,
            updatedAt: now
        )
    }

    func clearCache() throws {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        try fileManager.removeItem(at: cacheURL)
    }

    static func defaultCacheURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_METER_CACHE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("usage-cache.json")
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("CodexMeter", isDirectory: true)
            .appendingPathComponent("usage-cache.json")
    }

    private func scanFile(
        _ url: URL,
        from requestedOffset: Int64,
        checkpoint original: FileCheckpoint,
        retentionCutoff: Date
    ) throws -> FileCheckpoint {
        if requestedOffset == 0,
           let fastResult = try? scanWholeFileWithGrep(url, retentionCutoff: retentionCutoff) {
            return fastResult
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else { return original }

        var checkpoint = original
        var cursor = min(max(0, Int(requestedOffset)), data.count)

        if cursor > 0, data[cursor - 1] != 0x0A {
            if let previousNewline = data[..<cursor].lastIndex(of: 0x0A) {
                cursor = previousNewline + 1
            } else {
                cursor = 0
            }
        }

        while cursor < data.count,
              let match = data.range(of: marker, options: [], in: cursor..<data.count) {
            let lineStart = data[..<match.lowerBound].lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
            let lineEnd: Int
            if match.upperBound < data.count,
               let newline = data[match.upperBound..<data.count].firstIndex(of: 0x0A) {
                lineEnd = newline
            } else {
                lineEnd = data.count
            }

            cursor = lineEnd < data.count ? lineEnd + 1 : data.count

            // Real token_count events are small. Avoid copying giant tool-output lines
            // that merely happen to contain the same text.
            guard lineEnd > lineStart, lineEnd - lineStart <= 512_000 else { continue }
            let line = data.subdata(in: lineStart..<lineEnd)
            guard let event = parseTokenEvent(line) else { continue }
            consume(event, into: &checkpoint, retentionCutoff: retentionCutoff)
        }

        checkpoint.scannedSize = Int64(data.count)
        return checkpoint
    }

    private func scanWholeFileWithGrep(_ url: URL, retentionCutoff: Date) throws -> FileCheckpoint {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = ["-F", "\"type\":\"token_count\"", url.path]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        let matchingLines = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 || process.terminationStatus == 1 else {
            throw CocoaError(.fileReadUnknown)
        }

        var checkpoint = FileCheckpoint()
        for line in matchingLines.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard line.count <= 512_000,
                  let event = parseTokenEvent(Data(line)) else {
                continue
            }
            consume(event, into: &checkpoint, retentionCutoff: retentionCutoff)
        }

        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        checkpoint.scannedSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return checkpoint
    }

    private func consume(
        _ event: TokenEvent,
        into checkpoint: inout FileCheckpoint,
        retentionCutoff: Date
    ) {
        let delta = event.total.delta(from: checkpoint.lastTotal)
        checkpoint.lastTotal = event.total

        if event.timestamp >= retentionCutoff {
            checkpoint.daily[dayKey(for: event.timestamp), default: .zero].add(delta)
        }

        if let limits = event.rateLimits,
           checkpoint.latestRateLimits == nil
                || limits.timestamp > checkpoint.latestRateLimits!.timestamp {
            checkpoint.latestRateLimits = limits
        }
    }

    private func parseTokenEvent(_ data: Data) -> TokenEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any],
              root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let timestampText = root["timestamp"] as? String,
              let timestamp = parseTimestamp(timestampText),
              let info = payload["info"] as? [String: Any],
              let totals = info["total_token_usage"] as? [String: Any] else {
            return nil
        }

        let usage = TokenUsage(
            input: int64(totals["input_tokens"]),
            cachedInput: int64(totals["cached_input_tokens"]),
            output: int64(totals["output_tokens"])
        )

        var limitsSnapshot: RateLimitSnapshot?
        if let rateLimits = payload["rate_limits"] as? [String: Any] {
            var windows: [RateLimitWindow] = []
            if let primary = parseRateWindow(rateLimits["primary"], role: "primary") {
                windows.append(primary)
            }
            if let secondary = parseRateWindow(rateLimits["secondary"], role: "secondary") {
                windows.append(secondary)
            }

            if !windows.isEmpty {
                limitsSnapshot = RateLimitSnapshot(
                    timestamp: timestamp,
                    planType: rateLimits["plan_type"] as? String,
                    windows: windows.sorted(by: { $0.windowMinutes < $1.windowMinutes }),
                    source: .localLog
                )
            }
        }

        return TokenEvent(timestamp: timestamp, total: usage, rateLimits: limitsSnapshot)
    }

    private func parseRateWindow(_ value: Any?, role: String) -> RateLimitWindow? {
        guard let object = value as? [String: Any] else { return nil }
        let minutes = Int(int64(object["window_minutes"]))
        let resetSeconds = TimeInterval(int64(object["resets_at"]))
        guard minutes > 0, resetSeconds > 0 else { return nil }

        return RateLimitWindow(
            role: role,
            usedPercent: double(object["used_percent"]),
            windowMinutes: minutes,
            resetsAt: Date(timeIntervalSince1970: resetSeconds)
        )
    }

    private func int64(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String { return Int64(string) ?? 0 }
        return 0
    }

    private func double(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) ?? 0 }
        return 0
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func day(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    private func loadCache() -> ScannerCache {
        guard let data = try? Data(contentsOf: cacheURL) else {
            return ScannerCache(rootPath: rootURL.path)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ScannerCache.self, from: data))
            ?? ScannerCache(rootPath: rootURL.path)
    }

    private func saveCache(_ cache: ScannerCache) {
        do {
            try fileManager.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(cache).write(to: cacheURL, options: .atomic)
        } catch {
            // The dashboard remains useful without persistence; the next refresh
            // simply performs another read-only scan.
        }
    }
}
