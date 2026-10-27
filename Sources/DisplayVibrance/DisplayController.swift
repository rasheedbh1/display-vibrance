import Foundation
import AppKit
import CoreGraphics
@preconcurrency import ColorSync
import IOKit

struct DisplayInfo { let id: CGDirectDisplayID; let name: String; let profileURL: URL }

enum DisplayError: LocalizedError {
    case noDisplay, noProfile, unsupportedProfile, writeFailed, applyFailed
    var errorDescription: String? {
        switch self {
        case .noDisplay: "No active external display was found."
        case .noProfile: "The active display has no readable ColorSync profile."
        case .unsupportedProfile: "This display profile does not contain editable RGB colorants."
        case .writeFailed: "The derived ColorSync profile could not be saved."
        case .applyFailed: "macOS did not accept the derived display profile."
        }
    }
}

@MainActor
final class DisplayController {
    private var display: DisplayInfo?
    private var originalData: Data?
    private var originalGamma: ([CGGammaValue], [CGGammaValue], [CGGammaValue])?
    private let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DisplayVibrance", isDirectory: true)

    func refresh() throws -> DisplayInfo {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        guard let id = ids.first(where: { CGDisplayIsBuiltin($0) == 0 }) ?? ids.first else { throw DisplayError.noDisplay }
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }),
              let colorSpace = screen.colorSpace,
              let data = colorSpace.iccProfileData else { throw DisplayError.noProfile }

        let name = screen.localizedName
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let backup = support.appendingPathComponent("Original-\(id).icc")
        if !FileManager.default.fileExists(atPath: backup.path) { try data.write(to: backup, options: .atomic) }
        originalData = (try? Data(contentsOf: backup)) ?? data
        originalGamma = readGamma(id)
        let info = DisplayInfo(id: id, name: name, profileURL: backup)
        display = info
        return info
    }

    func apply(saturation: Double, vibrance: Double, gamma: Double) throws {
        guard let display, let base = originalData else { _ = try refresh(); return try apply(saturation: saturation, vibrance: vibrance, gamma: gamma) }
        // A display profile maps device RGB to the profile connection space. Contracting
        // its declared chroma makes ColorSync drive the real primaries farther from gray.
        // Vibrance receives a gentler, bounded contribution to protect already vivid colors.
        let adaptive = 1 + (saturation - 1) + vibrance * 0.45
        let contraction = 1 / max(0.55, min(1.8, adaptive))
        var profile = try ICCProfile(data: base)
        try profile.contractColorants(by: contraction)
        profile.rename("Display Vibrance S\(Int(saturation * 100)) V\(Int(vibrance * 100))")
        let url = support.appendingPathComponent("Active-\(display.id).icc")
        do { try profile.data.write(to: url, options: .atomic) } catch { throw DisplayError.writeFailed }
        guard setProfile(url, for: display.id) else { throw DisplayError.applyFailed }
        applyGamma(gamma, to: display.id)
    }

    func restore() throws {
        guard let display, let base = originalData else { _ = try refresh(); return try restore() }
        let url = support.appendingPathComponent("Original-\(display.id).icc")
        if !FileManager.default.fileExists(atPath: url.path) { try base.write(to: url, options: .atomic) }
        guard setProfile(url, for: display.id) else { throw DisplayError.applyFailed }
        if let g = originalGamma { _ = CGSetDisplayTransferByTable(display.id, UInt32(g.0.count), g.0, g.1, g.2) }
        else { CGDisplayRestoreColorSyncSettings() }
    }

    private func setProfile(_ url: URL, for id: CGDirectDisplayID) -> Bool {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return false }
        guard let defaultKey = kColorSyncDeviceDefaultProfileID?.takeUnretainedValue(),
              let displayClass = kColorSyncDisplayDeviceClass?.takeUnretainedValue() else { return false }
        let settings: [CFString: Any] = [defaultKey: url as CFURL]
        return ColorSyncDeviceSetCustomProfiles(displayClass, uuid, settings as CFDictionary)
    }

    private func readGamma(_ id: CGDirectDisplayID) -> ([CGGammaValue], [CGGammaValue], [CGGammaValue])? {
        let capacity = Int(CGDisplayGammaTableCapacity(id)); guard capacity > 0 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: capacity), g = r, b = r, count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, UInt32(capacity), &r, &g, &b, &count) == .success else { return nil }
        return (Array(r.prefix(Int(count))), Array(g.prefix(Int(count))), Array(b.prefix(Int(count))))
    }

    private func applyGamma(_ gamma: Double, to id: CGDirectDisplayID) {
        let count = max(256, Int(CGDisplayGammaTableCapacity(id)))
        let exponent = 1 / max(0.7, min(1.5, gamma))
        let table = (0..<count).map { CGGammaValue(pow(Double($0) / Double(count - 1), exponent)) }
        _ = CGSetDisplayTransferByTable(id, UInt32(count), table, table, table)
    }
}
