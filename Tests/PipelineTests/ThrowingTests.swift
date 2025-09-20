import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct ThrowingTests {
    
    let metadata = MyMetaData(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    @Test func throwing() throws {
        
        func step1(during execution: Execution) throws {
            try execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                try step2(during: execution)
            }
        }
        
        func step2(during execution: Execution) throws {
            try execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                throw TestError("error!")
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionEventProcessor = ExecutionEventProcessorForLogger(
            withMetaDataInfo: metadata.description,
            logger: logger,
            excutionInfoFormat: ExecutionInfoFormat(
                addIndentation: true,
                addStructuralID: true
            )
        )
        
        var uuidReplacements = UUIDReplacements()
        
        do {
            try step1(during: Execution(ExecutionEventProcessor: myExecutionEventProcessor))
        } catch {
            logger.log("THROWN ERROR: \(String(describing: error))")
        }
        
        #expect(uuidReplacements.doReplacements(in: logger.messages.joined(separator: "\n")) == """
            beginning step step1(during:)@PipelineTests <#1>
                beginning step step2(during:)@PipelineTests <#2>
            THROWN ERROR: error!
            """)
        
    }
    
    @Test func throwingAndCatching() throws {
        
        func step1(during execution: Execution)  {
            execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                do {
                    try step2(during: execution)
                } catch {
                    execution.log(.error, "catched thrown error: \(String(describing: error))")
                }
            }
        }
        
        func step2(during execution: Execution) throws {
            try execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                try step3(during: execution)
            }
        }
        
        func step3(during execution: Execution) throws {
            try execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
                throw TestError("error!")
            }
        }
        
        let logger = CollectingLogger()
        let myExecutionEventProcessor = ExecutionEventProcessorForLogger(
            withMetaDataInfo: metadata.description,
            logger: logger,
            excutionInfoFormat: ExecutionInfoFormat(
                addIndentation: true,
                addStructuralID: true
            )
        )
        
        var uuidReplacements = UUIDReplacements()
        
        step1(during: Execution(ExecutionEventProcessor: myExecutionEventProcessor))
        
        #expect(uuidReplacements.doReplacements(in: logger.messages.joined(separator: "\n")) == """
            beginning step step1(during:)@PipelineTests <#1>
                beginning step step2(during:)@PipelineTests <#2>
                    beginning step step3(during:)@PipelineTests <#3>
                catched thrown error: error! <>
            ending step step1(during:)@PipelineTests <#1>
            """)
        
    }
    
}
