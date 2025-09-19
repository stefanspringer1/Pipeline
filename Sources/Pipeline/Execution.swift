import Foundation
import Localization

/// Manages the execution of steps. In particular
/// - prevents double execution of steps
/// - keeps global information for logging
public final class Execution<MetaData: ExecutionMetaData> {
    
    let language: Language
    
    let metadata: MetaData
    
    var executionInfoConsumer: any ExecutionInfoConsumer<MetaData>
    
    let dispensedWith: Set<String>?
    let activatedOptions: Set<String>?
    
    var executedSteps = Set<StepID>()
    
    var _effectuationStack: [Effectuation]
    
    public var effectuationStack: [Effectuation] {
        _effectuationStack
    }
    
    public var waitNotPausedFunction: (() -> ())?
    
    public func setting(
        waitNotPausedFunction: (() -> ())? = nil
    ) -> Self {
        if let waitNotPausedFunction {
            self.waitNotPausedFunction = waitNotPausedFunction
        }
        return self
    }
    
    public var parallel: Execution<MetaData> {
        Execution<MetaData>(
            metadata: metadata,
            executionInfoConsumer: executionInfoConsumer,
            effectuationStack: _effectuationStack,
            waitNotPausedFunction: waitNotPausedFunction
        )
    }
    
    public init(
        language: Language = .en,
        metadata: MetaData,
        executionInfoConsumer: any ExecutionInfoConsumer<MetaData>,
        showSteps: Bool = false,
        debug: Bool = false,
        effectuationStack: [Effectuation] = [Effectuation](),
        withOptions activatedOptions: Set<String>? = nil,
        dispensingWith dispensedWith: Set<String>? = nil,
        waitNotPausedFunction: (() -> ())? = nil,
        logFileInfo: URL? = nil
    ) {
        self.language = language
        self.metadata = metadata
        self._effectuationStack = effectuationStack
        self.executionInfoConsumer = executionInfoConsumer
        self.activatedOptions = activatedOptions
        self.dispensedWith = dispensedWith
        self.waitNotPausedFunction = waitNotPausedFunction
    }
    
    public var level: Int { _effectuationStack.count }
    
    public var executionPath: String { _effectuationStack.executionPath }
    
    var _stopped = false
    
    public func stop(reason: String) {
        executionInfoConsumer.consume(
            ExecutionInfo(
                type: .progress,
                metadata: metadata,
                level: level,
                structuralID: UUID(),
                event: .stoppingExecution(
                    reason: reason
                ),
                effectuationStack: effectuationStack
            )
        )
        _stopped = true
    }
    
    public var stopped: Bool { _stopped }
    
    var forceValues = [Bool]()
    var appeaseTypes = [InfoType]()
    
    func waitNotPaused() {
        waitNotPausedFunction?() // wait if the execution is paused
    }
    
    /// Force all contained work to be executed, even if already executed before.
    fileprivate func execute<T>(
        step: StepID?,
        description: String?,
        force: Bool,
        appeaseTo appeaseType: InfoType? = nil,
        work: () throws -> T
    ) rethrows -> T {
        waitNotPaused() // wait if the execution is paused
        forceValues.append(force)
        if let appeaseType {
            appeaseTypes.append(appeaseType)
        }
        if let step {
            _effectuationStack.append(.step(step: step, description: description))
        }
        let result = try work()
        if step != nil {
            _effectuationStack.removeLast()
        }
        forceValues.removeLast()
        if appeaseType != nil {
            appeaseTypes.removeLast()
        }
        return result
    }
    
    /// Executes always.
    public func force<T>(work: () throws -> T) rethrows -> T? {
        let structuralID = UUID()
        executionInfoConsumer.consume(
            ExecutionInfo(
                type: .progress,
                metadata: metadata,
                level: level,
                structuralID: structuralID,
                event: .beginningForcingSteps,
                effectuationStack: effectuationStack
            )
        )
        _effectuationStack.append(.forcing)
        
        func rewind() {
            _effectuationStack.removeLast()
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .endingForcingSteps,
                    effectuationStack: effectuationStack
                )
            )
        }
        
        let t: T?
        do {
            t = try execute(step: nil, description: nil, force: true, work: work)
            rewind()
        } catch {
            rewind()
            throw error
        }
        return t
    }
    
    /// After execution, disremember what has been executed.
    public func disremember<T>(work: () throws -> T) rethrows -> T? {
        let oldExecutedSteps = executedSteps
        let result = try execute(step: nil, description: nil, force: false, work: work)
        executedSteps = oldExecutedSteps
        return result
    }
    
    /// Executes always if in a forced context.
    public func inheritForced<T>(work: () throws -> T) rethrows -> T? {
        try execute(step: nil, description: nil, force: forceValues.last == true, work: work)
    }
    
    /// Something that does not run in the normal case but ca be activated. Should use module name as prefix.
    public func optional<T>(named partName: String, description: String? = nil, work: () throws -> T) rethrows -> T? {
        let result: T?
        let structuralID = UUID()
        if activatedOptions?.contains(partName) != true || dispensedWith?.contains(partName) == true {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .skippingOptionalPart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
            result = nil
        } else {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .beginningOptionalPart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
            _effectuationStack.append(.optionalPart(name: partName, description: description))
            result = try execute(step: nil, description: nil, force: false, work: work)
            _effectuationStack.removeLast()
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .endingOptionalPart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
        }
        return result
    }
    
    /// Something that runs in the normal case but ca be dispensed with. Should use module name as prefix.
    public func dispensable<T>(named partName: String, description: String? = nil, work: () throws -> T) rethrows -> T? {
        let result: T?
        let structuralID = UUID()
        if dispensedWith?.contains(partName) == true {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .skippingDispensablePart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
            result = nil
        } else {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .beginningDispensablePart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
            _effectuationStack.append(.dispensablePart(name: partName, description: description))
            result = try execute(step: nil, description: description, force: false, work: work)
            _effectuationStack.removeLast()
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .endingDispensablePart(
                        name: partName,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
        }
        return result
    }
    
    /// Make worse message type than `Error` to type `Error` in contained calls.
    public func appease<T>(to appeaseType: InfoType? = .error, work: () throws -> T) rethrows -> T? {
        try execute(step: nil, description: nil, force: false, appeaseTo: appeaseType, work: work)
    }
    
    private func effectuateTest(forStep step: StepID, withDescription description: String?) -> (execute: Bool, forced: Bool, structuralID: UUID) {
        let structuralID = UUID()
        if _stopped || executionInfoConsumer.executionStopped {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .skippingStepInStoppedExecution(
                        id: step,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
            return (execute: false, forced: false, structuralID: structuralID)
        } else if !executedSteps.contains(step) {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                        event: .beginningStep(
                        id: step,
                        description: description,
                        forced: false
                    ),
                    effectuationStack: effectuationStack
                )
            )
            executedSteps.insert(step)
            return (execute: true, forced: false, structuralID: structuralID)
        } else if forceValues.last == true {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .beginningStep(
                        id: step,
                        description: description,
                        forced: true
                    ),
                    effectuationStack: effectuationStack
                )
            )
            executedSteps.insert(step)
            return (execute: true, forced: true, structuralID: structuralID)
        } else {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .skippingPreviouslyExecutedStep(
                        id: step,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
            return (execute: false, forced: false, structuralID: structuralID)
        }
    }
    
    /// Logging some work (that is not a step) as progress.
    public func doing<T>(withID id: String? = nil, _ description: String, work: () throws -> T) rethrows -> T? {
        let structuralID = UUID()
        executionInfoConsumer.consume(
            ExecutionInfo(
                type: .progress,
                metadata: metadata,
                level: level,
                structuralID: structuralID,
                event: .beginningDescribedPart(
                    description: description
                ),
                effectuationStack: effectuationStack
            )
        )
        _effectuationStack.append(.describedPart(description: description))
        let result = try work()
        _effectuationStack.removeLast()
        executionInfoConsumer.consume(
            ExecutionInfo(
                type: .progress,
                metadata: metadata,
                level: level,
                structuralID: structuralID,
                event: .endingDescribedPart(
                    description: description
                ),
                effectuationStack: effectuationStack
            )
        )
        return result
    }
    
    private func after(step: StepID, structuralID: UUID, description: String?, forced: Bool, secondsElapsed: Double) {
        if _stopped {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .stoppedStep(
                        id: step,
                        description: description
                    ),
                    effectuationStack: effectuationStack
                )
            )
        } else {
            executionInfoConsumer.consume(
                ExecutionInfo(
                    type: .progress,
                    metadata: metadata,
                    level: level,
                    structuralID: structuralID,
                    event: .endingStep(
                        id: step,
                        description: description,
                        forced: forced
                    ),
                    effectuationStack: effectuationStack
                )
            )
        }
    }
    
    /// Executes only if the step did not execute before.
    public func effectuate<T>(_ description: String? = nil, checking step: StepID, work: () throws -> T) rethrows -> T? {
        let (execute: toBeExecuted, forced: forced, structuralID: structuralID) = effectuateTest(forStep: step, withDescription: description)
        if toBeExecuted {
            let start = DispatchTime.now()
            let result = try execute(step: step, description: description, force: false, work: work)
            after(step: step, structuralID: structuralID, description: description, forced: forced, secondsElapsed: elapsedSeconds(start: start))
            return result
        } else {
            return nil
        }
    }
    
}
