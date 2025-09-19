import Foundation

public protocol ExecutionMetaData: CustomStringConvertible, Sendable {}

public protocol ExecutionInfoConsumer<MetaData> {
    associatedtype MetaData: CustomStringConvertible
    func consume(_ executionInfo: ExecutionInfo<MetaData>)
    var executionAborted: Bool { get }
}

public struct StepID: Hashable, CustomStringConvertible, Sendable {
    
    public let crossModuleFileDesignation: String
    public let functionSignature: String
    
    public init(crossModuleFileDesignation: String, functionSignature: String) {
        self.crossModuleFileDesignation = crossModuleFileDesignation
        self.functionSignature = functionSignature
    }
    
    public var description: String { "\(functionSignature)@\(crossModuleFileDesignation.split(separator: "/", omittingEmptySubsequences: false).first!)" }
}

public let stepPrefix = "step "
public let dispensablePartPrefix = "dispensable part "
public let optionalPartPrefix = "optional part "
public let describedPartPrefix = "doing "

public enum Effectuation: CustomStringConvertible, Sendable {
    
    case step(step: StepID, description: String?)
    case dispensablePart(name: String, description: String?)
    case optionalPart(name: String, description: String?)
    case describedPart(description: String)
    case forcing
    
    public var description: String {
        description(withDescription: true)
    }
    
    public var short: String {
        description(withDescription: false)
    }
    
    public func description(withDescription: Bool) -> String {
        switch self {
        case .step(step: let step, description: let description):
            return "\(stepPrefix)\(step)\(withDescription && description != nil ? " (\(description!))" : "")"
        case .dispensablePart(name: let id, description: let description):
            return "\(dispensablePartPrefix)\"\(id)\"\(withDescription && description != nil ? " (\(description!))" : "")"
        case .optionalPart(name: let id, description: let description):
            return "\(optionalPartPrefix)\"\(id)\"\(withDescription && description != nil ? " (\(description!))" : "")"
        case .describedPart(description: let description):
            return "\(describedPartPrefix)\"\(description)\""
        case .forcing:
            return "forcing"
        }
    }
    
}

extension Array where Element == Effectuation {
    
    var executionPathForEffectuation: String {
        self.map{ $0.short + " -> " }.joined()
    }
    
    var executionPath: String {
        self.map{ $0.short }.joined(separator: " -> ")
    }
    
}

public struct ExecutionInfoFormat {
    
    let withTime: Bool
    let withMetaData: Bool
    let withIndentation: Bool
    let withType: Bool
    let withExecutionPath: Bool
    
    public init(
        withTime: Bool = false,
        withMetaData: Bool = false,
        withIndentation: Bool = false,
        withType: Bool = false,
        withExecutionPath: Bool = false
    ) {
        self.withTime = withTime
        self.withMetaData = withMetaData
        self.withIndentation = withIndentation
        self.withType = withType
        self.withExecutionPath = withExecutionPath
    }
}

public struct ExecutionInfo<MetaData: CustomStringConvertible>: CustomStringConvertible {
    
    public let type: InfoType
    public let originalType: InfoType? // non-appeased
    public let time: Date
    public let metadata: MetaData
    public let level: Int
    public let structuralID: UUID
    public let event: ExecutionEvent
    public let effectuationStack: [Effectuation]
    
    public func isMessage() -> Bool { if case .message = event { true } else { false } }
    
    internal init(
        type: InfoType,
        originalType: InfoType? = nil,
        time: Date = Date.now,
        metadata: MetaData,
        level: Int,
        structuralID: UUID,
        event: ExecutionEvent,
        effectuationStack: [Effectuation]
    ) {
        self.type = type
        self.originalType = originalType
        self.time = time
        self.metadata = metadata
        self.level = level
        self.structuralID = structuralID
        self.event = event
        self.effectuationStack = effectuationStack
    }
    
    public var description: String {
        return description(
            withTime: true,
            withMetaData: true,
            withIndentation: true,
            withType: true,
            withExecutionPath: true
        )
    }
    
    public func description(
        withTime: Bool = false,
        withMetaData: Bool = false,
        withIndentation: Bool = false,
        withType: Bool = false,
        withExecutionPath: Bool
    ) -> String {
        [
            withTime ? "\(time.description):" : nil,
            withMetaData ? "\(metadata):" : nil,
            withIndentation && level > 0 ? "\(String(repeating: " ", count: level * 4 - 1))" : nil,
            withType ? "{\(type)}" : nil,
            event.description,
            withExecutionPath && !effectuationStack.isEmpty ? "[@@ \(isMessage() ? effectuationStack.executionPath : effectuationStack.executionPathForEffectuation)]" : nil
        ].compactMap({ $0 }).joined(separator: " ")
    }
    
    public func description(format executionInfoFormat: ExecutionInfoFormat) -> String {
        description(
            withTime: executionInfoFormat.withTime,
            withMetaData: executionInfoFormat.withMetaData,
            withIndentation: executionInfoFormat.withIndentation,
            withType: executionInfoFormat.withType,
            withExecutionPath: executionInfoFormat.withExecutionPath
        )
    }
    
}

public enum ExecutionEvent: CustomStringConvertible {
    
    case beginningStep(id: StepID, description: String?, forced: Bool)
    case endingStep(id: StepID, description: String?, forced: Bool)
    case abortedStep(id: StepID, description: String?)
    case skippingPreviouslyExecutedStep(id: StepID, description: String?)
    case skippingStepInAbortedExecution(id: StepID, description: String?)
    
    case beginningDispensablePart(name: String, description: String?)
    case endingDispensablePart(name: String, description: String?)
    case skippingDispensablePart(name: String, description: String?)
    
    case beginningOptionalPart(name: String, description: String?)
    case endingOptionalPart(name: String, description: String?)
    case skippingOptionalPart(name: String, description: String?)
    
    case beginningDescribedPart(description: String)
    case endingDescribedPart(description: String)
    
    case abortingExecution(reason: String)
    
    case beginningForcingSteps
    case endingForcingSteps
    
    case message(message: String)
    
    public var description: String {
        switch self {
        case .abortingExecution(reason: let reason):
            "aborting execution: \(reason)"
        case .beginningStep(id: let id, description: let description, forced: let forced):
            "beginning \(forced ? "forced " : "")step \(id)\(description != nil ? " (\(description!))" : "")"
        case .endingStep(id: let id, description: let description, forced: let forced):
            "ending \(forced ? "forced " : "")step \(id)\(description != nil ? " (\(description!))" : "")"
        case .skippingPreviouslyExecutedStep(id: let id, description: let description):
            "skipping previously executed step \(id)\(description != nil ? " (\(description!))" : "")"
        case .skippingStepInAbortedExecution(id: let id, description: let description):
            "skipping in an aborted environment step \(id)\(description != nil ? " (\(description!))" : "")"
        case .abortedStep(id: let id, description: let description):
            "aborted step \(id)\(description != nil ? " (\(description!))" : "")"
        case .beginningDispensablePart(name: let name, description: let description):
            "beginning dispensible part \"\(name)\"\(description != nil ? " (\(description!))" : "")"
        case .endingDispensablePart(name: let name, description: let description):
            "ending dispensible part \"\(name)\"\(description != nil ? " (\(description!))" : "")"
        case .skippingDispensablePart(name: let name, description: let description):
            "skipping dispensible part \"\(name)\"\(description != nil ? " (\(description!))" : "")"
        case .beginningOptionalPart(name: let name, description: let description):
            "beginning optional part \"\(name)\"\(description != nil ? " (\(description!))" : "")"
        case .endingOptionalPart(name: let name, description: let description):
            "ending optional part \"\(name)\"\(description != nil ? " (\(description!))" : "")"
        case .skippingOptionalPart(name: let name, description: let description):
            "skipping optional part \"\(name)\"\(description != nil ? " (\(description!))" : "")"
        case .beginningDescribedPart(description: let description):
            "beginning \"\(description)\""
        case .endingDescribedPart(description: let description):
            "ending \"\(description)\""
        case .beginningForcingSteps:
            "beginning forcing steps"
        case .endingForcingSteps:
            "ending forcing steps"
        case .message(message: let message):
            message
        }
    }
}

/// Get the ellapsed seconds since `start`.
/// The time to compare to is either the current time or the value of the argument `reference`.
func elapsedSeconds(start: DispatchTime, reference: DispatchTime = DispatchTime.now()) -> Double {
    return Double(reference.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
}
