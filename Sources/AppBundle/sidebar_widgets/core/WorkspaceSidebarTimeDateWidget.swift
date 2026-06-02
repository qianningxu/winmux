import Foundation
import SwiftUI

struct WorkspaceSidebarTimeDateWidget: View {
    let id: String
    let sectionWidth: CGFloat
    let isCompact: Bool
    let showsDate: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Group {
                if isCompact {
                    WorkspaceSidebarCompactTimeDateCard(
                        date: context.date,
                        sectionWidth: sectionWidth,
                    )
                } else {
                    WorkspaceSidebarExpandedTimeDateCard(
                        date: context.date,
                        sectionWidth: sectionWidth,
                        showsDate: showsDate,
                    )
                }
            }
        }
        .id(id)
    }
}

private struct WorkspaceSidebarClockComponents {
    let hour: String
    let minute: String
    let second: String

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        hour = Self.format(components.hour)
        minute = Self.format(components.minute)
        second = Self.format(components.second)
    }

    private static func format(_ value: Int?) -> String {
        String(format: "%02d", value ?? 0)
    }
}

private struct WorkspaceSidebarCompactTimeDateCard: View {
    let date: Date
    let sectionWidth: CGFloat

    private var components: WorkspaceSidebarClockComponents {
        WorkspaceSidebarClockComponents(date: date)
    }

    var body: some View {
        GeometryReader { _ in
            let shape = RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
            ZStack(alignment: .bottomLeading) {
                shape
                    .fill(Color.white.opacity(0.06))

                VStack(alignment: .center, spacing: 4) {
                    Text(components.hour)
                        .foregroundStyle(Color.white.opacity(0.90))

                    Text(components.minute)
                        .foregroundStyle(Color.white.opacity(0.90))

                    Text(components.second)
                        .foregroundStyle(Color.white.opacity(0.66))
                }
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                shape
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
            }
            .clipShape(shape)
        }
        .frame(width: sectionWidth, alignment: .leading)
        .frame(height: 92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date, format: .dateTime.hour().minute().second()))
    }
}

private struct WorkspaceSidebarExpandedTimeDateCard: View {
    let date: Date
    let sectionWidth: CGFloat
    let showsDate: Bool

    private var accessibilitySummary: String {
        var parts = [date.formatted(date: .omitted, time: .standard)]
        if showsDate {
            parts.append(date.formatted(date: .complete, time: .omitted))
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 4) {
                Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                Text(date, format: .dateTime.second(.twoDigits))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.34))
                    .lineLimit(1)
                    .padding(.top, 9)
            }
            .layoutPriority(1)

            if showsDate {
                VStack(alignment: .leading, spacing: 1) {
                    Text(date, format: .dateTime.weekday(.abbreviated))
                    Text(date, format: .dateTime.month(.abbreviated).day())
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: sectionWidth, height: 68, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilitySummary))
    }
}
