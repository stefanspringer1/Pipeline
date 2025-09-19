import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct AbortionTests {
    
    let metadata = MyMetaData1(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    @Test func testFatalError() throws {
        
        func step1<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2a(during: execution)
                step2b(during: execution)
            }
        }
        
        func step2a<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3aa(during: execution)
                execution.log(.fatal, "cannot proceess the item any further") // !!!! fatal error is here !!!!
                step3ab(during: execution)
            }
        }
        
        func step2b<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3b(during: execution)
            }
        }
        
        func step3aa<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3ab<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3b<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData1>(logger: logger, excutionInfoFormat: ExecutionInfoFormat(withIndentation: true, withType: true))
        
        let execution = Execution<MyMetaData1>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests
                {progress} beginning step step2a(during:abort:)@PipelineTests
                    {progress} beginning step step3aa(during:abort:)@PipelineTests
                    {progress} ending step step3aa(during:abort:)@PipelineTests
                    {fatal} cannot proceess the item any further
                    {progress} skipping in an aborted environment step step3ab(during:abort:)@PipelineTests
                {progress} ending step step2a(during:abort:)@PipelineTests
                {progress} skipping in an aborted environment step step2b(during:abort:)@PipelineTests
            {progress} ending step step1(during:)@PipelineTests
            """)
        
    }
    
    @Test func testDeadlyError() throws {
        
        func step1<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2a(during: execution)
                step2b(during: execution)
            }
        }
        
        func step2a<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3aa(during: execution)
                execution.log(.deadly, "cannot proceess anything any more") // !!!! deadly error is here !!!!
                step3ab(during: execution)
            }
        }
        
        func step2b<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3b(during: execution)
            }
        }
        
        func step3aa<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3ab<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3b<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData1>(logger: logger, excutionInfoFormat: ExecutionInfoFormat(withIndentation: true, withType: true))
        
        let execution = Execution<MyMetaData1>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests
                {progress} beginning step step2a(during:abort:)@PipelineTests
                    {progress} beginning step step3aa(during:abort:)@PipelineTests
                    {progress} ending step step3aa(during:abort:)@PipelineTests
                    {deadly} cannot proceess anything any more
                    {progress} skipping in an aborted environment step step3ab(during:abort:)@PipelineTests
                {progress} ending step step2a(during:abort:)@PipelineTests
                {progress} skipping in an aborted environment step step2b(during:abort:)@PipelineTests
            {progress} ending step step1(during:)@PipelineTests
            """)
        
    }
    
    @Test func testAbortion() throws {
        
        func step1<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2a(during: execution)
                step2b(during: execution)
            }
        }
        
        func step2a<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3aa(during: execution)
                execution.abort(reason: "cannot proceess any further") // !!!! abortion is here !!!!
                step3ab(during: execution)
            }
        }
        
        func step2b<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3b(during: execution)
            }
        }
        
        func step3aa<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3ab<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3b<MetaData: ExecutionMetaData>(during execution: Execution<MetaData>, abort: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger<MyMetaData1>(logger: logger, excutionInfoFormat: ExecutionInfoFormat(withIndentation: true, withType: true))
        
        let execution = Execution<MyMetaData1>(metadata: metadata, executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests
                {progress} beginning step step2a(during:abort:)@PipelineTests
                    {progress} beginning step step3aa(during:abort:)@PipelineTests
                    {progress} ending step step3aa(during:abort:)@PipelineTests
                    {progress} aborting execution: cannot proceess any further
                    {progress} skipping in an aborted environment step step3ab(during:abort:)@PipelineTests
                {progress} aborted step step2a(during:abort:)@PipelineTests
                {progress} skipping in an aborted environment step step2b(during:abort:)@PipelineTests
            {progress} aborted step step1(during:)@PipelineTests
            """)
        
    }
    
}
