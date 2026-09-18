import Foundation

/// Client-side port of `lib/events.ts#occurrences`. Occurrence strings are wall-clock
/// Eastern times in `yyyy-MM-dd'T'HH:mm` form, exactly what the RSVP API expects.
nonisolated enum Occurrences {
    static let zone = TimeZone(identifier: "America/New_York")!

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    static let wallClock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()

    static func date(from wall: String) -> Date? {
        wallClock.date(from: wall)
    }

    static func upcoming(for e: Entity, from now: Date = Date(), count: Int = 4) -> [String] {
        guard e.status == .active, let start = date(from: e.start) else { return [] }
        if let server = e.upcoming { return Array(server.prefix(count)) }
        let cal = calendar
        let r = e.recurrence
        let horizon = now.addingTimeInterval(730 * 86_400)
        let until: Date? = r.until.isEmpty ? nil : date(from: r.until + "T23:59")
        let cancelled = Set(e.overrides.filter(\.cancelled).map(\.date))
        var out: [String] = []

        func consider(_ d: Date) -> Bool {
            if d > horizon { return false }
            if let until, d > until { return false }
            if d < now { return true }
            if !r.months.isEmpty, !r.months.contains(cal.component(.month, from: d)) { return true }
            let s = wallClock.string(from: d)
            if cancelled.contains(String(s.prefix(10))) { return true }
            out.append(s)
            return out.count < count
        }

        switch r.frequency {
        case "weekly":
            var i = 0
            while i < 6000 {
                guard let d = cal.date(byAdding: .day, value: 7 * max(1, r.interval) * i, to: start) else { break }
                if !consider(d) { break }
                i += 1
            }
        case "monthly":
            var i = 0
            while i < 1200 {
                guard let d = cal.date(byAdding: .month, value: max(1, r.interval) * i, to: start) else { break }
                if !consider(d) { break }
                i += 1
            }
        case "nth-weekday":
            var i = 0
            let time = cal.dateComponents([.hour, .minute], from: start)
            while i < 1200 {
                guard let monthStart = cal.date(byAdding: .month, value: max(1, r.interval) * i, to: cal.date(from: cal.dateComponents([.year, .month], from: start))!) else { break }
                i += 1
                if let d = nthWeekday(of: monthStart, weekday: r.weekday, nth: r.nth, hour: time.hour ?? 0, minute: time.minute ?? 0, cal: cal) {
                    if d < start { continue }
                    if !consider(d) { break }
                } else if monthStart > horizon {
                    break
                }
            }
        default:
            _ = consider(start)
        }
        return out
    }

    /// `weekday` is 0 = Monday … 6 = Sunday (rrule order).
    private static func nthWeekday(of monthStart: Date, weekday: Int, nth: Int, hour: Int, minute: Int, cal: Calendar) -> Date? {
        let targetWeekday = ((weekday + 1) % 7) + 1 // Calendar: 1 = Sunday … 7 = Saturday
        let firstWeekday = cal.component(.weekday, from: monthStart)
        var offset = (targetWeekday - firstWeekday + 7) % 7
        offset += (max(1, nth) - 1) * 7
        guard let day = cal.date(byAdding: .day, value: offset, to: monthStart) else { return nil }
        guard cal.component(.month, from: day) == cal.component(.month, from: monthStart) else { return nil }
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    // MARK: Display helpers

    static func display(_ wall: String, _ format: String) -> String {
        guard let d = date(from: wall) else { return wall }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = zone
        f.dateFormat = format
        return f.string(from: d)
    }

    static func longDate(_ wall: String) -> String { display(wall, "EEEE, MMMM d") }
    static func shortDate(_ wall: String) -> String { display(wall, "MMM d") }
    static func time(_ wall: String) -> String { display(wall, "h:mm a") }
    static func monthAbbrev(_ wall: String) -> String { display(wall, "MMM") }
    static func dayNumber(_ wall: String) -> String { display(wall, "d") }
    static func weekday(_ wall: String) -> String { display(wall, "EEEE") }

    /// Google Calendar template link, matching `lib/events.ts#googleCalendar`.
    static func googleCalendarURL(for e: Entity, start: String) -> URL? {
        guard let s = date(from: start) else { return nil }
        let duration: TimeInterval = {
            guard let a = date(from: e.start), let b = date(from: e.end) else { return 0 }
            return max(0, b.timeIntervalSince(a))
        }()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let override = e.overrides.first { $0.date == String(start.prefix(10)) }
        var comps = URLComponents(string: "https://calendar.google.com/calendar/render")!
        comps.queryItems = [
            .init(name: "action", value: "TEMPLATE"),
            .init(name: "text", value: e.name),
            .init(name: "dates", value: f.string(from: s) + "/" + f.string(from: s.addingTimeInterval(duration))),
            .init(name: "ctz", value: e.timezone),
            .init(name: "details", value: e.description),
            .init(name: "location", value: (override?.location.isEmpty == false ? override!.location : e.location)),
        ]
        return comps.url
    }
}
