import Foundation

/// Manages the execution of steps. In particular
/// - prevents double execution of steps
/// - keeps global information for logging
public class Execution {
    
    var executedSteps = Set<StepID>()
    
    var _effectuationStack: [Effectuation]
    
    public var effectuationStack: [Effectuation] {
        _effectuationStack
    }
    
    var executionInfoConsumer: ExecutionInfoConsumer
    
    public func setting(
        waitNotPausedFunction: (() -> ())? = nil
    ) -> Self {
        if let waitNotPausedFunction {
            self.waitNotPausedFunction = waitNotPausedFunction
        }
        return self
    }
    
    let dispensedWith: Set<String>?
    let activatedOptions: Set<String>?
    
    public var parallel: Execution {
        Execution(
            executionInfoConsumer: executionInfoConsumer,
            effectuationStack: _effectuationStack,
            waitNotPausedFunction: waitNotPausedFunction
        )
    }
    
    public var waitNotPausedFunction: (() -> ())?
    
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
        self._effectuationStack = effectuationStack
        self.executionInfoConsumer = executionInfoConsumer
        self.activatedOptions = activatedOptions
        self.dispensedWith = dispensedWith
        self.waitNotPausedFunction = waitNotPausedFunction
    }
    
    public var level: Int { _effectuationStack.count }
    
    public var executionPath: String { _effectuationStack.executionPath }
    
    var _aborted = false
    
    public func abort(reason: String) {
        executionInfoConsumer.consume(
            .abortingExecution(
                reason: reason
            ),
            atLevel: level
        )
        _aborted = true
    }
    
    public var aborted: Bool { _aborted }
    
    var forceValues = [Bool]()
    
    public var currentIndentation: String { String(repeating: "    ", count: level) }
    
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
        
        (waitNotPausedFunction ?? waitNotPaused)() // wait if the execution is paused
    }
    
    /// Force all contained work to be executed, even if already executed before.
    fileprivate func execute<T>(step: StepID?, description: String?, force: Bool, work: () throws -> T) rethrows -> T {
        waitNotPaused() // wait if the execution is paused
        forceValues.append(force)
        if let step {
            _effectuationStack.append(.step(step: step, description: description))
        }
        let result = try work()
        if step != nil {
            _effectuationStack.removeLast()
        }
        forceValues.removeLast()
        return result
    }
    
    /// Executes always.
    public func force<T>(work: () throws -> T) rethrows -> T? {
        
        executionInfoConsumer.consume(
            .beginningForcingSteps,
            atLevel: level
        )
        _effectuationStack.append(.forcing)
        
        func rewind() {
            _effectuationStack.removeLast()
            executionInfoConsumer.consume(
                .endingForcingSteps,
                atLevel: level
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
        if activatedOptions?.contains(partName) != true || dispensedWith?.contains(partName) == true {
            executionInfoConsumer.consume(
                .skippingOptionalPart(
                    name: partName,
                    description: description
                ),
                atLevel: level
            )
            result = nil
        } else {
            executionInfoConsumer.consume(
                .beginningOptionalPart(
                    name: partName,
                    description: description
                ),
                atLevel: level
            )
            _effectuationStack.append(.optionalPart(name: partName, description: description))
            result = try execute(step: nil, description: nil, force: false, work: work)
            _effectuationStack.removeLast()
            executionInfoConsumer.consume(
                .endingOptionalPart(
                    name: partName,
                    description: description
                ),
                atLevel: level
            )
        }
        return result
    }
    
    /// Something that runs in the normal case but ca be dispensed with. Should use module name as prefix.
    public func dispensable<T>(named partName: String, description: String? = nil, work: () throws -> T) rethrows -> T? {
        let result: T?
        if dispensedWith?.contains(partName) == true {
            executionInfoConsumer.consume(
                .skippingDispensablePart(
                    name: partName,
                    description: description
                ),
                atLevel: level
            )
            result = nil
        } else {
            executionInfoConsumer.consume(
                .beginningDispensablePart(
                    name: partName,
                    description: description
                ),
                atLevel: level
            )
            _effectuationStack.append(.dispensablePart(name: partName, description: description))
            result = try execute(step: nil, description: description, force: false, work: work)
            _effectuationStack.removeLast()
            executionInfoConsumer.consume(
                .endingDispensablePart(
                    name: partName,
                    description: description
                ),
                atLevel: level
            )
        }
        return result
    }
    
    private func effectuateTest(forStep step: StepID, withDescription description: String?) -> (execute: Bool, forced: Bool) {
        if _aborted {
            executionInfoConsumer.consume(
                .skippingStepInAbortedExecution(
                    id: step,
                    description: description
                ),
                atLevel: level
            )
            return (execute: false, forced: false)
        } else if !executedSteps.contains(step) {
            executionInfoConsumer.consume(
                .beginningStep(
                    id: step,
                    description: description,
                    forced: false
                ),
                atLevel: level
            )
            executedSteps.insert(step)
            return (execute: true, forced: false)
        } else if forceValues.last == true {
            executionInfoConsumer.consume(
                .beginningStep(
                    id: step,
                    description: description,
                    forced: true
                ),
                atLevel: level
            )
            executedSteps.insert(step)
            return (execute: true, forced: true)
        } else {
            executionInfoConsumer.consume(
                .skippingPreviouslyExecutedStep(
                    id: step,
                    description: description
                ),
                atLevel: level
            )
            return (execute: false, forced: false)
        }
    }
    
    /// Logging some work (that is not a step) as progress.
    public func doing<T>(withID id: String? = nil, _ description: String, work: () throws -> T) rethrows -> T? {
        executionInfoConsumer.consume(
            .beginningDescribedPart(
                description: description
            ),
            atLevel: level
        )
        _effectuationStack.append(.describedPart(description: description))
        let result = try work()
        _effectuationStack.removeLast()
        executionInfoConsumer.consume(
            .endingDescribedPart(
                description: description
            ),
            atLevel: level
        )
        return result
    }
    
    private func after(step: StepID, description: String?, forced: Bool, secondsElapsed: Double) {
        if _aborted {
            executionInfoConsumer.consume(
                .abortedStep(
                    id: step,
                    description: description
                ),
                atLevel: level
            )
        } else {
            executionInfoConsumer.consume(
                .endingStep(
                    id: step,
                    description: description,
                    forced: forced
                ),
                atLevel: level
            )
        }
    }
    
    /// Executes only if the step did not execute before.
    public func effectuate<T>(_ description: String? = nil, checking step: StepID, work: () throws -> T) rethrows -> T? {
        let (execute: toBeExecuted,forced: forced) = effectuateTest(forStep: step, withDescription: description)
        if toBeExecuted {
            let start = DispatchTime.now()
            let result = try execute(step: step, description: description, force: false, work: work)
            after(step: step, description: description, forced: forced, secondsElapsed: elapsedSeconds(start: start))
            return result
        } else {
            return nil
        }
    }
    
}
