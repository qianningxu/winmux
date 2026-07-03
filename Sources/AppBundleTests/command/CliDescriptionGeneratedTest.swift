import XCTest

final class CliDescriptionGeneratedTest: XCTestCase {
    func testTabCommandsArePrimaryAndWorkspaceCommandsAreLegacyAliases() throws {
        let descriptions = try String(contentsOf: projectRoot.appending(path: "Sources/Cli/subcommandDescriptionsGenerated.swift"))

        XCTAssertTrue(descriptions.contains(#"["  tab", "Focus the specified Tab"]"#))
        XCTAssertTrue(descriptions.contains(#"["  workspace", "Legacy alias for tab"]"#))
        XCTAssertTrue(descriptions.contains(#"["  list-tabs", "Print Tabs that satisfy conditions"]"#))
        XCTAssertTrue(descriptions.contains(#"["  list-workspaces", "Legacy alias for list-tabs"]"#))
        XCTAssertTrue(descriptions.contains(#"["  folder", "Focus the specified sidebar folder"]"#))
        XCTAssertTrue(descriptions.contains(#"["  project", "Legacy alias for folder"]"#))
        XCTAssertTrue(descriptions.contains(#"["  move-node-to-tab", "Move the focused window to the specified Tab"]"#))
        XCTAssertTrue(descriptions.contains(#"["  move-node-to-workspace", "Legacy alias for move-node-to-tab"]"#))
        XCTAssertTrue(descriptions.contains(#"["  reorder-tab", "Reorder a Tab before or after another Tab"]"#))
        XCTAssertTrue(descriptions.contains(#"["  reorder-workspace", "Legacy alias for reorder-tab"]"#))
        XCTAssertTrue(descriptions.contains(#"["  stack-with", "Disabled legacy center stacking command"]"#))
        XCTAssertFalse(descriptions.contains("Alias for flatten-workspace-tree"))
        XCTAssertFalse(descriptions.contains("legacy folder stacking"))
    }

    func testDetailedHelpAdvertisesTabSyntaxOnly() throws {
        let help = try String(contentsOf: projectRoot.appending(path: "Sources/Common/cmdHelpGenerated.swift"))

        XCTAssertTrue(help.contains("USAGE: tab [-h|--help]"))
        XCTAssertTrue(help.contains("USAGE: list-tabs [-h|--help]"))
        XCTAssertTrue(help.contains("USAGE: folder [-h|--help]"))
        XCTAssertTrue(help.contains("USAGE: move-node-to-tab [-h|--help]"))
        XCTAssertTrue(help.contains("USAGE: move-tab-to-monitor [-h|--help]"))
        XCTAssertTrue(help.contains("USAGE: reorder-tab [-h|--help]"))
        XCTAssertTrue(help.contains("USAGE: summon-tab [-h|--help]"))

        XCTAssertFalse(help.contains("workspace [-h|--help]"))
        XCTAssertFalse(help.contains("list-workspaces [-h|--help]"))
        XCTAssertFalse(help.contains("move-node-to-workspace [-h|--help]"))
        XCTAssertFalse(help.contains("move-workspace-to-monitor [-h|--help]"))
        XCTAssertFalse(help.contains("reorder-workspace [-h|--help]"))
        XCTAssertFalse(help.contains("summon-workspace [-h|--help]"))
        XCTAssertFalse(help.contains("workspace-back-and-forth [-h|--help]"))
        XCTAssertFalse(help.contains("flatten-workspace-tree [-h|--help]"))
        XCTAssertFalse(help.contains("--workspace <tab>"))
    }
}
