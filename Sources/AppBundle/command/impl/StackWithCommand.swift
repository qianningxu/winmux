import AppKit
import Common

struct StackWithCommand: Command {
    let args: StackWithCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        io.err("Center stacking is disabled. Use left, right, top, or bottom split actions inside the active Tab instead.")
    }
}
