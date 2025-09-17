import Foundation

/// Manages the execution of steps. In particular
/// - prevents double execution of steps
/// - keeps global information for logging
public actor AsyncExecution {
    
    let synchronousExecution: Execution
    
    public var synchronous: Execution {
        get async { synchronousExecution }
    }
    
    public func setting(
        waitNotPausedFunction: (() -> ())? = nil
    ) -> Self {
        if let waitNotPausedFunction {
            synchronousExecution.waitNotPausedFunction = waitNotPausedFunction
        }
        return self
    }
    
    public var parallel: AsyncExecution {
        AsyncExecution(
            executionInfoConsumer: synchronousExecution.executionInfoConsumer,
            effectuationStack: synchronousExecution._effectuationStack,
            waitNotPausedFunction: synchronousExecution.waitNotPausedFunction
        )
    }
    
    public init(
        processID: String? = nil,
        executionInfoConsumer: ExecutionInfoConsumer,
        itemInfo: String? = nil,
        showSteps: Bool = false,
        debug: Bool = false,
        effectuationStack: [Effectuation] = [Effectuation](),
        withOptions activatedOptions: Set<String>? = nil,
        dispensingWith dispensedWith: Set<String>? = nil,
        waitNotPausedFunction: (() -> ())? = nil,
        logFileInfo: URL? = nil
    ) {
        self.synchronousExecution = Execution(
            processID: processID,
            executionInfoConsumer: executionInfoConsumer,
            itemInfo: itemInfo,
            showSteps: showSteps,
            debug: debug,
            effectuationStack: effectuationStack,
            withOptions: activatedOptions,
            dispensingWith: dispensedWith,
            waitNotPausedFunction: waitNotPausedFunction,
            logFileInfo: logFileInfo
        )
    }
    
    public var level: Int {
        get async { synchronousExecution.level }
    }
    
    public var executionPath: String {
        get async { synchronousExecution.executionPath }
    }
    
    public func abort(reason: String) async {
        synchronousExecution.abort(reason: reason)
    }
    
    public var aborted: Bool { synchronousExecution._aborted }
    
    public var currentIndentation: String {
        get async { synchronousExecution.currentIndentation }
    }
    
    let semaphoreForPause = DispatchSemaphore(value: 1)
    
    /// Pausing the execution (without effect for async execution).
    public func pause() {
        semaphoreForPause.wait()
    }
    
    /// Proceeding a paused execution.
    public func proceed() {
        semaphoreForPause.signal()
    }
    
    func waitNotPaused() {
        
        func waitNotPaused() {
            semaphoreForPause.wait(); semaphoreForPause.signal()
        }
        
        (synchronousExecution.waitNotPausedFunction ?? waitNotPaused)() // wait if the execution is paused
    }
    
    /// Force all contained work to be executed, even if already executed before.
    fileprivate func execute<T>(step: StepID?, description: String?, force: Bool, work: () async throws -> T) async rethrows -> T {
        waitNotPaused() // wait if the execution is paused
        synchronousExecution.forceValues.append(force)
        if let step {
            synchronousExecution._effectuationStack.append(.step(step: step, description: description))
        }
        let result = try await work()
        if step != nil {
            synchronousExecution._effectuationStack.removeLast()
        }
        synchronousExecution.forceValues.removeLast()
        return result
    }
    
    /// Executes always.
    public func force<T>(work: () async throws -> T) async rethrows -> T? {
        
        synchronousExecution.executionInfoConsumer.consume(
            .beginningForcingSteps,
            atLevel: await level
        )
        synchronousExecution._effectuationStack.append(.forcing)
        
        func rewind() async {
            synchronousExecution._effectuationStack.removeLast()
            synchronousExecution.executionInfoConsumer.consume(
                .endingForcingSteps,
                atLevel: synchronousExecution.level
            )
        }
        
        let t: T?
        do {
            t = try await execute(step: nil, description: nil, force: true, work: work)
            await rewind()
        } catch {
            await rewind()
            throw error
        }
        return t
    }
    
    /// After execution, disremember what has been executed.
    public func disremember<T>(work: () async throws -> T) async rethrows -> T? {
        let oldExecutedSteps = synchronousExecution.executedSteps
        let result = try await execute(step: nil, description: nil, force: false, work: work)
        synchronousExecution.executedSteps = oldExecutedSteps
        return result
    }
    
    /// Executes always if in a forced context.
    public func inheritForced<T>(work: () async throws -> T) async rethrows -> T? {
        try await execute(step: nil, description: nil, force: synchronousExecution.forceValues.last == true, work: work)
    }
    
    /// Something that does not run in the normal case but ca be activated. Should use module name as prefix.
    public func optional<T>(named partName: String, description: String? = nil, work: () async throws -> T) async rethrows -> T? {
        let result: T?
        if synchronousExecution.activatedOptions?.contains(partName) != true || synchronousExecution.dispensedWith?.contains(partName) == true {
            synchronousExecution.executionInfoConsumer.consume(
                .skippingOptionalPart(
                    name: partName,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
            result = nil
        } else {
            synchronousExecution.executionInfoConsumer.consume(
                .beginningOptionalPart(
                    name: partName,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
            synchronousExecution._effectuationStack.append(.optionalPart(name: partName, description: description))
            result = try await execute(step: nil, description: nil, force: false, work: work)
            synchronousExecution._effectuationStack.removeLast()
            synchronousExecution.executionInfoConsumer.consume(
                .endingOptionalPart(
                    name: partName,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
        }
        return result
    }
    
    /// Something that runs in the normal case but ca be dispensed with. Should use module name as prefix.
    public func dispensable<T>(named partName: String, description: String? = nil, work: () async throws -> T) async rethrows -> T? {
        let result: T?
        if synchronousExecution.dispensedWith?.contains(partName) == true {
            synchronousExecution.executionInfoConsumer.consume(
                .skippingDispensablePart(
                    name: partName,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
            result = nil
        } else {
            synchronousExecution.executionInfoConsumer.consume(
                .beginningDispensablePart(
                    name: partName,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
            synchronousExecution._effectuationStack.append(.dispensablePart(name: partName, description: description))
            result = try await execute(step: nil, description: description, force: false, work: work)
            synchronousExecution._effectuationStack.removeLast()
            synchronousExecution.executionInfoConsumer.consume(
                .endingDispensablePart(
                    name: partName,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
        }
        return result
    }
    
    private func effectuateTest(forStep step: StepID, withDescription description: String?) async -> (execute: Bool, forced: Bool) {
        if synchronousExecution._aborted {
            synchronousExecution.executionInfoConsumer.consume(
                .skippingStepInAbortedExecution(
                    id: step,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
            return (execute: false, forced: false)
        } else if !synchronousExecution.executedSteps.contains(step) {
            synchronousExecution.executionInfoConsumer.consume(
                .beginningStep(
                    id: step,
                    description: description,
                    forced: false
                ),
                atLevel: synchronousExecution.level
            )
            synchronousExecution.executedSteps.insert(step)
            return (execute: true, forced: false)
        } else if synchronousExecution.forceValues.last == true {
            synchronousExecution.executionInfoConsumer.consume(
                .beginningStep(
                    id: step,
                    description: description,
                    forced: true
                ),
                atLevel: synchronousExecution.level
            )
            synchronousExecution.executedSteps.insert(step)
            return (execute: true, forced: true)
        } else {
            synchronousExecution.executionInfoConsumer.consume(
                .skippingPreviouslyExecutedStep(
                    id: step,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
            return (execute: false, forced: false)
        }
    }
    
    /// Logging some work (that is not a step) as progress.
    public func doing<T>(withID id: String? = nil, _ description: String, work: () async throws -> T) async rethrows -> T? {
        synchronousExecution.executionInfoConsumer.consume(
            .beginningDescribedPart(
                description: description
            ),
            atLevel: synchronousExecution.level
        )
        synchronousExecution._effectuationStack.append(.describedPart(description: description))
        let result = try await work()
        synchronousExecution._effectuationStack.removeLast()
        synchronousExecution.executionInfoConsumer.consume(
            .endingDescribedPart(
                description: description
            ),
            atLevel: synchronousExecution.level
        )
        return result
    }
    
    private func after(step: StepID, description: String?, forced: Bool, secondsElapsed: Double) async {
        if synchronousExecution._aborted {
            synchronousExecution.executionInfoConsumer.consume(
                .abortedStep(
                    id: step,
                    description: description
                ),
                atLevel: synchronousExecution.level
            )
        } else {
            synchronousExecution.executionInfoConsumer.consume(
                .endingStep(
                    id: step,
                    description: description,
                    forced: forced
                ),
                atLevel: synchronousExecution.level
            )
        }
    }
    
    /// Executes only if the step did not execute before.
    public func effectuate<T>(_ description: String? = nil, checking step: StepID, work: () async throws -> T) async rethrows -> T? {
        let (execute: toBeExecuted,forced: forced) = await effectuateTest(forStep: step, withDescription: description)
        if toBeExecuted {
            let start = DispatchTime.now()
            let result = try await execute(step: step, description: description, force: false, work: work)
            await after(step: step, description: description, forced: forced, secondsElapsed: elapsedSeconds(start: start))
            return result
        } else {
            return nil
        }
    }
    
}
