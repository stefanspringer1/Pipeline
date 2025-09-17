import Pipeline

protocol Logger {
    func log(_ message: String)
    func log(_ message: String, indentation: String)
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

class ExecutionInfoConsumerForLogger: ExecutionInfoConsumer {
    
    private var logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func consume(_ executionInfo: ExecutionInfo, atLevel level: Int) {
        logger.log("\(String(repeating: "    ", count: level))\(executionInfo)")
    }
}

// from README:
class PrintingLogger: Logger {
    
    func log(_ message: String) {
        print(message)
    }
    
    func log(_ message: String, indentation: String) {
        print(indentation + message)
    }
    
}

// from README:
class ExecutionInfoConsumerForLoggerWithContext: ExecutionInfoConsumer {
    
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
    
    func consume(_ executionInfo: ExecutionInfo, atLevel level: Int) {
        logger.log("\(applicationName): \(processID)/\(workItemInfo): \(String(repeating: "    ", count: level))\(executionInfo)")
    }
}

class PrintingxecutionInfoConsumerWithContext: ExecutionInfoConsumer {
    
    let applicationName: String
    let processID: String
    let workItemInfo: String

    init(applicationName: String, processID: String, forWorkItem workItemInfo: String) {
        self.applicationName = applicationName
        self.processID = processID
        self.workItemInfo = workItemInfo
    }
    
    func consume(_ executionInfo: ExecutionInfo, atLevel level: Int) {
        print("\(applicationName): \(processID)/\(workItemInfo): \(String(repeating: "    ", count: level))\(executionInfo)")
    }
}
