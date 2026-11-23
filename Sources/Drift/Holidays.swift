import Foundation

/// Holidays that can swap in their own wallpapers. Each can be turned on or off in Settings.
/// The `key` matches the wallpaper file names: holiday_<key>_01.jpg.
enum Holiday: String, CaseIterable, Identifiable {
    case newyear, valentines, easter, ramadan, bajram, kurbanbajram, halloween, christmas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newyear: return "New Year"
        case .valentines: return "Valentine's Day"
        case .easter: return "Easter"
        case .ramadan: return "Ramadan"
        case .bajram: return "Ramazanski Bajram (Eid al-Fitr)"
        case .kurbanbajram: return "Kurban Bajram (Eid al-Adha)"
        case .halloween: return "Halloween"
        case .christmas: return "Christmas"
        }
    }

    /// Image key to fall back to when this holiday has no images of its own.
    var fallbackKey: String? { self == .kurbanbajram ? Holiday.bajram.rawValue : nil }

    /// Is `date` inside this holiday's window?
    func contains(_ date: Date) -> Bool {
        let greg = Calendar(identifier: .gregorian)
        let c = greg.dateComponents([.year, .month, .day], from: date)
        guard let year = c.year, let month = c.month, let day = c.day else { return false }

        switch self {
        case .newyear:
            return (month == 12 && day == 31) || (month == 1 && day <= 2)
        case .valentines:
            return month == 2 && (13...14).contains(day)
        case .halloween:
            return month == 10 && (29...31).contains(day)
        case .christmas:
            return month == 12 && (20...27).contains(day)
        case .easter:
            // Good Friday to Easter Monday.
            guard let easter = Holiday.westernEaster(year: year) else { return false }
            let diff = greg.dateComponents([.day], from: greg.startOfDay(for: easter), to: greg.startOfDay(for: date)).day ?? 99
            return (-2...1).contains(diff)
        case .ramadan, .bajram, .kurbanbajram:
            let hijri = Calendar(identifier: .islamicUmmAlQura)
            let h = hijri.dateComponents([.month, .day], from: date)
            guard let hm = h.month, let hd = h.day else { return false }
            switch self {
            case .ramadan: return hm == 9
            case .bajram: return hm == 10 && hd <= 3
            default: return hm == 12 && (10...13).contains(hd)
            }
        }
    }

    /// The holiday that applies today among the enabled ones (the first match wins).
    static func current(on date: Date = Date(), enabled: Set<Holiday>) -> Holiday? {
        // Bajram before Ramadan so the last days of Ramadan don't hide it.
        let order: [Holiday] = [.bajram, .kurbanbajram, .christmas, .newyear, .easter, .valentines, .halloween, .ramadan]
        return order.first { enabled.contains($0) && $0.contains(date) }
    }

    /// Anonymous Gregorian algorithm for Western Easter Sunday.
    static func westernEaster(year: Int) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }
}
