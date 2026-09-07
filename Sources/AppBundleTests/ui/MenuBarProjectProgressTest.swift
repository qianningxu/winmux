import Foundation
import XCTest
@testable import AppBundle

final class MenuBarProjectProgressTest: XCTestCase {
    func testProjectProgressRotatesOneProjectEveryFiveMinutes() {
        let firstBoundary = Date(timeIntervalSinceReferenceDate: 300 * 1_000)
        let firstIndex = MenuBarProjectProgressRotation.index(for: firstBoundary, projectCount: 3)

        XCTAssertEqual(firstIndex, 1)
        XCTAssertEqual(
            MenuBarProjectProgressRotation.index(
                for: firstBoundary.addingTimeInterval(menuBarProjectProgressRotationInterval - 1),
                projectCount: 3
            ),
            firstIndex
        )
        XCTAssertEqual(
            MenuBarProjectProgressRotation.index(
                for: firstBoundary.addingTimeInterval(menuBarProjectProgressRotationInterval),
                projectCount: 3
            ),
            2
        )
        XCTAssertEqual(
            MenuBarProjectProgressRotation.index(
                for: firstBoundary.addingTimeInterval(menuBarProjectProgressRotationInterval * 2),
                projectCount: 3
            ),
            0
        )
    }

    func testProjectProgressRotationHasNoSelectionWithoutProjects() {
        XCTAssertNil(MenuBarProjectProgressRotation.index(for: .now, projectCount: 0))
    }

    func testLoadsEveryProjectMatchingProjectsViewFiltersAndSortsByPriority() throws {
        let fixture = try ProjectProgressFixture()
        defer { fixture.remove() }

        try fixture.writeBase()
        try fixture.writeProject(
            "Interview Q",
            frontmatter: """
            Period:
              - Y3 summer
            Status: In progress
            Priority: 3
            ratio: 4
            start: 2026-08-22T00:00:00
            ddl: 2026-09-25
            """
        )
        try fixture.writeProject(
            "Leetcode",
            frontmatter: """
            Period: Y3 summer
            Status:
              - In progress
            Priority: 2
            start: 2026-09-04T00:00:00
            ddl: 2026-09-25
            """
        )
        try fixture.writeProject(
            "Completed",
            frontmatter: """
            Period: Y3 summer
            Status: Completed
            Priority: 9
            """
        )

        let now = try XCTUnwrap(ProjectProgressFixture.date("2026-09-04T12:00:00"))
        let projects = MenuBarProjectProgressLoader(baseURL: fixture.baseURL).load(now: now)

        XCTAssertEqual(projects.map(\.name), ["Interview Q", "Leetcode"])
        XCTAssertEqual(projects.map(\.completedTaskCount), [0, 0])
        XCTAssertEqual(projects.map(\.totalTaskCount), [0, 0])
        XCTAssertEqual(projects.map(\.daysRemaining), [21, 21])
        XCTAssertEqual(projects[0].timeProgress, 40)
        XCTAssertEqual(projects[1].timeProgress, 2)
    }

    func testCountsCompletedTasksInConfiguredTaskFolders() throws {
        let fixture = try ProjectProgressFixture()
        defer { fixture.remove() }

        try fixture.writeBase()
        try fixture.writeProject(
            "Interview Q",
            frontmatter: """
            Period: Y3 summer
            Status: In progress
            Priority: 1
            start: 2026-09-01
            ddl: 2026-09-20
            """
        )

        try fixture.writeTask("Interview Q", "done", completed: true)
        try fixture.writeTask("Interview Q", "todo", completed: false)
        try fixture.writeTask("Different project", "ignored", completed: true)

        let now = try XCTUnwrap(ProjectProgressFixture.date("2026-09-04T12:00:00"))
        let project = try XCTUnwrap(MenuBarProjectProgressLoader(baseURL: fixture.baseURL).load(now: now).first)
        XCTAssertEqual(project.completedTaskCount, 1)
        XCTAssertEqual(project.totalTaskCount, 2)
    }
}

private final class ProjectProgressFixture {
    let rootURL: URL
    let vaultURL: URL
    let baseURL: URL
    let projectsURL: URL
    let tasksURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory.appending(
            path: "winmux-project-progress-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        vaultURL = rootURL.appending(path: "self_ob", directoryHint: .isDirectory)
        baseURL = vaultURL.appending(path: "Others/tasks.base")
        projectsURL = vaultURL.appending(path: "Others/Projects", directoryHint: .isDirectory)
        tasksURL = vaultURL.appending(path: "Others/Tasks/Interview Q", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tasksURL, withIntermediateDirectories: true)
    }

    func writeBase() throws {
        let contents = """
        views:
          - type: table
            name: Projects
            filters:
              and:
                - file.folder == "Others/Projects"
                - Period.contains("Y3 summer")
                - Status.contains("In progress")
                - "!Priority.isEmpty()"
          - type: table
            name: Tasks
            filters:
              and:
                - file.folder.containsAny("Others/Tasks/Interview Q")
        """
        try contents.write(to: baseURL, atomically: true, encoding: .utf8)
    }

    func writeTask(_ project: String, _ name: String, completed: Bool) throws {
        let contents = "---\ncompleted: \(completed)\nproject: \"[[\(project)]]\"\n---\n"
        try contents.write(
            to: tasksURL.appending(path: "\(name).md"),
            atomically: true,
            encoding: .utf8
        )
    }

    func writeProject(_ name: String, frontmatter: String) throws {
        let contents = "---\n\(frontmatter)\n---\n"
        try contents.write(
            to: projectsURL.appending(path: "\(name).md"),
            atomically: true,
            encoding: .utf8
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    static func date(_ rawValue: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: rawValue)
    }
}
