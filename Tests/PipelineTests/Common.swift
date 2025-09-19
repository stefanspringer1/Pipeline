import Foundation
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
    
}

class ConcurrentCollectingLogger: Logger {
    
    private var _messages = [String]()
    let messagesSemaphore = DispatchSemaphore(value: 1)
    
    /// Gets the current messages.
    var messages: [String] {
        messagesSemaphore.wait()
        let value = _messages
        messagesSemaphore.signal()
        return value
    }
    
    internal let group = DispatchGroup()
    internal let queue = DispatchQueue(label: "ConcurrentCollectingLogger", qos: .background)
    
    public func log(_ message: String) {
        group.enter()
        self.queue.sync {
            messagesSemaphore.wait()
            self._messages.append(message)
            messagesSemaphore.signal()
            self.group.leave()
        }
    }
    
    /// Wait until all logging is done.
    public func wait() {
        group.wait()
    }
    
}

class ExecutionInfoConsumerForLogger<MetaData: CustomStringConvertible>: ExecutionInfoConsumer {
    
    var logger: Logger
    let minimalInfoType: InfoType?
    var excutionInfoFormat: ExecutionInfoFormat?
    
    init(logger: Logger, withMinimalInfoType minimalInfoType: InfoType? = nil, excutionInfoFormat: ExecutionInfoFormat? = nil) {
        self.logger = logger
        self.minimalInfoType = minimalInfoType
        self.excutionInfoFormat = excutionInfoFormat
    }
    
    func consume(_ executionInfo: ExecutionInfo<MetaData>) {
        if let minimalInfoType, executionInfo.type < minimalInfoType {
            return
        }
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

struct MyMetaData1: ExecutionMetaData {
    
    let applicationName: String
    let processID: String
    let workItemInfo: String
    
    var description: String {
        "\(applicationName): \(processID)/\(workItemInfo)"
    }
}

struct MyMetaData2: ExecutionMetaData {
    
    let server: String
    let processID: String
    let path: String
    
    var description: String {
        "\(server): \(processID)/\(path)"
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

func elapsedTime(of f: () -> Void) -> Double {
    let startTime = DispatchTime.now()
    f()
    let endTime = DispatchTime.now()
    let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    return Double(elapsedTime) / 1_000_000_000
}

func elapsedTime(of f: () async -> Void) async -> Double {
    let startTime = DispatchTime.now()
    await f()
    let endTime = DispatchTime.now()
    let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    return Double(elapsedTime) / 1_000_000_000
}

/// Process the items in `batch` in parallel by the function `worker` using `threads` number of threads.
public func executeInParallel<Seq: Sequence>(batch: Seq, threads: Int, worker: @escaping (Seq.Element) -> ()) {
    let queue = DispatchQueue(label: "AyncLogger", attributes: .concurrent)
    let group = DispatchGroup()
    let semaphore = DispatchSemaphore(value: threads)
    
    for item in batch {
        
        group.enter()
        semaphore.wait()
        queue.async {
            worker(item)
            semaphore.signal()
            group.leave()
        }
        
    }
    
    group.wait()
}
