import Foundation
import SwiftUI

private let todayFocusTargetHoursByWeekday = [0, 11, 11, 6, 11, 11, 11]
private let todayFocusMarkerHeight: CGFloat = 72
private let todayFocusMarkerWidth: CGFloat = 4
private let todayFocusCompactCellSize: CGFloat = workspaceSidebarAppIconSize + 2
private let todayFocusCompactCellSpacing: CGFloat = 5
private let todayFocusCompactCellCornerRadius: CGFloat = 5

struct WorkspaceSidebarTodayFocusWidget: View {
    let id: String
    let sectionWidth: CGFloat
    let isCompact: Bool
    let entriesPath: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = TodayFocusAggregator(
                dataSource: URL(filePath: entriesPath, directoryHint: .isDirectory),
            ).load(now: context.date)

            TodayFocusCard(
                snapshot: snapshot,
                sectionWidth: sectionWidth,
                isCompact: isCompact,
            )
        }
        .id(id)
    }
}

struct TodayFocusSnapshot: Equatable, Sendable {
    let focusedSeconds: TimeInterval
    let targetHours: Int
    let errorMessage: String?

    var focusedHours: Double {
        focusedSeconds / 3600
    }

    var percentage: Int {
        guard targetHours > 0 else { return 0 }
        return Int((focusedHours / Double(targetHours) * 100).rounded())
    }
}

struct TodayFocusAggregator: Sendable {
    let dataSource: URL

    func load(now: Date = Date()) -> TodayFocusSnapshot {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now) - 1
        let targetHours = todayFocusTargetHoursByWeekday.indices.contains(weekday)
            ? todayFocusTargetHoursByWeekday[weekday]
            : 0

        guard let sqliteURL = SidebarSelfDataStore.sqliteURL(for: dataSource),
              let entries = SidebarSelfDataStore.loadTimeEntries(from: sqliteURL, now: now)
        else {
            return TodayFocusSnapshot(
                focusedSeconds: 0,
                targetHours: targetHours,
                errorMessage: "Can't read self_data",
            )
        }

        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return TodayFocusSnapshot(
                focusedSeconds: 0,
                targetHours: targetHours,
                errorMessage: "Can't resolve today",
            )
        }

        let focusedSeconds = entries.reduce(TimeInterval(0)) { total, entry in
            total + max(0, min(min(entry.stop, now), end).timeIntervalSince(max(entry.start, start)))
        }
        return TodayFocusSnapshot(
            focusedSeconds: focusedSeconds,
            targetHours: targetHours,
            errorMessage: nil,
        )
    }
}

private struct TodayFocusCard: View {
    let snapshot: TodayFocusSnapshot
    let sectionWidth: CGFloat
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                TodayFocusCompactHourGrid(snapshot: snapshot, sectionWidth: sectionWidth)
                    .frame(width: sectionWidth, alignment: .center)
            } else {
                expandedCard
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Today")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.72))
                Spacer(minLength: 2)
                Text(summaryText)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(summaryColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)

            Spacer(minLength: 0)
                .frame(height: 23)

            if let errorMessage = snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.80))
                    .lineLimit(2)
            } else if snapshot.targetHours == 0 {
                Text("REST")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.78))
                    .frame(maxWidth: .infinity, minHeight: todayFocusMarkerHeight, alignment: .center)
            } else {
                TodayFocusMarkers(snapshot: snapshot)
                    .frame(height: todayFocusMarkerHeight)
            }

            Spacer(minLength: 0)
                .frame(height: 11)
        }
        .padding(20)
        .frame(width: sectionWidth, alignment: .leading)
        .background(TodayFocusCardBackground())
    }

    private var summaryText: String {
        if snapshot.errorMessage != nil {
            return "—"
        }
        return String(format: "%.1fh", snapshot.focusedHours)
    }

    private var summaryColor: Color {
        if snapshot.errorMessage != nil {
            return winMuxOverlayDestructive(0.92)
        }
        return winMuxOverlayMutedForeground(0.72)
    }

    private var accessibilitySummary: String {
        if let errorMessage = snapshot.errorMessage {
            return errorMessage
        }
        return "Today, \(String(format: "%.1f", snapshot.focusedHours)) of \(snapshot.targetHours) focus hours, \(snapshot.percentage) percent"
    }
}

private struct TodayFocusCompactHourGrid: View {
    let snapshot: TodayFocusSnapshot
    let sectionWidth: CGFloat

    var body: some View {
        Group {
            if snapshot.errorMessage != nil {
                compactCell(fill: winMuxOverlayDestructive(0.92))
            } else if snapshot.targetHours == 0 {
                compactCell(fill: winMuxOverlayContrastingFill(darkOpacity: 0.14, lightOpacity: 0.09))
            } else {
                VStack(spacing: todayFocusCompactCellSpacing) {
                    ForEach(0 ..< snapshot.targetHours, id: \.self) { index in
                        TodayFocusCompactHourCell(progress: progress(at: index))
                    }
                }
            }
        }
        .frame(width: sectionWidth)
    }

    private func progress(at index: Int) -> Double {
        max(0, min(1, snapshot.focusedHours - Double(index)))
    }

    private func compactCell(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: todayFocusCompactCellCornerRadius, style: .continuous)
            .fill(fill)
            .frame(width: todayFocusCompactCellSize, height: todayFocusCompactCellSize)
    }
}

private struct TodayFocusCompactHourCell: View {
    let progress: Double

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: todayFocusCompactCellCornerRadius, style: .continuous)
                .fill(winMuxOverlayContrastingFill(darkOpacity: 0.14, lightOpacity: 0.09))

            if progress >= 1 {
                RoundedRectangle(cornerRadius: todayFocusCompactCellCornerRadius, style: .continuous)
                    .fill(winMuxOverlayForeground(0.94))
            } else if progress > 0 {
                Rectangle()
                    .fill(winMuxOverlayAttention())
                    .frame(height: todayFocusCompactCellSize * progress)
            }
        }
        .frame(width: todayFocusCompactCellSize, height: todayFocusCompactCellSize)
        .clipShape(RoundedRectangle(cornerRadius: todayFocusCompactCellCornerRadius, style: .continuous))
    }
}

private struct TodayFocusCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
            .fill(winMuxOverlayCard(0.94))
            .overlay {
                RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
                    .strokeBorder(winMuxOverlayBorder(0.76), lineWidth: 0.75)
            }
            .shadow(
                color: winMuxOverlayShadow(darkOpacity: 0.24, lightOpacity: 0.14),
                radius: 10,
                y: 4,
            )
    }
}

private struct TodayFocusMarkers: View {
    let snapshot: TodayFocusSnapshot

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(0 ..< snapshot.targetHours, id: \.self) { index in
                    Capsule()
                        .fill(markerColor(at: index))
                        .frame(width: todayFocusMarkerWidth, height: todayFocusMarkerHeight)
                        .position(
                            x: markerX(index: index, width: geometry.size.width),
                            y: todayFocusMarkerHeight / 2,
                        )
                }

                Capsule()
                    .fill(winMuxOverlayAttention())
                    .frame(width: todayFocusMarkerWidth, height: todayFocusMarkerHeight)
                    .position(
                        x: currentMarkerX(width: geometry.size.width),
                        y: todayFocusMarkerHeight / 2,
                    )
            }
        }
    }

    private func markerColor(at index: Int) -> Color {
        if snapshot.focusedHours >= Double(index + 1) {
            return winMuxOverlayForeground(0.94)
        }
        return winMuxOverlayContrastingFill(darkOpacity: 0.14, lightOpacity: 0.09)
    }

    private func markerX(index: Int, width: CGFloat) -> CGFloat {
        guard snapshot.targetHours > 1 else { return width / 2 }
        let usableWidth = max(0, width - todayFocusMarkerWidth)
        return todayFocusMarkerWidth / 2
            + CGFloat(index) / CGFloat(snapshot.targetHours - 1) * usableWidth
    }

    private func currentMarkerX(width: CGFloat) -> CGFloat {
        guard snapshot.targetHours > 1 else { return width / 2 }
        let progress = max(0, min(1, (snapshot.focusedHours - 1) / Double(snapshot.targetHours - 1)))
        let usableWidth = max(0, width - todayFocusMarkerWidth)
        return todayFocusMarkerWidth / 2 + CGFloat(progress) * usableWidth
    }
}
