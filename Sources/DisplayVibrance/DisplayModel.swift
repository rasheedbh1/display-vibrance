import AppKit
import CoreGraphics
import ServiceManagement

enum DisplayPreset: String, CaseIterable, Identifiable {
    case original = "Original", vivid = "Vivid", gaming = "Gaming", cinema = "Cinema"
    var id: String { rawValue }
}

@MainActor
final class DisplayModel: ObservableObject {
    @Published var saturation = UserDefaults.standard.double(forKey: "saturation").nonzero(or: 100)
    @Published var vibrance = UserDefaults.standard.double(forKey: "vibrance")
    @Published var gamma = UserDefaults.standard.double(forKey: "gamma").nonzero(or: 100)
    @Published var preset: DisplayPreset = .original
    @Published var launchAtLogin = false
    @Published var reapplyAfterWake = UserDefaults.standard.object(forKey: "wake") as? Bool ?? true
    @Published private(set) var displayName = "Detecting display…"
    @Published private(set) var status = "Starting"
    @Published private(set) var hasError = false

    private let controller = DisplayController()
    private var previewTask: Task<Void, Never>?

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refresh()
        autoApplyOnLaunch()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in if self?.reapplyAfterWake == true { self?.commit() } }
        }
        CGDisplayRegisterReconfigurationCallback({ _, _, context in
            guard let context else { return }
            let model = Unmanaged<DisplayModel>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in model.refresh(); model.autoApplyOnLaunch() }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    // Apply saved non-neutral settings automatically so the vibrance is active as
    // soon as the app launches (e.g. at login) or a display reconnects — no UI
    // interaction required. Neutral settings are skipped to leave colors untouched.
    func autoApplyOnLaunch() {
        guard !hasError else { return }
        let isNeutral = saturation == 100 && vibrance == 0 && gamma == 100
        guard !isNeutral else { return }
        schedulePreview()
    }

    func refresh() {
        do {
            let info = try controller.refresh()
            displayName = info.name
            status = "Ready • original profile backed up"
            hasError = false
        } catch { fail(error) }
    }

    func schedulePreview() {
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.commit()
        }
    }

    func commit() {
        do {
            try controller.apply(saturation: saturation / 100, vibrance: vibrance / 100, gamma: gamma / 100)
            UserDefaults.standard.set(saturation, forKey: "saturation")
            UserDefaults.standard.set(vibrance, forKey: "vibrance")
            UserDefaults.standard.set(gamma, forKey: "gamma")
            UserDefaults.standard.set(reapplyAfterWake, forKey: "wake")
            status = "Applied"
            hasError = false
            fputs("DisplayVibrance: applied saturation=\(saturation) vibrance=\(vibrance) gamma=\(gamma)\n", stderr)
        } catch { fail(error) }
    }

    func reset() {
        previewTask?.cancel()
        do {
            try controller.restore()
            saturation = 100; vibrance = 0; gamma = 100; preset = .original
            status = "Original profile restored"
            hasError = false
        } catch { fail(error) }
    }

    func apply(_ preset: DisplayPreset) {
        switch preset {
        case .original: saturation = 100; vibrance = 0; gamma = 100
        case .vivid: saturation = 135; vibrance = 45; gamma = 100
        case .gaming: saturation = 125; vibrance = 30; gamma = 97
        case .cinema: saturation = 115; vibrance = 20; gamma = 103
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do { enabled ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
        catch { fail(error) }
    }

    func openDisplaySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!)
    }

    private func fail(_ error: Error) { status = error.localizedDescription; hasError = true }
}

private extension Double {
    func nonzero(or fallback: Double) -> Double { self == 0 ? fallback : self }
}
