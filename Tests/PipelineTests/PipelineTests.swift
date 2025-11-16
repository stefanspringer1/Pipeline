import Testing
import Pipeline

@Suite(.serialized) struct PipelineTests {
    
    @Test func pipelineTest1() throws {
        
        // the public parts of PipelineCore + StepMacro should
        // be reachable by the above Pipeline import alone:
        
        @Step
        func step1(during execution: Execution) {
            print("hello")
        }
        
    }
    
}
