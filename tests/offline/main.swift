import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
let sessions = root.appendingPathComponent("sessions")
try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }
let now = Date()
let stamp = ISO8601DateFormatter().string(from: now)
func event(_ input: Int, _ output: Int) throws -> Data {
    let object: [String: Any] = [
        "timestamp": stamp, "type": "event_msg",
        "payload": ["type": "token_count", "info": ["total_token_usage":
            ["input_tokens": input, "cached_input_tokens": input / 2, "output_tokens": output]]]
    ]
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    data.append(10)
    return data
}
let file = sessions.appendingPathComponent("synthetic.jsonl")
var initial = Data("{\"type\":\"session_meta\",\"payload\":{\"cwd\":\"/synthetic/project\"}}\ninvalid-json\n".utf8)
initial.append(try event(100, 10))
initial.append(try event(150, 20))
try initial.write(to: file)
let scanner = CodexLogScanner(rootURL: sessions, cacheURL: root.appendingPathComponent("cache.json"))
let first = try scanner.scan(now: now)
check(first.trailingNinetyDayUsage.total == 170, "Cumulative counters must not be double counted")
check(first.projects.count == 1 && first.projects[0].name == "project", "Project metadata")
check(first.rateLimits == nil, "Missing quota must remain unknown")
let warm = try scanner.scan(now: now)
check(warm.trailingNinetyDayUsage.total == 170, "Warm cache")
let handle = try FileHandle(forWritingTo: file)
try handle.seekToEnd()
try handle.write(contentsOf: event(200, 30))
try handle.close()
let appended = try scanner.scan(now: now)
check(appended.trailingNinetyDayUsage.total == 230, "Incremental append")
check(appended.weeklyUsage.reduce(0) { $0 + $1.usage.total } == 230, "Weekly conservation")
check(appended.projects.reduce(0) { $0 + $1.totalUsage.total } == 230, "Project conservation")
try event(10, 2).write(to: file)
let truncated = try scanner.scan(now: now)
check(truncated.trailingNinetyDayUsage.total == 12, "Truncated file rebuild")
check(TokenUsage(input: 10, output: 2).delta(from: TokenUsage(input: 200, output: 30)).total == 12, "Counter reset")
let response = Data(#"{"result":{"rateLimits":{"planType":"plus","primary":{"usedPercent":30,"windowDurationMins":300,"resetsAt":1900000000},"secondary":{"usedPercent":60,"windowDurationMins":10080,"resetsAt":1900000000}}}}"#.utf8)
let quota = try CodexAccountUsageClient.parseResponse(response)
check(quota.windows.count == 2 && quota.windows[1].remainingPercent == 40, "Two quota windows")
do {
    _ = try CodexAccountUsageClient.parseResponse(Data("{}".utf8))
    fatalError("Malformed account response accepted")
} catch {}
print("PASS: synthetic scanner, warm cache, append, truncation, counter reset, project/week totals, account responses")