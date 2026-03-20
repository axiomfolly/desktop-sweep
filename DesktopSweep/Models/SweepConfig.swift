import Foundation
import Combine

final class SweepConfig: ObservableObject {
    static let shared = SweepConfig()

    private let configURL: URL
    private var rawLines: [String] = []
    private var saveCancellable: AnyCancellable?

    @Published var enabled: Bool = true
    @Published var scheduleHour: Int = 9
    @Published var scheduleMinute: Int = 0
    @Published var logEnabled: Bool = true
    @Published var ageThresholdDays: Int = 30
    @Published var skipFiles: [String] = []
    @Published var skipExtensions: [String] = []
    @Published var showInMenuBar: Bool = false

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configURL = home.appendingPathComponent("Desktop/Archive/config.cfg")
        ensureConfigExists()
        load()
    }

    // MARK: - Load

    func load() {
        guard let data = try? String(contentsOf: configURL, encoding: .utf8) else { return }
        rawLines = data.components(separatedBy: "\n")

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }

            let key = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "ENABLED":            enabled = (value == "true")
            case "SCHEDULE_HOUR":      scheduleHour = Int(value) ?? 9
            case "SCHEDULE_MINUTE":    scheduleMinute = Int(value) ?? 0
            case "LOG_ENABLED":        logEnabled = (value == "true")
            case "AGE_THRESHOLD_DAYS": ageThresholdDays = Int(value) ?? 30
            case "SKIP_FILES":
                skipFiles = value.isEmpty ? [] : value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "SKIP_EXTENSIONS":
                skipExtensions = value.isEmpty ? [] : value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "SHOW_IN_MENU_BAR":   showInMenuBar = (value == "true")
            default: break
            }
        }
    }

    // MARK: - Save

    func save() {
        let keyValues: [(String, String)] = [
            ("ENABLED", enabled ? "true" : "false"),
            ("SCHEDULE_HOUR", String(scheduleHour)),
            ("SCHEDULE_MINUTE", String(scheduleMinute)),
            ("LOG_ENABLED", logEnabled ? "true" : "false"),
            ("AGE_THRESHOLD_DAYS", String(ageThresholdDays)),
            ("SKIP_FILES", skipFiles.joined(separator: ",")),
            ("SKIP_EXTENSIONS", skipExtensions.joined(separator: ",")),
            ("SHOW_IN_MENU_BAR", showInMenuBar ? "true" : "false"),
        ]

        var updatedLines = rawLines
        var handled = Set<String>()

        for (i, line) in updatedLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let eqIndex = trimmed.firstIndex(of: "=") else { continue }

            let key = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
            if let pair = keyValues.first(where: { $0.0 == key }) {
                updatedLines[i] = "\(pair.0)=\(pair.1)"
                handled.insert(key)
            }
        }

        for (key, value) in keyValues where !handled.contains(key) {
            updatedLines.append("\(key)=\(value)")
        }

        rawLines = updatedLines
        let content = updatedLines.joined(separator: "\n")
        try? content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Auto-save

    func startAutoSave() {
        saveCancellable = objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
    }

    // MARK: - Last Run Info

    var lastRunInfo: String {
        let logURL = configURL.deletingLastPathComponent().appendingPathComponent("archive.log")
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else { return "Never" }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let last = lines.last,
              let range = last.range(of: "\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\]", options: .regularExpression) else {
            return "Never"
        }
        return String(last[range]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    }

    // MARK: - First-launch config

    private func ensureConfigExists() {
        let fm = FileManager.default
        let archiveDir = configURL.deletingLastPathComponent()

        if !fm.fileExists(atPath: archiveDir.path) {
            try? fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        }

        guard !fm.fileExists(atPath: configURL.path) else { return }

        if let bundled = Bundle.main.url(forResource: "config", withExtension: "cfg") {
            try? fm.copyItem(at: bundled, to: configURL)
        }
    }
}
