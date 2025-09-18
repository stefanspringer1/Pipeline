import Foundation

public protocol ExecutionMetaData: CustomStringConvertible, Sendable {
    
}

public protocol ExecutionInfoConsumer<MetaData> {
    associatedtype MetaData: CustomStringConvertible
    func consume(_ executionInfo: ExecutionInfo<MetaData>)
}

public struct StepID: Hashable, CustomStringConvertible, Sendable {
    
    public let crossModuleFileDesignation: String
    public let functionSignature: String
    
    public init(crossModuleFileDesignation: String, functionSignature: String) {
        self.crossModuleFileDesignation = crossModuleFileDesignation
        self.functionSignature = functionSignature
    }
    
    public var description: String { "\(functionSignature)@\(crossModuleFileDesignation)" }
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
        switch self {
        case .step(step: let step, description: let description):
            return "\(stepPrefix)\(step.description)\(description != nil ? " (\(description!))" : "")"
        case .dispensablePart(name: let id, description: let description):
            return "\(dispensablePartPrefix)\"\(id)\"\(description != nil ? " (\(description!))" : "")"
        case .optionalPart(name: let id, description: let description):
            return "\(optionalPartPrefix)\"\(id)\"\(description != nil ? " (\(description!))" : "")"
        case .describedPart(description: let description):
            return "\(describedPartPrefix)\"\(description)\""
        case .forcing:
            return "forcing"
        }
    }
    
}

extension Array where Element == Effectuation {
    var executionPath: String {
        self.map{ $0.description }.joined(separator: " -> ")
    }
}

public enum ExecutionInfoFormat {
    case full
    case bare
    case bareIndented
}

public struct ExecutionInfo<MetaData: CustomStringConvertible>: CustomStringConvertible {
    
    let type: InfoType
    let time: Date
    let metadata: MetaData
    let level: Int
    let structuralID: UUID
    let event: ExecutionEvent
    
    internal init(
        type: InfoType,
        time: Date = Date.now,
        metadata: MetaData,
        level: Int,
        structuralID: UUID,
        event: ExecutionEvent
    ) {
        self.type = type
        self.time = time
        self.metadata = metadata
        self.level = level
        self.structuralID = structuralID
        self.event = event
    }
    
    public var description: String {
        "\(time): \(metadata): \(String(repeating: "    ", count: level)){\(type)} \(event)"
    }
    
    public func description(executionInfoDescription: ExecutionInfoFormat) -> String {
        switch executionInfoDescription {
        case .full:
            description
        case .bare:
            event.description
        case .bareIndented:
            "\(String(repeating: "    ", count: level))\(event)"
        }
        
    }
    
    public var bareIndentedDescription: String {
        "\(String(repeating: "    ", count: level))\(event)"
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
            "skipping step in aborted execution \(id)\(description != nil ? " (\(description!))" : "")"
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
