import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct LoggingTests {
    
    let metadata = MyMetaData(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    @Test func testMessage1() throws {
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData>(logger: logger)
        
        let execution = Execution<MyMetaData>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        let message = Message(
            id: "values not OK",
            type: .info,
            fact: [
                Language.en: #""$0" and "$1" are not OK"#,
                Language.de: #""$0" und "$1" sind nicht OK"#,
            ]
        )
        
        execution.log(message, "A", "B")
        
        // e.g. `2025-09-18 09:09:55 +0000: myapp: precess123/item123: {info} [values not OK]: "A" and "B" are not OK`:
        #expect(logger.messages.joined(separator: "\n").contains(#/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \+\d{4}: myapp: precess123\/item123: {info} \[values not OK\]: "A" and "B" are not OK$/#))
    }
    
    @Test func testMessage2() throws {
        
        let logger = CollectingLogger()
        
        // NOTE: `excutionInfoFormat: .bareIndented` added:
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData>(logger: logger, excutionInfoFormat: .bareIndented)
        
        // NOTE: `language: .de` added:
        let execution = Execution<MyMetaData>(language: .de, metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        let message = Message(
            id: "values not OK",
            type: .info,
            fact: [
                Language.en: #""$0" and "$1" are not OK"#,
                Language.de: #""$0" und "$1" sind nicht OK"#,
            ],
            solution: [
                Language.en: #"change "$0" and "$1""#,
                Language.de: #"ändere "$0" und "$1""#,
            ]
        )
        
        execution.log(message, "A", "B")
        
        #expect(logger.messages.joined(separator: "\n") == #"[values not OK]: "A" und "B" sind nicht OK → ändere "A" und "B""#)
        
    }
    
    @Test func testAppeasement() throws {
        
        let logger = CollectingLogger()
        
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData>(logger: logger, excutionInfoFormat: .bareWithInfoType)
        
        // NOTE: `language: .de` added:
        let execution = Execution<MyMetaData>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        execution.appease(to: .warning) {
            execution.log(.error, "this was an error")
            execution.appease(to: .info) {
                execution.log(.warning, "this was a warning")
            }
        }
        
        // default is the appeasement to `error`:
        execution.appease {
            execution.log(.fatal, "this was a fatal error")
        }
        
        execution.log(.fatal, "this is still a fatal error")
        
        #expect(logger.messages.joined(separator: "\n") == """
            {warning} this was an error
            {info} this was a warning
            {error} this was a fatal error
            {fatal} this is still a fatal error
            """)
    }
    
    @Test func testAppeasementAsync() async throws {
        
        let logger = CollectingLogger()
        
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData>(logger: logger, excutionInfoFormat: .bareWithInfoType)
        
        // NOTE: `language: .de` added:
        let execution = AsyncExecution<MyMetaData>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        await execution.appease(to: .warning) {
            await execution.log(.error, "this was an error")
            await execution.appease(to: .info) {
                await execution.log(.warning, "this was a warning")
            }
        }
        
        // default is the appeasement to `error`:
        await execution.appease {
            await execution.log(.fatal, "this was a fatal error")
        }
        
        await execution.log(.fatal, "this is still a fatal error")
        
        #expect(logger.messages.joined(separator: "\n") == """
            {warning} this was an error
            {info} this was a warning
            {error} this was a fatal error
            {fatal} this is still a fatal error
            """)
    }
    
}
