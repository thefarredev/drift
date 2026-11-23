import Foundation
import Combine

/// What the overlay is currently drawing.
enum WeatherScene: String, CaseIterable, Identifiable {
    case snow, rain, clear
    var id: String { rawValue }
    var title: String {
        switch self {
        case .snow: return "Snow"
        case .rain: return "Rain"
        case .clear: return "Clear"
        }
    }
}

/// Where the scene comes from: the live forecast, or a fixed choice.
enum SceneSource: String, CaseIterable, Identifiable {
    case live, snow, rain, clear
    var id: String { rawValue }
    var title: String {
        switch self {
        case .live: return "Follow the weather"
        case .snow: return "Always snow"
        case .rain: return "Always rain"
        case .clear: return "Clear"
        }
    }
}

enum Intensity: String, CaseIterable, Identifiable {
    case light, medium, heavy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// Particles spawned per second, per 1000pt of screen width.
    var spawnRate: Double {
        switch self {
        case .light: return 18
        case .medium: return 45
        case .heavy: return 100
        }
    }
}

/// App-wide settings, persisted in UserDefaults. Observed by both AppKit code and SwiftUI.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var source: SceneSource { didSet { d.set(source.rawValue, forKey: "source") } }
    @Published var intensity: Intensity { didSet { d.set(intensity.rawValue, forKey: "intensity") } }
    @Published var city: String { didSet { d.set(city, forKey: "city") } }
    @Published var paused: Bool { didSet { d.set(paused, forKey: "paused") } }
    @Published var settleOnWindows: Bool { didSet { d.set(settleOnWindows, forKey: "settleOnWindows") } }
    @Published var moments: MomentFrequency { didSet { d.set(moments.rawValue, forKey: "moments") } }
    @Published var wallpaperEnabled: Bool { didSet { d.set(wallpaperEnabled, forKey: "wallpaperEnabled") } }
    @Published var wallpaperFolder: URL { didSet { d.set(wallpaperFolder.path, forKey: "wallpaperFolder") } }
    @Published var rotateMinutes: Int { didSet { d.set(rotateMinutes, forKey: "rotateMinutes") } }
    @Published var disabledHolidays: Set<String> { didSet { d.set(Array(disabledHolidays), forKey: "disabledHolidays") } }

    var enabledHolidays: Set<Holiday> { Set(Holiday.allCases.filter { !disabledHolidays.contains($0.rawValue) }) }

    /// All project assets live in the project folder: <project>/Assets/Wallpapers.
    /// Worked out from this source file's location, so it follows the project wherever it is.
    static let defaultWallpaperFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // Sources/Drift
        .deletingLastPathComponent()      // Sources
        .deletingLastPathComponent()      // project root
        .appendingPathComponent("Assets/Wallpapers", isDirectory: true)

    private init() {
        source = SceneSource(rawValue: d.string(forKey: "source") ?? "") ?? .snow
        intensity = Intensity(rawValue: d.string(forKey: "intensity") ?? "") ?? .medium
        city = d.string(forKey: "city") ?? ""
        paused = d.bool(forKey: "paused")
        settleOnWindows = d.object(forKey: "settleOnWindows") as? Bool ?? true
        moments = MomentFrequency(rawValue: d.string(forKey: "moments") ?? "") ?? .sometimes
        wallpaperEnabled = d.object(forKey: "wallpaperEnabled") as? Bool ?? true
        wallpaperFolder = d.string(forKey: "wallpaperFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? AppSettings.defaultWallpaperFolder
        rotateMinutes = d.object(forKey: "rotateMinutes") as? Int ?? 30
        disabledHolidays = Set(d.stringArray(forKey: "disabledHolidays") ?? [])
    }
}
