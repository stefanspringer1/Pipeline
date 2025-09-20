import Foundation
import Pipeline

protocol Logger {
    func log(_ message: String)
}

// from README:
public class PrintingLogger: Logger {
    
    public func log(_ message: String) {
        print(message)
    }
    
}

public class CollectingLogger: Logger {
    
    private var _messages = [String]()
    
    var messages: [String] { _messages }
    
    public func log(_ message: String) {
        _messages.append(message)
    }
    
}

public class ConcurrentCollectingLogger: Logger {
    
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

public class ExecutionEventProcessorForLogger: ExecutionEventProcessor {
    
    public let metadataInfo: String
    public let metadataInfoForUserInteraction: String
    
    private var logger: Logger
    private let minimalInfoType: InfoType?
    private var excutionInfoFormat: ExecutionInfoFormat?
    
    init(
        withMetaDataInfo metadataInfo: String,
        withMetaDataInfoForUserInteraction metadataInfoForUserInteraction: String? = nil,
        logger: Logger,
        withMinimalInfoType minimalInfoType: InfoType? = nil,
        excutionInfoFormat: ExecutionInfoFormat? = nil
    ) {
        self.metadataInfo = metadataInfo
        self.metadataInfoForUserInteraction = metadataInfoForUserInteraction ?? metadataInfo
        self.logger = logger
        self.minimalInfoType = minimalInfoType
        self.excutionInfoFormat = excutionInfoFormat
    }
    
    public func process(_ executionEvent: ExecutionEvent) {
        if let minimalInfoType, executionEvent.type < minimalInfoType {
            return
        }
        if let excutionInfoFormat {
            logger.log(executionEvent.description(format: excutionInfoFormat, withMetaDataInfo: metadataInfo))
        } else {
            logger.log(executionEvent.description(withMetaDataInfo: metadataInfo))
        }
    }
    
}

struct MyMetaData: CustomStringConvertible {
    
    let applicationName: String
    let processID: String
    let workItemInfo: String
    
    var description: String {
        "\(applicationName): \(processID)/\(workItemInfo)"
    }
}

/// Process the items in `batch` in parallel by the function `worker` using `threads` number of threads.
public func executeInParallel<Seq: Sequence>(batch: Seq, threads: Int, worker: @escaping (Seq.Element) -> ()) {
    let queue = DispatchQueue(label: "executeInParallel", attributes: .concurrent)
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

public struct TestError: Error, CustomStringConvertible  {
    public let description: String
    
    var localizedDescription: String { description }
    
    public init(_ description: String) {
        self.description = description
    }
}

struct UUIDReplacements {
    var count = 0
    var mapped = [String:String]()
    
    mutating func replacement(for token: String) -> String {
        if let existing = mapped[token] {
            return existing
        } else {
            count += 1
            let replacement = "#\(count)"
            mapped[token] = replacement
            return replacement
        }
    }
    
    mutating func doReplacements(in text: String) -> String {
        var parts = [Substring]()
        var rest = Substring(text)
        while let match = rest.firstMatch(of: /[0-9A-Z]{8}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{12}/) {
            parts.append(rest[..<match.range.lowerBound])
            parts.append(Substring(replacement(for: String(rest[match.range.lowerBound..<match.range.upperBound]))))
            rest = rest[match.range.upperBound...]
        }
        parts.append(rest)
        return parts.joined()
    }
            
}
