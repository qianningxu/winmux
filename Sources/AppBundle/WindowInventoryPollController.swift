import Foundation

@MainActor
final class WindowInventoryPollController {
    typealias ScheduledOperation = @MainActor () async -> Void
    typealias CancelScheduledOperation = @MainActor () -> Void
    typealias Scheduler = @MainActor (
        _ delay: TimeInterval,
        _ tolerance: TimeInterval,
        _ operation: @escaping ScheduledOperation
    ) -> CancelScheduledOperation

    static let initialDelay: TimeInterval = 0.35
    static let maximumDelay: TimeInterval = 5

    private let scheduler: Scheduler
    private let checkInventory: @MainActor () async -> Bool
    private let reconcileIfIdle: @MainActor () -> Bool
    private let now: @MainActor () -> TimeInterval

    private var currentDelay = initialDelay
    private var scheduledDeadline: TimeInterval?
    private var cancelScheduledOperation: CancelScheduledOperation?
    private var scheduleGeneration: UInt64 = 0
    private var lifecycleGeneration: UInt64 = 0
    private var isRunning = false
    private var isChecking = false
    private var activityWhileChecking = false

    init(
        scheduler: @escaping Scheduler,
        checkInventory: @escaping @MainActor () async -> Bool,
        reconcileIfIdle: @escaping @MainActor () -> Bool,
        now: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.scheduler = scheduler
        self.checkInventory = checkInventory
        self.reconcileIfIdle = reconcileIfIdle
        self.now = now
    }

    func start() {
        guard !isRunning else {
            noteActivity()
            return
        }
        lifecycleGeneration += 1
        isRunning = true
        currentDelay = Self.initialDelay
        scheduleCheck(after: currentDelay)
    }

    func stop() {
        lifecycleGeneration += 1
        isRunning = false
        activityWhileChecking = false
        cancelPendingCheck()
    }

    func noteActivity() {
        guard isRunning else { return }
        currentDelay = Self.initialDelay
        if isChecking {
            activityWhileChecking = true
        } else {
            scheduleCheck(after: currentDelay)
        }
    }

    private func scheduleCheck(after delay: TimeInterval) {
        guard isRunning else { return }
        let deadline = now() + delay
        if let scheduledDeadline, scheduledDeadline <= deadline {
            return
        }

        cancelPendingCheck()
        scheduleGeneration += 1
        let generation = scheduleGeneration
        scheduledDeadline = deadline
        cancelScheduledOperation = scheduler(delay, Self.tolerance(for: delay)) { [weak self] in
            guard let self else { return }
            await self.runScheduledCheck(generation: generation)
        }
    }

    private func cancelPendingCheck() {
        scheduleGeneration += 1
        cancelScheduledOperation?()
        cancelScheduledOperation = nil
        scheduledDeadline = nil
    }

    private func runScheduledCheck(generation: UInt64) async {
        guard isRunning, generation == scheduleGeneration else { return }
        cancelScheduledOperation = nil
        scheduledDeadline = nil
        guard !isChecking else {
            activityWhileChecking = true
            return
        }

        isChecking = true
        let checkLifecycleGeneration = lifecycleGeneration
        let inventoryChanged = await checkInventory()
        isChecking = false

        guard isRunning, checkLifecycleGeneration == lifecycleGeneration else {
            if isRunning, activityWhileChecking {
                activityWhileChecking = false
                currentDelay = Self.initialDelay
                scheduleCheck(after: currentDelay)
            }
            return
        }

        if inventoryChanged {
            _ = reconcileIfIdle()
        }
        if activityWhileChecking {
            activityWhileChecking = false
            currentDelay = Self.initialDelay
        } else {
            currentDelay = min(currentDelay * 2, Self.maximumDelay)
        }
        scheduleCheck(after: currentDelay)
    }

    static func tolerance(for delay: TimeInterval) -> TimeInterval {
        min(delay * 0.2, 0.5)
    }
}
