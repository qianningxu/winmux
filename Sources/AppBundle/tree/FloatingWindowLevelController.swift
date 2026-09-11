import CoreGraphics
import Darwin
import Foundation

@MainActor
final class FloatingWindowLevelController {
    typealias LoadLevels = @MainActor () -> [UInt32: CGWindowLevel]
    typealias SetLevel = @MainActor (UInt32, CGWindowLevel) -> Bool

    static let shared = FloatingWindowLevelController(
        loadLevels: copyWindowLevels,
        setLevel: setSkyLightWindowLevel
    )

    private let loadLevels: LoadLevels
    private let setLevel: SetLevel
    private var originalLevels: [UInt32: CGWindowLevel] = [:]

    init(loadLevels: @escaping LoadLevels, setLevel: @escaping SetLevel) {
        self.loadLevels = loadLevels
        self.setLevel = setLevel
    }

    @discardableResult
    func sync(floatingWindowIds: Set<UInt32>) -> Set<UInt32> {
        var promotedWindowIds: Set<UInt32> = []
        let windowIdsToRestore = originalLevels.keys.filter { !floatingWindowIds.contains($0) }
        for windowId in windowIdsToRestore {
            guard let originalLevel = originalLevels[windowId] else { continue }
            if originalLevel != floatingWindowLevel {
                _ = setLevel(windowId, originalLevel)
            }
            originalLevels.removeValue(forKey: windowId)
        }

        let newWindowIds = floatingWindowIds.filter { originalLevels[$0] == nil }
        guard !newWindowIds.isEmpty else { return promotedWindowIds }
        let levels = loadLevels()
        for windowId in newWindowIds {
            guard let originalLevel = levels[windowId] else { continue }
            if originalLevel == floatingWindowLevel || setLevel(windowId, floatingWindowLevel) {
                originalLevels[windowId] = originalLevel
                promotedWindowIds.insert(windowId)
            }
        }
        return promotedWindowIds
    }

    func restoreAll() {
        sync(floatingWindowIds: [])
    }
}

@MainActor
func syncGlobalFloatingWindowLevels() {
    let floatingWindowIds: Set<UInt32> = if TrayMenuModel.shared.isEnabled && !serverArgs.isReadOnly {
        Set(globalFloatingWindowsContainer.children.compactMap { ($0 as? MacWindow)?.windowId })
    } else {
        []
    }
    let promotedWindowIds = FloatingWindowLevelController.shared.sync(floatingWindowIds: floatingWindowIds)
    for windowId in promotedWindowIds {
        MacWindow.allWindowsMap[windowId]?.macApp.raiseWindow(windowId)
    }
}

private let floatingWindowLevel = CGWindowLevelForKey(.floatingWindow)

@MainActor
private func copyWindowLevels() -> [UInt32: CGWindowLevel] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
    guard let windowInfos = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
        return [:]
    }
    return windowInfos.reduce(into: [:]) { result, info in
        guard let windowId = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
              let level = (info[kCGWindowLayer as String] as? NSNumber)?.int32Value
        else { return }
        result[windowId] = level
    }
}

@MainActor
private func setSkyLightWindowLevel(_ windowId: UInt32, _ level: CGWindowLevel) -> Bool {
    SkyLightWindowLevel.shared.setWindowLevel(windowId, level)
}

@MainActor
private final class SkyLightWindowLevel {
    static let shared = SkyLightWindowLevel()

    typealias MainConnectionIdFunction = @convention(c) () -> Int32
    typealias GetWindowOwnerFunction = @convention(c) (Int32, UInt32, UnsafeMutablePointer<Int32>) -> CGError
    typealias SetWindowLevelFunction = @convention(c) (Int32, UInt32, CGWindowLevel) -> CGError

    private let connectionId: Int32
    private let getWindowOwner: GetWindowOwnerFunction?
    private let setWindowLevel: SetWindowLevelFunction?

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            connectionId = 0
            getWindowOwner = nil
            setWindowLevel = nil
            return
        }
        let mainConnection = dlsym(handle, "SLSMainConnectionID")
            .map { unsafeBitCast($0, to: MainConnectionIdFunction.self) }
        getWindowOwner = dlsym(handle, "SLSGetWindowOwner")
            .map { unsafeBitCast($0, to: GetWindowOwnerFunction.self) }
        setWindowLevel = dlsym(handle, "SLSSetWindowLevel")
            .map { unsafeBitCast($0, to: SetWindowLevelFunction.self) }
        connectionId = mainConnection?() ?? 0
    }

    func setWindowLevel(_ windowId: UInt32, _ level: CGWindowLevel) -> Bool {
        guard connectionId != 0, let getWindowOwner, let setWindowLevel else { return false }
        var ownerConnectionId: Int32 = 0
        guard getWindowOwner(connectionId, windowId, &ownerConnectionId) == .success,
              ownerConnectionId != 0
        else { return false }
        return setWindowLevel(ownerConnectionId, windowId, level) == .success
    }
}
