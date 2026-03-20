import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: SweepConfig
    @ObservedObject var scriptRunner: ScriptRunner

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            statusSection
            scheduleSection
            rulesSection
            optionsSection
            actionsSection
            kofiSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(maxHeight: NSScreen.main.map { $0.visibleFrame.height * 0.75 } ?? 700)
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            Toggle("Enable Desktop Sweep", isOn: $config.enabled)
                .onChange(of: config.enabled) { newValue in
                    if newValue {
                        LaunchdManager.install(hour: config.scheduleHour, minute: config.scheduleMinute)
                    } else {
                        LaunchdManager.unload()
                    }
                }
            LabeledContent("Last run") {
                Text(config.lastRunInfo)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section("Schedule") {
            HStack {
                Text("Run daily at")
                Spacer()
                Picker("", selection: $config.scheduleHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 70)
                Text(":")
                Picker("", selection: $config.scheduleMinute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 70)
            }
            .onChange(of: config.scheduleHour) { _ in reinstallSchedule() }
            .onChange(of: config.scheduleMinute) { _ in reinstallSchedule() }
        }
    }

    // MARK: - Rules

    private var rulesSection: some View {
        Section("Rules") {
            HStack {
                Text("Keep files newer than")
                Spacer()
                TextField("", text: Binding(
                    get: { String(config.ageThresholdDays) },
                    set: { newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(3))
                        config.ageThresholdDays = min(Int(filtered) ?? 0, 365)
                    }
                ))
                    .frame(width: 48)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: $config.ageThresholdDays, in: 0...365)
                    .labelsHidden()
                Text(config.ageThresholdDays == 1 ? "day" : "days")
                    .foregroundStyle(.secondary)
            }

            SkipListEditor(
                title: "Skip these files",
                items: $config.skipFiles,
                placeholder: "filename.txt"
            )

            SkipListEditor(
                title: "Skip these file extensions",
                items: $config.skipExtensions,
                placeholder: "pdf"
            )
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Write log file", isOn: $config.logEnabled)
            Toggle("Show in menu bar", isOn: $config.showInMenuBar)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section("Actions") {
            HStack(spacing: 12) {
                Button("Run Now") { scriptRunner.run(dryRun: false) }
                    .disabled(scriptRunner.isRunning)
                Button("Dry Run") { scriptRunner.run(dryRun: true) }
                    .disabled(scriptRunner.isRunning)
                if scriptRunner.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }

            if !scriptRunner.output.isEmpty {
                ScrollView {
                    Text(scriptRunner.output)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Ko-fi

    private var kofiSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Text("Enjoying Desktop Sweep?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Link(destination: URL(string: "https://ko-fi.com/axiomfolly")!) {
                        HStack(spacing: 6) {
                            Text("☕")
                            Text("Buy me a coffee")
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func reinstallSchedule() {
        guard config.enabled else { return }
        LaunchdManager.install(hour: config.scheduleHour, minute: config.scheduleMinute)
    }
}
