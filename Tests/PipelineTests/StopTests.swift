import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct StopTests {
    
    let metadata = MyMetaData(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    @Test func testFatalError() throws {
        
        func step1(during execution: Execution) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2a(during: execution)
                step2b(during: execution)
            }
        }
        
        func step2a(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3aa(during: execution)
                execution.log(.fatal, "cannot proceess the item any further") // !!!! fatal error is here !!!!
                step3ab(during: execution)
            }
        }
        
        func step2b(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3b(during: execution)
            }
        }
        
        func step3aa(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3ab(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3b(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger, excutionInfoFormat: ExecutionInfoFormat(addIndentation: true, addType: true))
        
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests
                {progress} beginning step step2a(during:stop:)@PipelineTests
                    {progress} beginning step step3aa(during:stop:)@PipelineTests
                    {progress} ending step step3aa(during:stop:)@PipelineTests
                    {fatal} cannot proceess the item any further
                    {progress} stopping execution: fatal error occurred
                    {progress} skipping in an stopped environment step step3ab(during:stop:)@PipelineTests
                {progress} stopped step step2a(during:stop:)@PipelineTests
                {progress} skipping in an stopped environment step step2b(during:stop:)@PipelineTests
            {progress} stopped step step1(during:)@PipelineTests
            """)
        
    }
    
    @Test func testDeadlyError() throws {
        
        func step1(during execution: Execution) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2a(during: execution)
                step2b(during: execution)
            }
        }
        
        func step2a(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3aa(during: execution)
                execution.log(.deadly, "cannot proceess anything any more") // !!!! deadly error is here !!!!
                step3ab(during: execution)
            }
        }
        
        func step2b(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3b(during: execution)
            }
        }
        
        func step3aa(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3ab(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3b(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger, excutionInfoFormat: ExecutionInfoFormat(addIndentation: true, addType: true))
        
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests
                {progress} beginning step step2a(during:stop:)@PipelineTests
                    {progress} beginning step step3aa(during:stop:)@PipelineTests
                    {progress} ending step step3aa(during:stop:)@PipelineTests
                    {deadly} cannot proceess anything any more
                    {progress} stopping execution: deadly error occurred
                    {progress} skipping in an stopped environment step step3ab(during:stop:)@PipelineTests
                {progress} stopped step step2a(during:stop:)@PipelineTests
                {progress} skipping in an stopped environment step step2b(during:stop:)@PipelineTests
            {progress} stopped step step1(during:)@PipelineTests
            """)
        
    }
    
    @Test func testStop() throws {
        
        func step1(during execution: Execution) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step2a(during: execution)
                step2b(during: execution)
            }
        }
        
        func step2a(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3aa(during: execution)
                execution.stop(reason: "cannot proceess any further") // !!!! stop is here !!!!
                step3ab(during: execution)
            }
        }
        
        func step2b(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                step3b(during: execution)
            }
        }
        
        func step3aa(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3ab(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        func step3b(during execution: Execution, stop: Bool = false) {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                // -
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger, excutionInfoFormat: ExecutionInfoFormat(addIndentation: true, addType: true))
        
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
        step1(during: execution)
        
        #expect(logger.messages.joined(separator: "\n") == """
            {progress} beginning step step1(during:)@PipelineTests
                {progress} beginning step step2a(during:stop:)@PipelineTests
                    {progress} beginning step step3aa(during:stop:)@PipelineTests
                    {progress} ending step step3aa(during:stop:)@PipelineTests
                    {progress} stopping execution: cannot proceess any further
                    {progress} skipping in an stopped environment step step3ab(during:stop:)@PipelineTests
                {progress} stopped step step2a(during:stop:)@PipelineTests
                {progress} skipping in an stopped environment step step2b(during:stop:)@PipelineTests
            {progress} stopped step step1(during:)@PipelineTests
            """)
        
    }
    
}
