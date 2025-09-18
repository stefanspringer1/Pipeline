// The message type that informs about the severity a message.
//
// It conforms to `Comparable` so there is an order of severity.
public enum MessageType: Comparable, Codable, Sendable {
    
    /// Debugging information.
    case debug
    
    /// Information about the progress (e.g. the steps being executed).
    case progress
    
    /// Information from the processing.
    case info
    
    /// Information about the execution for a work item, e.g. starting.
    case iteration
    
    /// Warnings from the processing.
    case warning
    
    /// Errors from the processing.
    case error
    
    /// A fatal error, the execution (for the data item being processed) is
    /// then abandoned.
    case fatal
    
    /// The program or process that has been startet to be in charge for
    /// the whole processing of a work item is lost (crashed or hanging).
    case loss
    
    /// A deadly error, i.e. not only the processing for one work item
    /// has to be abandoned, but the whole processing cannot continue.
    case deadly

}
