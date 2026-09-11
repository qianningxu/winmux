import Foundation

/// Y4S1 starts with orientation week 0 on 7 September 2026.
struct MenuBarAcademicPeriod {
    let currentWeek: Int
    let weekday: String
    let totalWeeks = 12

    init(now: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
        currentWeek = min(max(days / 7, 0), 12)
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.locale = Locale(identifier: "en_GB")
        weekdayFormatter.timeZone = calendar.timeZone
        weekdayFormatter.dateFormat = "EEE"
        weekday = weekdayFormatter.string(from: now)
    }

    var specialWeek: String? {
        switch currentWeek {
            case 6: "Reading Week"
            case 11: "Revision Week"
            default: nil
        }
    }

    var title: String {
        let progress = "Y4S1 - \(weekday) - \(currentWeek)/\(totalWeeks) Week"
        return specialWeek.map { "\(progress) - \($0)" } ?? progress
    }

    var accessibilityLabel: String {
        let progress = "Y4S1, \(weekday), week \(currentWeek) of \(totalWeeks)"
        return specialWeek.map { "\(progress), \($0)" } ?? progress
    }
}
