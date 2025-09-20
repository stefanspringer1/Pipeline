import Testing
import Pipeline
import Foundation
import Localization

@Suite(.serialized) struct LoggingTests {
    
    let metadata = MyMetaData(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    @Test func testExecutionPath() throws {
        
        func step1(during execution: Execution) {
            execution.effectuate("doing something in step1", checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2(during: execution)
            }
        }
        
        func step2(during execution: Execution) {
            execution.effectuate("doing something in step2", checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                execution.log(.info, "hello")
                #expect(execution.executionPath == "step step1(during:)@\(#file.firstPathPart) -> step step2(during:)@\(#file.firstPathPart)")
                execution.dispensable(named: "we might dispense with step 3") {
                    #expect(execution.executionPath == "step step1(during:)@\(#file.firstPathPart) -> step step2(during:)@\(#file.firstPathPart) -> dispensable part \"we might dispense with step 3\"")
                    step3(during: execution)
                }
            }
        }
        
        func step3(during execution: Execution) {
            execution.effectuate("doing something in step3", checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                execution.force {
                    execution.log(.info, "hello again")
                }
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger, excutionInfoFormat: ExecutionInfoFormat(addIndentation: true, addType: true, addExecutionPath: true))
        
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests (doing something in step1)
                {progress} beginning step step2(during:)@PipelineTests (doing something in step2) [@@ step step1(during:)@PipelineTests -> ]
                    {info} hello [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests]
                    {progress} beginning dispensible part "we might dispense with step 3" [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> ]
                        {progress} beginning step step3(during:)@PipelineTests (doing something in step3) [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> dispensable part "we might dispense with step 3" -> ]
                            {progress} beginning forcing steps [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> dispensable part "we might dispense with step 3" -> step step3(during:)@PipelineTests -> ]
                                {info} hello again [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> dispensable part "we might dispense with step 3" -> step step3(during:)@PipelineTests -> forcing]
                            {progress} ending forcing steps [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> dispensable part "we might dispense with step 3" -> step step3(during:)@PipelineTests -> ]
                        {progress} ending step step3(during:)@PipelineTests (doing something in step3) [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> dispensable part "we might dispense with step 3" -> ]
                    {progress} ending dispensible part "we might dispense with step 3" [@@ step step1(during:)@PipelineTests -> step step2(during:)@PipelineTests -> ]
                {progress} ending step step2(during:)@PipelineTests (doing something in step2) [@@ step step1(during:)@PipelineTests -> ]
            {progress} ending step step1(during:)@PipelineTests (doing something in step1)
            """
        )
    }
    
    @Test func testMessage1() throws {
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger)
        
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
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
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger, excutionInfoFormat: ExecutionInfoFormat(addIndentation: true))
        
        // NOTE: `language: .de` added:
        let execution = Execution(language: .de, executionInfoConsumer: myExecutionInfoConsumer)
        
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
        
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(
            withMetaDataInfo: metadata.description,
            logger: logger,
            withMinimalInfoType: .info,
            excutionInfoFormat: ExecutionInfoFormat(addType: true)
        )
        
        // NOTE: `language: .de` added:
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
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
        
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(
            withMetaDataInfo: metadata.description,
            logger: logger,
            withMinimalInfoType: .info,
            excutionInfoFormat: ExecutionInfoFormat(addType: true)
        )
        
        // NOTE: `language: .de` added:
        let execution = AsyncExecution(executionInfoConsumer: myExecutionInfoConsumer)
        
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
