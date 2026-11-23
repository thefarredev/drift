import AppKit

// MARK: - What the sky is doing

/// Weather for picking a wallpaper. File names start with the raw value: snow_night_01.jpg.
enum WallpaperCondition: String, CaseIterable {
    case snow, rain, storm, fog, cloudy, clear

    /// From a MET Norway symbol code, e.g. "lightsnowshowers_night" or "partlycloudy_day".
    init(symbol: String) {
        switch true {
        case symbol.contains("thunder"): self = .storm
        case symbol.contains("snow") || symbol.contains("sleet"): self = .snow
        case symbol.contains("rain"): self = .rain
        case symbol.contains("fog"): self = .fog
        case symbol.hasPrefix("cloudy"): self = .cloudy
        default: self = .clear      // clearsky, fair, partlycloudy
        }
    }

    init(scene: WeatherScene) {
        switch scene {
        case .snow: self = .snow
        case .rain: self = .rain
        case .clear: self = .clear
        }
    }

    /// Which conditions to try, in order, when there are no images for this one.
    var fallbacks: [WallpaperCondition] {
        switch self {
        case .snow: return [.snow, .cloudy, .clear]
        case .rain: return [.rain, .storm, .cloudy, .clear]
        case .storm: return [.storm, .rain, .cloudy, .clear]
        case .fog: return [.fog, .cloudy, .clear]
        case .cloudy: return [.cloudy, .fog, .clear]
        case .clear: return [.clear, .cloudy]
        }
    }
}

/// Part of the day. File names use the raw value after the condition: clear_dusk_01.jpg.
enum TimeOfDay: String, CaseIterable {
    case morning, day, dusk, night

    /// Nearby times to try when there is no image for this one.
    var fallbacks: [TimeOfDay] {
        switch self {
        case .morning: return [.morning, .day, .dusk]
        case .day: return [.day, .morning, .dusk]
        case .dusk: return [.dusk, .night, .morning]
        case .night: return [.night, .dusk]
        }
    }

    /// From real sunrise and sunset when the location is known, otherwise from the clock.
    static func now(latitude: Double?, longitude: Double?, date: Date = Date()) -> TimeOfDay {
        if let lat = latitude, let lon = longitude, let sun = SunTimes(date: date, latitude: lat, longitude: lon) {
            let hour: TimeInterval = 3600
            if date < sun.sunrise.addingTimeInterval(-0.5 * hour) || date > sun.sunset.addingTimeInterval(0.75 * hour) { return .night }
            if date < sun.sunrise.addingTimeInterval(2 * hour) { return .morning }
            if date > sun.sunset.addingTimeInterval(-1.25 * hour) { return .dusk }
            return .day
        }
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case 6..<9: return .morning
        case 9..<17: return .day
        case 17..<20: return .dusk
        default: return .night
        }
    }
}

/// Season, from the month (flipped south of the equator). File names: winter_clear_day_01.jpg, autumn_01.jpg.
enum Season: String, CaseIterable {
    case winter, spring, summer, autumn

    static func now(latitude: Double?, date: Date = Date()) -> Season {
        let month = Calendar.current.component(.month, from: date)
        var s: Season
        switch month {
        case 3...5: s = .spring
        case 6...8: s = .summer
        case 9...11: s = .autumn
        default: s = .winter
        }
        if let latitude, latitude < 0 {
            s = [.summer, .autumn, .winter, .spring][Season.allCases.firstIndex(of: s)!]
        }
        return s
    }
}

/// Sunrise and sunset for a day and place (NOAA's simplified solar position formulas).
struct SunTimes {
    let sunrise: Date
    let sunset: Date

    init?(date: Date, latitude: Double, longitude: Double) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let dayStart = utc.startOfDay(for: date)
        let n = Double(utc.ordinality(of: .day, in: .year, for: date) ?? 1)

        let gamma = 2 * Double.pi / 365 * (n - 1)
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
                               - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let latR = latitude * .pi / 180
        let cosH = cos(90.833 * .pi / 180) / (cos(latR) * cos(decl)) - tan(latR) * tan(decl)
        guard cosH >= -1, cosH <= 1 else { return nil }     // polar day or night
        let ha = acos(cosH) * 180 / .pi
        let riseMinutes = 720 - 4 * (longitude + ha) - eqTime
        let setMinutes = 720 - 4 * (longitude - ha) - eqTime
        sunrise = dayStart.addingTimeInterval(riseMinutes * 60)
        sunset = dayStart.addingTimeInterval(setMinutes * 60)
    }
}

// MARK: - Images on disk

/// Finds wallpapers in a folder by file name:
///   <condition>_<time>_NN.jpg   e.g. snow_night_01.jpg
///   <condition>_NN.jpg          any time of day, e.g. fog_01.jpg, storm_02.png
///   holiday_<key>_NN.jpg        e.g. holiday_christmas_01.jpg
///   <season>_<condition>_<time>_NN.jpg, <season>_<condition>_NN.jpg   e.g. winter_clear_day_01.jpg
///   <season>_NN.jpg             clear and cloudy days in that season, e.g. autumn_01.jpg
struct WallpaperLibrary {
    private(set) var byKey: [String: [URL]] = [:]

    init(folder: URL) {
        let exts: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff", "webp"]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for url in files where exts.contains(url.pathExtension.lowercased()) {
            // Drop the trailing number: "snow_night_01" → "snow_night"
            var parts = url.deletingPathExtension().lastPathComponent.lowercased().split(separator: "_").map(String.init)
            if let last = parts.last, Int(last) != nil { parts.removeLast() }
            guard !parts.isEmpty else { continue }
            byKey[parts.joined(separator: "_"), default: []].append(url)
        }
    }

    var isEmpty: Bool { byKey.isEmpty }
    var count: Int { byKey.values.reduce(0) { $0 + $1.count } }

    /// Best matching images, most specific first.
    func candidates(condition: WallpaperCondition, time: TimeOfDay, holiday: Holiday?, season: Season) -> [URL] {
        if let holiday {
            if let urls = byKey["holiday_\(holiday.rawValue)"], !urls.isEmpty { return urls }
            if let key = holiday.fallbackKey, let urls = byKey["holiday_\(key)"], !urls.isEmpty { return urls }
        }
        // Images made for this season and weather, e.g. winter_clear_day_01.jpg.
        for t in time.fallbacks {
            if let urls = byKey["\(season.rawValue)_\(condition.rawValue)_\(t.rawValue)"], !urls.isEmpty { return urls }
        }
        if let urls = byKey["\(season.rawValue)_\(condition.rawValue)"], !urls.isEmpty { return urls }
        let calm = condition == .clear || condition == .cloudy
        // A general season image, e.g. autumn_01.jpg, on calm days.
        if calm, let urls = byKey[season.rawValue], !urls.isEmpty { return urls }
        // Calm winter days with no winter images: a snowy landscape fits better than a summer one.
        if calm, season == .winter {
            for t in time.fallbacks {
                if let urls = byKey["snow_\(t.rawValue)"], !urls.isEmpty { return urls }
            }
        }
        for c in condition.fallbacks {
            for t in time.fallbacks {
                if let urls = byKey["\(c.rawValue)_\(t.rawValue)"], !urls.isEmpty { return urls }
            }
            if let urls = byKey[c.rawValue], !urls.isEmpty { return urls }
        }
        // Anything that isn't a holiday image.
        let seasonal = Set(Season.allCases.map(\.rawValue))
        return byKey.filter { key, _ in
            !key.hasPrefix("holiday_") && !seasonal.contains(String(key.split(separator: "_")[0]))
        }.flatMap(\.value)
    }
}

// MARK: - Placeholders

/// Simple painted skies used until real wallpapers are added, so the feature works right away.
enum PlaceholderSky {
    static func image(condition: WallpaperCondition, time: TimeOfDay, holiday: Holiday?) -> URL? {
        let key = holiday.map { "holiday_\($0.rawValue)" } ?? "\(condition.rawValue)_\(time.rawValue)"
        // Kept inside the project next to the real wallpapers (git-ignored; recreated when missing).
        let dir = AppSettings.defaultWallpaperFolder.deletingLastPathComponent()
            .appendingPathComponent("Placeholders", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(key)_v1.png")
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let size = NSSize(width: 2560, height: 1600)
        let (top, bottom) = colors(condition: condition, time: time, holiday: holiday)
        let image = NSImage(size: size, flipped: false) { rect in
            NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
            // A soft sun or moon, unless the sky is overcast.
            if condition == .clear || holiday != nil {
                let glow = time == .night ? NSColor(white: 1, alpha: 0.85) : NSColor(calibratedRed: 1, green: 0.95, blue: 0.8, alpha: 0.9)
                let r: CGFloat = time == .night ? 60 : 110
                let centre = NSPoint(x: rect.width * 0.72, y: rect.height * (time == .day ? 0.72 : 0.42))
                NSGradient(starting: glow, ending: glow.withAlphaComponent(0))?
                    .draw(fromCenter: centre, radius: 0, toCenter: centre, radius: r * 3, options: [])
                glow.setFill()
                NSBezierPath(ovalIn: NSRect(x: centre.x - r / 2, y: centre.y - r / 2, width: r, height: r)).fill()
            }
            // Two layers of soft hills along the bottom.
            for (i, shade) in [CGFloat(0.18), 0.32].enumerated() {
                let hills = NSBezierPath()
                hills.move(to: NSPoint(x: 0, y: 0))
                var x: CGFloat = 0
                let base = rect.height * (0.16 - CGFloat(i) * 0.06)
                while x <= rect.width {
                    let y = base + sin(x / (380 - CGFloat(i) * 90) + CGFloat(i) * 2) * 40 + sin(x / 170) * 12
                    hills.line(to: NSPoint(x: x, y: y))
                    x += 20
                }
                hills.line(to: NSPoint(x: rect.width, y: 0))
                hills.close()
                let ground = condition == .snow ? NSColor(white: 0.97 - shade * 0.25, alpha: 1)
                                                : bottom.blended(withFraction: 0.45 + shade, of: .black) ?? .black
                ground.setFill()
                hills.fill()
            }
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        try? png.write(to: url)
        return url
    }

    private static func colors(condition: WallpaperCondition, time: TimeOfDay, holiday: Holiday?) -> (NSColor, NSColor) {
        func c(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
            NSColor(calibratedRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        }
        if let holiday {
            switch holiday {
            case .christmas: return (c(20, 40, 70), c(150, 40, 50))
            case .newyear: return (c(10, 10, 40), c(80, 40, 120))
            case .halloween: return (c(30, 15, 50), c(230, 110, 30))
            case .valentines: return (c(250, 180, 200), c(255, 230, 220))
            case .easter: return (c(170, 220, 255), c(220, 245, 200))
            case .ramadan, .bajram, .kurbanbajram: return (c(20, 30, 70), c(230, 170, 90))
            }
        }
        switch (condition, time) {
        case (_, .night): return condition == .clear ? (c(8, 12, 35), c(35, 50, 95)) : (c(20, 24, 35), c(55, 60, 75))
        case (.clear, .morning): return (c(120, 170, 230), c(255, 200, 150))
        case (.clear, .day): return (c(70, 140, 230), c(185, 220, 255))
        case (.clear, .dusk): return (c(60, 70, 150), c(250, 140, 100))
        case (.snow, _): return (c(170, 185, 205), c(235, 240, 248))
        case (.rain, _), (.storm, _): return (c(70, 80, 95), c(140, 150, 160))
        case (.fog, _): return (c(185, 190, 195), c(225, 228, 230))
        case (.cloudy, _): return (c(130, 145, 165), c(200, 208, 218))
        }
    }
}

// MARK: - Manager

/// Sets the desktop wallpaper of every screen to match the weather, time of day and holiday,
/// rotates through matching images, and puts your own wallpaper back when turned off or quit.
final class WallpaperManager {
    var enabled = false { didSet { enabled ? refresh(force: true) : restoreOriginals() } }
    var folder: URL { didSet { reloadLibrary(); refresh(force: true) } }
    var rotateMinutes = 30 { didSet { scheduleRotation() } }
    var enabledHolidays: Set<Holiday> = Set(Holiday.allCases) { didSet { refresh(force: false) } }

    private(set) var library: WallpaperLibrary
    private(set) var currentDescription = ""
    private var condition: WallpaperCondition = .clear
    private var latitude: Double?
    private var longitude: Double?
    private var lastKey = ""
    private var current: [String: URL] = [:]
    private var rotationTimer: Timer?
    private var tickTimer: Timer?
    private let originalsKey = "originalWallpapers"

    init(folder: URL) {
        self.folder = folder
        library = WallpaperLibrary(folder: folder)
        // Re-check every 5 minutes so dawn, dusk and holidays switch on time.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.reloadLibrary()
            self?.refresh(force: false)
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.refresh(force: true) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in self?.applyCurrentToAllScreens() }
    }

    /// New weather from the forecast (or a fixed scene from the menu).
    func update(condition: WallpaperCondition, latitude: Double?, longitude: Double?) {
        self.condition = condition
        if let latitude { self.latitude = latitude }
        if let longitude { self.longitude = longitude }
        refresh(force: false)
    }

    /// "Next wallpaper" from the menu.
    func next() {
        reloadLibrary()
        refresh(force: true)
    }

    func reloadLibrary() { library = WallpaperLibrary(folder: folder) }

    /// Picks new images when the situation changed (or when forced), otherwise leaves them.
    private func refresh(force: Bool) {
        guard enabled else { return }
        saveOriginalsIfNeeded()
        let time = TimeOfDay.now(latitude: latitude, longitude: longitude)
        let holiday = Holiday.current(enabled: enabledHolidays)
        let season = Season.now(latitude: latitude)
        let key = "\(season.rawValue)_\(condition.rawValue)_\(time.rawValue)_\(holiday?.rawValue ?? "")"
        guard force || key != lastKey || current.isEmpty else { return }
        lastKey = key

        let candidates = library.candidates(condition: condition, time: time, holiday: holiday, season: season)
        currentDescription = [holiday?.title, season.rawValue.capitalized, condition.rawValue, time.rawValue].compactMap { $0 }.joined(separator: " · ")

        for screen in NSScreen.screens {
            let id = screenID(screen)
            let url: URL?
            if candidates.isEmpty {
                url = PlaceholderSky.image(condition: condition, time: time, holiday: holiday)
            } else {
                // A different image than the one showing now, when there's a choice.
                let fresh = candidates.filter { $0 != current[id] }
                url = (fresh.isEmpty ? candidates : fresh).randomElement()
            }
            if let url { set(url, on: screen) }
        }
        scheduleRotation()
    }

    private func set(_ url: URL, on screen: NSScreen) {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
            current[screenID(screen)] = url
        } catch {
            NSLog("Drift: couldn't set wallpaper: \(error.localizedDescription)")
        }
    }

    /// macOS sets wallpapers per Space; re-apply when you switch Spaces so every one matches.
    private func applyCurrentToAllScreens() {
        guard enabled else { return }
        for screen in NSScreen.screens {
            if let url = current[screenID(screen)], NSWorkspace.shared.desktopImageURL(for: screen) != url {
                set(url, on: screen)
            }
        }
    }

    private func scheduleRotation() {
        rotationTimer?.invalidate()
        guard enabled, rotateMinutes > 0 else { return }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(rotateMinutes * 60), repeats: true) { [weak self] _ in
            self?.refresh(force: true)
        }
    }

    // MARK: Your own wallpaper

    /// Remember each screen's wallpaper the first time Drift takes over.
    private func saveOriginalsIfNeeded() {
        var saved = UserDefaults.standard.dictionary(forKey: originalsKey) as? [String: String] ?? [:]
        var changed = false
        for screen in NSScreen.screens {
            let id = screenID(screen)
            guard saved[id] == nil, let url = NSWorkspace.shared.desktopImageURL(for: screen),
                  !url.path.hasPrefix(folder.path), !url.path.contains("/Assets/Placeholders/") else { continue }
            saved[id] = url.absoluteString
            changed = true
        }
        if changed { UserDefaults.standard.set(saved, forKey: originalsKey) }
    }

    /// Put back the wallpapers you had before Drift.
    func restoreOriginals() {
        rotationTimer?.invalidate()
        let saved = UserDefaults.standard.dictionary(forKey: originalsKey) as? [String: String] ?? [:]
        for screen in NSScreen.screens {
            guard let s = saved[screenID(screen)], let url = URL(string: s) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
        UserDefaults.standard.removeObject(forKey: originalsKey)
        current.removeAll()
        lastKey = ""
    }

    private func screenID(_ screen: NSScreen) -> String {
        if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           let uuid = CGDisplayCreateUUIDFromDisplayID(n.uint32Value)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return screen.localizedName
    }
}
