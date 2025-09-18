import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct MessageTest {
    
    let metadata = MyMetaData(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    @Test func testMessage1() throws {
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData>(logger: logger, excutionInfoFormat: .bareIndented)
        
        let execution = Execution<MyMetaData>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        let message = Message(
            id: "values not OK",
            type: .info,
            fact: [
                Language.en: #""$0" and "$2" are not OK"#,
                Language.de: #""$0" und "$2" sind nicht OK"#,
            ]
        )
        
        execution.log(message, "A", "B")
        
        #expect(logger.messages.joined(separator: "\n") == #"{info} [values not OK]: "A" and "$2" are not OK"#)
        
    }
    
    @Test func testMessage2() throws {
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData>(logger: logger, excutionInfoFormat: .bareIndented)
        
        let execution = Execution<MyMetaData>(language: .de, metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        let message = Message(
            id: "values not OK",
            type: .info,
            fact: [
                Language.en: #""$0" and "$2" are not OK"#,
                Language.de: #""$0" und "$2" sind nicht OK"#,
            ],
            solution: [
                Language.en: #"change "$0" and "$1""#,
                Language.de: #"ändere "$0" und "$1""#,
            ]
        )
        
        execution.log(message, "A", "B")
        
        #expect(logger.messages.joined(separator: "\n") == #"{info} [values not OK]: "A" und "$2" sind nicht OK → ändere "A" und "B""#)
        
    }
    
}
