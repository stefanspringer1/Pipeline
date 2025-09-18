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
    var excutionInfoFormat: ExecutionInfoFormat
    
    init(logger: Logger, excutionInfoFormat: ExecutionInfoFormat = .full) {
        self.logger = logger
        self.excutionInfoFormat = excutionInfoFormat
    }
    
    func consume(_ executionInfo: ExecutionInfo<MetaData>) {
        logger.log(executionInfo.description(executionInfoDescription: excutionInfoFormat))
    }
}

// from README:
class PrintingLogger: Logger {
    
    func log(_ message: String) {
        print(message)
    }
    
}

// from README:
class ExecutionInfoConsumerForLoggerWithContext<MetaData: CustomStringConvertible>: ExecutionInfoConsumer {
    
    private var logger: Logger
    let applicationName: String
    let processID: String
    let workItemInfo: String

    init(logger: Logger, applicationName: String, processID: String, forWorkItem workItemInfo: String) {
        self.logger = logger
        self.applicationName = applicationName
        self.processID = processID
        self.workItemInfo = workItemInfo
    }
    
    func consume(_ executionInfo: ExecutionInfo<MetaData>) {
        logger.log(executionInfo.description)
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
