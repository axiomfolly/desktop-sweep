import Foundation

enum LaunchdManager {
    static let plistLabel = "net.axiomfolly.desktop-sweep"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(plistLabel).plist")
    }

    private static var scriptURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("scripts/archive-desktop.sh")
    }

    // MARK: - Status

    static func isLoaded() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["list", plistLabel]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    // MARK: - Load / Unload

    @discardableResult
    static func load() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["load", plistURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    @discardableResult
    static func unload() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["unload", plistURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    // MARK: - Install / Update

    static func install(hour: Int, minute: Int) {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let scriptsDir = home.appendingPathComponent("scripts")
        try? fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

        if let bundledScript = Bundle.main.url(forResource: "archive-desktop", withExtension: "sh") {
            try? fm.removeItem(at: scriptURL)
            try? fm.copyItem(at: bundledScript, to: scriptURL)
            chmod(scriptURL.path, 0o755)
        }

        let plistContent = generatePlist(home: home.path, hour: hour, minute: minute)
        if isLoaded() { unload() }
        try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        load()
    }

    static func generatePlist(home: String, hour: Int, minute: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/bash</string>
                <string>\(home)/scripts/archive-desktop.sh</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>\(hour)</integer>
                <key>Minute</key>
                <integer>\(minute)</integer>
            </dict>
            <key>StandardOutPath</key>
            <string>\(home)/Desktop/Archive/launchd-stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(home)/Desktop/Archive/launchd-stderr.log</string>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
    }
}
