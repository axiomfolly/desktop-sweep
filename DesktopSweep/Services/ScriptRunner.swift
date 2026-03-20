import Foundation

final class ScriptRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false

    private var task: Process?

    private var scriptPath: String {
        let installed = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("scripts/archive-desktop.sh").path

        if FileManager.default.fileExists(atPath: installed) {
            return installed
        }
        return Bundle.main.url(forResource: "archive-desktop", withExtension: "sh")?.path ?? installed
    }

    func run(dryRun: Bool = false) {
        guard !isRunning else { return }
        isRunning = true
        output = ""

        let path = scriptPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            let pipe = Pipe()

            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = dryRun ? [path, "--dry-run"] : [path]
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    self?.output = result
                    self?.isRunning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.output = "Error: \(error.localizedDescription)"
                    self?.isRunning = false
                }
            }
        }
    }
}
