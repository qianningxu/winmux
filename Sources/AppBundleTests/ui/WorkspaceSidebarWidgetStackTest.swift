@testable import AppBundle
import Foundation
import XCTest

final class WorkspaceSidebarWidgetStackTest: XCTestCase {
    func testRotationGroupsKeepFirstPositionAndCollectEnabledMembers() {
        let widgets = [
            widget(id: "time-date", type: .builtInTimeDate),
            widget(id: "toggl-days", type: .builtInTogglDays, rotationGroup: "focus", rotationIntervalSeconds: 300),
            widget(id: "spending", type: .builtInSpendingCategories),
            widget(id: "schedule-heatmap", type: .builtInScheduleHeatmap, rotationGroup: "focus"),
            widget(id: "toggl-projects", type: .builtInTogglProjects, rotationGroup: "reports", rotationIntervalSeconds: 60),
            widget(id: "custom", type: .plugin, bundle: "CustomWidget.bundle", rotationGroup: "reports", rotationIntervalSeconds: 120),
        ]

        let items = WorkspaceSidebarWidgetStackItem.items(for: widgets)

        assertEquals(items.map(\.id), ["time-date", "rotation-focus", "spending", "rotation-reports"])
        guard case .rotationGroup(let focusId, let focusWidgets, let focusIntervalSeconds) = items[1] else {
            return XCTFail("Expected focus rotation group")
        }
        assertEquals(focusId, "focus")
        assertEquals(focusWidgets.map(\.id), ["toggl-days", "schedule-heatmap"])
        assertEquals(focusIntervalSeconds, 300)

        guard case .rotationGroup(let reportsId, let reportsWidgets, let reportsIntervalSeconds) = items[3] else {
            return XCTFail("Expected reports rotation group")
        }
        assertEquals(reportsId, "reports")
        assertEquals(reportsWidgets.map(\.id), ["toggl-projects", "custom"])
        assertEquals(reportsIntervalSeconds, 60)
    }

    func testSingleWidgetRotationGroupRendersAsPlainWidget() {
        let widgets = [
            widget(id: "time-date", type: .builtInTimeDate),
            widget(id: "toggl-days", type: .builtInTogglDays, rotationGroup: "focus", rotationIntervalSeconds: 300),
        ]

        let items = WorkspaceSidebarWidgetStackItem.items(for: widgets)

        assertEquals(items, [
            .widget(widgets[0]),
            .widget(widgets[1]),
        ])
    }

    func testRotationGroupUsesDefaultIntervalAndReferenceDateSlots() {
        let widgets = [
            widget(id: "toggl-days", type: .builtInTogglDays, rotationGroup: "focus"),
            widget(id: "schedule-heatmap", type: .builtInScheduleHeatmap, rotationGroup: "focus"),
        ]

        let items = WorkspaceSidebarWidgetStackItem.items(for: widgets)

        guard case .rotationGroup(_, let groupWidgets, let intervalSeconds) = items.first else {
            return XCTFail("Expected rotation group")
        }
        assertEquals(intervalSeconds, defaultWorkspaceSidebarWidgetRotationIntervalSeconds)
        assertEquals(
            WorkspaceSidebarWidgetStackItem.activeWidget(
                in: groupWidgets,
                intervalSeconds: intervalSeconds,
                at: Date(timeIntervalSinceReferenceDate: 299),
            )?.id,
            "toggl-days",
        )
        assertEquals(
            WorkspaceSidebarWidgetStackItem.activeWidget(
                in: groupWidgets,
                intervalSeconds: intervalSeconds,
                at: Date(timeIntervalSinceReferenceDate: 300),
            )?.id,
            "schedule-heatmap",
        )
        assertEquals(
            WorkspaceSidebarWidgetStackItem.activeWidget(
                in: groupWidgets,
                intervalSeconds: intervalSeconds,
                at: Date(timeIntervalSinceReferenceDate: 600),
            )?.id,
            "toggl-days",
        )
    }

    private func widget(
        id: String,
        type: WorkspaceSidebarWidgetType,
        bundle: String? = nil,
        rotationGroup: String? = nil,
        rotationIntervalSeconds: Int? = nil,
    ) -> WorkspaceSidebarWidgetConfig {
        WorkspaceSidebarWidgetConfig(
            id: id,
            type: type,
            enabled: true,
            bundle: bundle,
            rotationGroup: rotationGroup,
            rotationIntervalSeconds: rotationIntervalSeconds,
        )
    }
}
