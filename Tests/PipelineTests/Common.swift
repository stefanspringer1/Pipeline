import Pipeline

protocol Logger {
    func log(_ message: String)
}

class CollectingLogger: Logger {
    
    private var _messages = [String]()
    
    var messages: [String] { _messages }
    
    func log(_ message: String) {
        _messages.append(message)
    }
    
    func log(_ message: String, indentation: String) {
        _messages.append(indentation + message)
    }
    
}

class ExecutionInfoConsumerForLogger<MetaData: CustomStringConvertible>: ExecutionInfoConsumer {
    
    var logger: Logger
    var excutionInfoFormat: ExecutionInfoFormat?
    
    init(logger: Logger, excutionInfoFormat: ExecutionInfoFormat? = nil) {
        self.logger = logger
        self.excutionInfoFormat = excutionInfoFormat
    }
    
    func consume(_ executionInfo: ExecutionInfo<MetaData>) {
        if let excutionInfoFormat {
            logger.log(executionInfo.description(format: excutionInfoFormat))
        } else {
            logger.log(executionInfo.description)
        }
    }
}

// from README:
class PrintingLogger: Logger {
    
    func log(_ message: String) {
        print(message)
    }
    
}

struct MyMetaData: ExecutionMetaData {
    
    let applicationName: String
    let processID: String
    let workItemInfo: String
    
    var description: String {
        "\(applicationName): \(processID)/\(workItemInfo)"
    }
}

class PrintingxecutionInfoConsumerWithContext<MetaData: CustomStringConvertible>: ExecutionInfoConsumer {
    
    let applicationName: String
    let processID: String
    let workItemInfo: String

    init(applicationName: String, processID: String, forWorkItem workItemInfo: String) {
        self.applicationName = applicationName
        self.processID = processID
        self.workItemInfo = workItemInfo
    }
    
    func consume(_ executionInfo: ExecutionInfo<MetaData>) {
        print("\(applicationName): \(processID)/\(workItemInfo): \(executionInfo)")
    }
}

extension String {
    var firstPathPart: Substring {
        self.split(separator: "/", omittingEmptySubsequences: false).first!
    }
}
