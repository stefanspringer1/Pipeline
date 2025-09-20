import Foundation
import Localization

/// Manages the execution of steps. In particular
/// - prevents double execution of steps
/// - keeps global information for logging
public final actor AsyncExecution {
    
    let synchronousExecution: Execution
    
    public var metadataInfo: String { synchronousExecution.metadataInfo }
    public var metadataInfoForUserInteraction: String { synchronousExecution.metadataInfoForUserInteraction }
    
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
            ExecutionEventProcessor: synchronousExecution.ExecutionEventProcessor,
            effectuationStack: synchronousExecution._effectuationStack,
            waitNotPausedFunction: synchronousExecution.waitNotPausedFunction
        )
    }
    
    public init(
        language: Language = .en,
        processID: String? = nil,
        ExecutionEventProcessor: any ExecutionEventProcessor,
        stopAtFatalError: Bool = true,
        effectuationStack: [Effectuation] = [Effectuation](),
        withOptions activatedOptions: Set<String>? = nil,
        dispensingWith dispensedWith: Set<String>? = nil,
        waitNotPausedFunction: (() -> ())? = nil,
        logFileInfo: URL? = nil
    ) {
        self.synchronousExecution = Execution(
            language: language,
            ExecutionEventProcessor: ExecutionEventProcessor,
            stopAtFatalError: stopAtFatalError,
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
    
    public func stop(reason: String) async {
        synchronousExecution.stop(reason: reason)
    }
    
    public var stopped: Bool { synchronousExecution._stopped }
    
    func waitNotPaused() {
        synchronousExecution.waitNotPausedFunction?() // wait if the execution is paused
    }
    
    /// Force all contained work to be executed, even if already executed before.
    fileprivate func execute<T>(
        step: StepID?,
        description: String?,
        force: Bool,
        appeaseTo appeaseType: InfoType? = nil,
        work: () async throws -> T
    ) async rethrows -> T {
        waitNotPaused() // wait if the execution is paused
        synchronousExecution.forceValues.append(force)
        if let appeaseType {
            synchronousExecution.appeaseTypes.append(appeaseType)
        }
        if let step {
            synchronousExecution._effectuationStack.append(.step(step: step, description: description))
        }
        let result = try await work()
        if step != nil {
            synchronousExecution._effectuationStack.removeLast()
        }
        synchronousExecution.forceValues.removeLast()
        if appeaseType != nil {
            synchronousExecution.appeaseTypes.removeLast()
        }
        return result
    }
    
    /// Executes always.
    public func force<T>(work: () async throws -> T) async rethrows -> T? {
        let structuralID = UUID()
        synchronousExecution.ExecutionEventProcessor.process(
            ExecutionEvent(
                type: .progress,
                level: synchronousExecution.level,
                structuralID: structuralID,
                event: .beginningForcingSteps,
                effectuationStack: synchronousExecution.effectuationStack
            )
        )
        synchronousExecution._effectuationStack.append(.forcing)
        
        func rewind() async {
            synchronousExecution._effectuationStack.removeLast()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .endingForcingSteps,
                    effectuationStack: synchronousExecution.effectuationStack
                )
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
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: nil, // is a leave, no structural ID necessary
                    event: .skippingOptionalPart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            result = nil
        } else {
            let structuralID = UUID()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .beginningOptionalPart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            synchronousExecution._effectuationStack.append(.optionalPart(name: partName, description: description))
            result = try await execute(step: nil, description: nil, force: false, work: work)
            synchronousExecution._effectuationStack.removeLast()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .endingOptionalPart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
        }
        return result
    }
    
    /// Something that runs in the normal case but ca be dispensed with. Should use module name as prefix.
    public func dispensable<T>(named partName: String, description: String? = nil, work: () async throws -> T) async rethrows -> T? {
        let result: T?
        if synchronousExecution.dispensedWith?.contains(partName) == true {
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: nil, // is a leave, no structural ID necessary
                    event: .skippingDispensablePart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            result = nil
        } else {
            let structuralID = UUID()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .beginningDispensablePart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            synchronousExecution._effectuationStack.append(.dispensablePart(name: partName, description: description))
            result = try await execute(step: nil, description: description, force: false, work: work)
            synchronousExecution._effectuationStack.removeLast()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .endingDispensablePart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
        }
        return result
    }
    
    /// Make worse message type than `Error` to type `Error` in contained calls.
    public func appease<T>(to appeaseType: InfoType? = .error, work: () async throws -> T) async rethrows -> T? {
        try await execute(step: nil, description: nil, force: false, appeaseTo: appeaseType, work: work)
    }
    
    private func effectuateTest(forStep step: StepID, withDescription description: String?) async -> (execute: Bool, forced: Bool, structuralID: UUID?) {
        if synchronousExecution._stopped {
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: nil, // is a leave, no structural ID necessary
                    event: .skippingStepInStoppedExecution(
                        id: step,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            return (execute: false, forced: false, structuralID: nil)
        } else if !synchronousExecution.executedSteps.contains(step) {
            let structuralID = UUID()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                        event: .beginningStep(
                        id: step,
                        description: description,
                        forced: false
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            synchronousExecution.executedSteps.insert(step)
            return (execute: true, forced: false, structuralID: structuralID)
        } else if synchronousExecution.forceValues.last == true {
            let structuralID = UUID()
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .beginningStep(
                        id: step,
                        description: description,
                        forced: true
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            synchronousExecution.executedSteps.insert(step)
            return (execute: true, forced: true, structuralID: structuralID)
        } else {
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: nil, // is a leave, no structural ID necessary
                    event: .skippingPreviouslyExecutedStep(
                        id: step,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
            return (execute: false, forced: false, structuralID: nil)
        }
    }
    
    /// Logging some work (that is not a step) as progress.
    public func doing<T>(withID id: String? = nil, _ description: String, work: () async throws -> T) async rethrows -> T? {
        let structuralID = UUID()
        synchronousExecution.ExecutionEventProcessor.process(
            ExecutionEvent(
                type: .progress,
                level: synchronousExecution.level,
                structuralID: structuralID,
                event: .beginningDescribedPart(
                    description: description
                ),
                effectuationStack: synchronousExecution.effectuationStack
            )
        )
        synchronousExecution._effectuationStack.append(.describedPart(description: description))
        let result = try await work()
        synchronousExecution._effectuationStack.removeLast()
        synchronousExecution.ExecutionEventProcessor.process(
            ExecutionEvent(
                type: .progress,
                level: synchronousExecution.level,
                structuralID: structuralID,
                event: .endingDescribedPart(
                    description: description
                ),
                effectuationStack: synchronousExecution.effectuationStack
            )
        )
        return result
    }
    
    private func after(step: StepID, structuralID: UUID?, description: String?, forced: Bool, secondsElapsed: Double) async {
        if synchronousExecution._stopped {
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .stoppedStep(
                        id: step,
                        description: description
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
        } else {
            synchronousExecution.ExecutionEventProcessor.process(
                ExecutionEvent(
                    type: .progress,
                    level: synchronousExecution.level,
                    structuralID: structuralID,
                    event: .endingStep(
                        id: step,
                        description: description,
                        forced: forced
                    ),
                    effectuationStack: synchronousExecution.effectuationStack
                )
            )
        }
    }
    
    /// Executes only if the step did not execute before.
    public func effectuate<T>(_ description: String? = nil, checking step: StepID, work: () async throws -> T) async rethrows -> T? {
        let (execute: toBeExecuted, forced: forced, structuralID: structuralID) = await effectuateTest(forStep: step, withDescription: description)
        if toBeExecuted {
            let start = DispatchTime.now()
            let result = try await execute(step: step, description: description, force: false, work: work)
            await after(step: step, structuralID: structuralID, description: description, forced: forced, secondsElapsed: elapsedSeconds(start: start))
            return result
        } else {
            return nil
        }
    }
    
}
