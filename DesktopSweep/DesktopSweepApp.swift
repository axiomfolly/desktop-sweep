import SwiftUI

@main
struct DesktopSweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let config = SweepConfig.shared
    @StateObject private var scriptRunner = ScriptRunner()

    var body: some Scene {
        WindowGroup("Desktop Sweep") {
            SettingsView(scriptRunner: scriptRunner)
                .environmentObject(config)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let config = SweepConfig.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        FirstLaunchSetup.runIfNeeded()
        config.startAutoSave()

        applyActivationPolicy()

        if config.showInMenuBar {
            setupStatusItem()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.title == "Desktop Sweep" }?.makeKeyAndOrderFront(nil)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged),
            name: NSNotification.Name("SweepConfigChanged"),
            object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !config.showInMenuBar
    }

    // MARK: - Menu Bar

    @objc private func configChanged() {
        if config.showInMenuBar {
            if statusItem == nil { setupStatusItem() }
        } else {
            removeStatusItem()
        }
        applyActivationPolicy()
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(config.showInMenuBar ? .accessory : .regular)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "archivebox",
            accessibilityDescription: "Desktop Sweep"
        )

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Run Now", action: #selector(runNow), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Desktop Sweep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        for item in menu.items {
            item.target = self
        }
        menu.items.last?.target = nil

        statusItem?.menu = menu
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func runNow() {
        ScriptRunner().run(dryRun: false)
    }

    @objc private func dryRun() {
        ScriptRunner().run(dryRun: true)
    }
}

// MARK: - First Launch Setup

enum FirstLaunchSetup {
    static func runIfNeeded() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let archiveDir = home.appendingPathComponent("Desktop/Archive")
        try? fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        let scriptDest = home.appendingPathComponent("scripts/archive-desktop.sh")
        if !fm.fileExists(atPath: scriptDest.path) {
            let scriptsDir = scriptDest.deletingLastPathComponent()
            try? fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

            if let bundled = Bundle.main.url(forResource: "archive-desktop", withExtension: "sh") {
                try? fm.copyItem(at: bundled, to: scriptDest)
                chmod(scriptDest.path, 0o755)
            }
        }

        let plistDest = home.appendingPathComponent("Library/LaunchAgents/\(LaunchdManager.plistLabel).plist")
        if !fm.fileExists(atPath: plistDest.path) {
            let config = SweepConfig.shared
            LaunchdManager.install(hour: config.scheduleHour, minute: config.scheduleMinute)
        }
    }
}
