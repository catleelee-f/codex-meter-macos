import AppKit
import Combine
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(store: UsageStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Meter 设置"
        window.contentViewController = NSHostingController(rootView: SettingsView(store: store))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class DetailsWindowController: NSWindowController {
    init(store: UsageStore, onOpenCodex: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex 详细统计"
        window.minSize = NSSize(width: 760, height: 560)
        window.contentViewController = NSHostingController(
            rootView: DetailsView(store: store, onOpenCodex: onOpenCodex)
        )
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var detailsWindowController: DetailsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        observeStore()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.showPopover()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        let autosaveName = "io.github.catleelee-f.codexmeter.status-item"
        let preferredPositionKey = "NSStatusItem Preferred Position \(autosaveName)"
        let placementMigrationKey = "didPlaceStatusItemNearClockV2"
        if !UserDefaults.standard.bool(forKey: placementMigrationKey) {
            // New status items are normally inserted on the far left of other
            // menu extras, which can put them behind a MacBook camera notch.
            UserDefaults.standard.set(96, forKey: preferredPositionKey)
            UserDefaults.standard.set(true, forKey: placementMigrationKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        item.behavior = [.removalAllowed]
        item.isVisible = true
        guard let button = item.button else { return }

        button.image = makeStatusIcon()
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageLeading
        button.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        button.title = " C"
        button.toolTip = "Codex 用量"
        button.target = self
        button.action = #selector(togglePopover)
        statusItem = item
    }

    private func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let ring = NSBezierPath()
            ring.appendArc(
                withCenter: NSPoint(x: 8.4, y: 8.5),
                radius: 5.4,
                startAngle: 42,
                endAngle: 320,
                clockwise: false
            )
            ring.lineWidth = 2.15
            ring.lineCapStyle = .round
            ring.stroke()

            let spark = NSBezierPath()
            spark.move(to: NSPoint(x: 13.2, y: 16.0))
            spark.line(to: NSPoint(x: 14.0, y: 13.9))
            spark.line(to: NSPoint(x: 16.1, y: 13.1))
            spark.line(to: NSPoint(x: 14.0, y: 12.3))
            spark.line(to: NSPoint(x: 13.2, y: 10.2))
            spark.line(to: NSPoint(x: 12.4, y: 12.3))
            spark.line(to: NSPoint(x: 10.3, y: 13.1))
            spark.line(to: NSPoint(x: 12.4, y: 13.9))
            spark.close()
            spark.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Codex Meter"
        return image
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 446, height: 700)
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(
                store: store,
                onOpenCodex: { [weak self] in self?.openCodex() },
                onOpenDetails: { [weak self] in self?.showDetails() },
                onOpenSettings: { [weak self] in self?.showSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    private func observeStore() {
        Publishers.CombineLatest(store.$snapshot, store.$showMenuPercentage)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        store.$isRefreshing
            .receive(on: RunLoop.main)
            .sink { [weak self] refreshing in
                self?.statusItem?.button?.toolTip = refreshing
                    ? "正在刷新 Codex 用量…"
                    : "Codex 用量"
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        statusItem?.button?.title = store.menuTitle.isEmpty ? " C" : " \(store.menuTitle)"
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else { return }
        store.refreshIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showSettings() {
        popover.performClose(nil)
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showDetails() {
        popover.performClose(nil)
        store.refreshIfNeeded()
        if detailsWindowController == nil {
            detailsWindowController = DetailsWindowController(
                store: store,
                onOpenCodex: { [weak self] in self?.openCodex() }
            )
        }
        detailsWindowController?.showWindow(nil)
        detailsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openCodex() {
        popover.performClose(nil)

        if let running = NSWorkspace.shared.runningApplications.first(where: { application in
            application.bundleIdentifier != Bundle.main.bundleIdentifier
                && application.bundleURL?.lastPathComponent.caseInsensitiveCompare("Codex.app") == .orderedSame
        }) {
            running.activate(options: [.activateAllWindows])
            return
        }

        let identifiers = [
            "com.openai.codex",
            "com.openai.Codex"
        ]
        for identifier in identifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: NSWorkspace.OpenConfiguration(),
                    completionHandler: nil
                )
                return
            }
        }

        let commonLocations = [
            "/Applications/Codex.app",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications/Codex.app")
        ]
        for path in commonLocations where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: path),
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            return
        }

        if let url = URL(string: "https://chatgpt.com/codex") {
            NSWorkspace.shared.open(url)
        }
    }
}

@main
enum CodexMeterMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
