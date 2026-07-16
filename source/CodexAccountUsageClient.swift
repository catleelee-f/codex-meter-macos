import Foundation

enum CodexAccountUsageError: LocalizedError {
    case codexCLINotFound
    case launchFailed(String)
    case timedOut
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .codexCLINotFound:
            return "未找到支持账号用量同步的 Codex CLI"
        case .launchFailed(let message):
            return "无法启动 Codex 用量服务：\(message)"
        case .timedOut:
            return "账号用量同步超时"
        case .server(let message):
            return "账号用量同步失败：\(message)"
        case .invalidResponse:
            return "Codex 返回了无法识别的用量数据"
        }
    }
}

private final class AccountUsageResponseBox {
    private let lock = NSLock()
    private let semaphore: DispatchSemaphore
    private var buffer = Data()
    private var response: Data?
    private var exitError: CodexAccountUsageError?
    private var completed = false

    init(semaphore: DispatchSemaphore) {
        self.semaphore = semaphore
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return }

        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)

            guard let object = try? JSONSerialization.jsonObject(with: line),
                  let root = object as? [String: Any],
                  let id = root["id"] as? NSNumber,
                  id.intValue == CodexAccountUsageClient.requestID else {
                continue
            }

            response = line
            completed = true
            semaphore.signal()
            return
        }
    }

    func processExited(status: Int32) {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return }

        completed = true
        exitError = .launchFailed("进程提前退出（\(status)）")
        semaphore.signal()
    }

    func result() -> Result<Data, CodexAccountUsageError>? {
        lock.lock()
        defer { lock.unlock() }
        if let response { return .success(response) }
        if let exitError { return .failure(exitError) }
        return nil
    }
}

final class CodexAccountUsageClient {
    static let requestID = 2_601

    private let fileManager: FileManager
    private let homeDirectory: String
    private let environment: [String: String]

    init(
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.environment = environment
    }

    func fetchRateLimits(timeout: TimeInterval = 20) throws -> RateLimitSnapshot {
        guard let executableURL = locateCodexExecutable() else {
            throw CodexAccountUsageError.codexCLINotFound
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]

        var childEnvironment = environment
        let executableDirectory = executableURL.deletingLastPathComponent().path
        let inheritedPath = childEnvironment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        childEnvironment["PATH"] = "\(executableDirectory):\(inheritedPath)"
        childEnvironment["RUST_LOG"] = "error"
        process.environment = childEnvironment

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let semaphore = DispatchSemaphore(value: 0)
        let responseBox = AccountUsageResponseBox(semaphore: semaphore)
        output.fileHandleForReading.readabilityHandler = { handle in
            responseBox.append(handle.availableData)
        }
        process.terminationHandler = { process in
            responseBox.processExited(status: process.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            throw CodexAccountUsageError.launchFailed(error.localizedDescription)
        }

        defer {
            output.fileHandleForReading.readabilityHandler = nil
            input.fileHandleForWriting.closeFile()
            if process.isRunning {
                process.terminate()
            }
        }

        do {
            try sendRequests(to: input.fileHandleForWriting)
        } catch {
            throw CodexAccountUsageError.launchFailed(error.localizedDescription)
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw CodexAccountUsageError.timedOut
        }

        guard let result = responseBox.result() else {
            throw CodexAccountUsageError.invalidResponse
        }

        switch result {
        case .success(let data):
            return try Self.parseResponse(data, fetchedAt: Date())
        case .failure(let error):
            throw error
        }
    }

    static func parseResponse(_ data: Data, fetchedAt: Date = Date()) throws -> RateLimitSnapshot {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            throw CodexAccountUsageError.invalidResponse
        }

        if let error = root["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "未知错误"
            throw CodexAccountUsageError.server(message)
        }

        guard let result = root["result"] as? [String: Any] else {
            throw CodexAccountUsageError.invalidResponse
        }

        let keyedLimits = result["rateLimitsByLimitId"] as? [String: Any]
        let rawSnapshot = (keyedLimits?["codex"] as? [String: Any])
            ?? (result["rateLimits"] as? [String: Any])
        guard let rawSnapshot else {
            throw CodexAccountUsageError.invalidResponse
        }

        var windows: [RateLimitWindow] = []
        if let primary = parseWindow(rawSnapshot["primary"], role: "primary") {
            windows.append(primary)
        }
        if let secondary = parseWindow(rawSnapshot["secondary"], role: "secondary") {
            windows.append(secondary)
        }
        guard !windows.isEmpty else {
            throw CodexAccountUsageError.invalidResponse
        }

        return RateLimitSnapshot(
            timestamp: fetchedAt,
            planType: rawSnapshot["planType"] as? String,
            windows: windows.sorted(by: { $0.windowMinutes < $1.windowMinutes }),
            source: .accountAPI
        )
    }

    private func sendRequests(to handle: FileHandle) throws {
        let messages: [[String: Any]] = [
            [
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "codex_meter",
                        "title": "Codex Meter",
                        "version": "1.1.0"
                    ]
                ]
            ],
            ["method": "initialized", "params": [:]],
            [
                "method": "account/rateLimits/read",
                "id": Self.requestID,
                "params": NSNull()
            ]
        ]

        for message in messages {
            let data = try JSONSerialization.data(withJSONObject: message)
            handle.write(data)
            handle.write(Data([0x0A]))
        }
    }

    private func locateCodexExecutable() -> URL? {
        var candidates: [String] = []

        if let override = environment["CODEX_CLI_PATH"], !override.isEmpty {
            candidates.append((override as NSString).expandingTildeInPath)
        }

        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            (homeDirectory as NSString).appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex"),
            "/Applications/Codex.app/Contents/Resources/codex",
            (homeDirectory as NSString).appendingPathComponent("Applications/Codex.app/Contents/Resources/codex"),
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            (homeDirectory as NSString).appendingPathComponent(".local/bin/codex"),
            (homeDirectory as NSString).appendingPathComponent(".volta/bin/codex"),
            (homeDirectory as NSString).appendingPathComponent(".bun/bin/codex")
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                (String($0) as NSString).appendingPathComponent("codex")
            })
        }

        candidates.append(contentsOf: versionManagerCandidates())

        var seen = Set<String>()
        for path in candidates where seen.insert(path).inserted {
            if fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func versionManagerCandidates() -> [String] {
        var paths: [String] = []

        let nvmRoot = (homeDirectory as NSString).appendingPathComponent(".nvm/versions/node")
        for version in directoryNames(at: nvmRoot) {
            paths.append((nvmRoot as NSString).appendingPathComponent("\(version)/bin/codex"))
        }

        let fnmRoot = (homeDirectory as NSString).appendingPathComponent(".local/share/fnm/node-versions")
        for version in directoryNames(at: fnmRoot) {
            paths.append((fnmRoot as NSString).appendingPathComponent("\(version)/installation/bin/codex"))
        }

        return paths
    }

    private func directoryNames(at path: String) -> [String] {
        (try? fileManager.contentsOfDirectory(atPath: path))?
            .sorted(by: { $0.compare($1, options: .numeric) == .orderedDescending }) ?? []
    }

    private static func parseWindow(_ value: Any?, role: String) -> RateLimitWindow? {
        guard let object = value as? [String: Any],
              let usedPercent = number(object["usedPercent"]),
              let windowMinutes = number(object["windowDurationMins"]),
              let resetsAt = number(object["resetsAt"]),
              windowMinutes > 0,
              resetsAt > 0 else {
            return nil
        }

        return RateLimitWindow(
            role: role,
            usedPercent: usedPercent,
            windowMinutes: Int(windowMinutes),
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}
