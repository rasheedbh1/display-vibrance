import SwiftUI
import AppKit

@main
struct DisplayVibranceApp: App {
    @StateObject private var model = DisplayModel()

    var body: some Scene {
        WindowGroup("Display Vibrance") {
            ControlPanel(model: model)
                .frame(minWidth: 380, minHeight: 440)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Display Vibrance", systemImage: "circle.lefthalf.filled") {
            ControlPanel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ControlPanel: View {
    @ObservedObject var model: DisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "display")
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName).font(.headline)
                    Text(model.status).font(.caption).foregroundStyle(model.hasError ? .red : .secondary)
                }
                Spacer()
            }

            Divider()
            slider("Saturation", value: $model.saturation, range: 0...175, suffix: "%")
            slider("Vibrance", value: $model.vibrance, range: -100...100, suffix: "")
            slider("Gamma", value: $model.gamma, range: 70...150, suffix: "%")

            Picker("Preset", selection: $model.preset) {
                ForEach(DisplayPreset.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: model.preset) { _, preset in model.apply(preset) }

            HStack {
                Button("Reset to Original") { model.reset() }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                Spacer()
                Button("Apply") { model.commit() }.buttonStyle(.borderedProminent)
            }

            Toggle("Launch at Login", isOn: $model.launchAtLogin)
                .onChange(of: model.launchAtLogin) { _, enabled in model.setLaunchAtLogin(enabled) }
            Toggle("Reapply After Wake", isOn: $model.reapplyAfterWake)

            Divider()
            HStack {
                Button("Open Color Profile Settings") { model.openDisplaySettings() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }.font(.caption)
        }
        .padding(16)
        .frame(width: 380)
        .onChange(of: model.saturation) { _, _ in model.schedulePreview() }
        .onChange(of: model.vibrance) { _, _ in model.schedulePreview() }
        .onChange(of: model.gamma) { _, _ in model.schedulePreview() }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(spacing: 4) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue))\(suffix)").monospacedDigit() }
            Slider(value: value, in: range)
        }
    }
}
