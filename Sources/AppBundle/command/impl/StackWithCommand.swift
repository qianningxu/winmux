import AppKit
import Common

struct StackWithCommand: Command {
    let args: StackWithCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        io.err("Window stacking into old top tab groups is disabled. Use edge split actions inside the active Tab instead.")
    }
}
