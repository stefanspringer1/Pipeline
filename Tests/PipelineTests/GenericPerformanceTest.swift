import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct GenericPerformanceTest {
    
    let metadata = MyMetaData(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    func elapsedTime(of f: () -> Void) -> Double {
        let startTime = DispatchTime.now()
        f()
        let endTime = DispatchTime.now()
        let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        return Double(elapsedTime) / 1_000_000_000
    }
    
    final class GenericExecution<MetaData: ExecutionMetaData> {
        
        let metadata: MetaData
        
        init(metadata: MetaData) {
            self.metadata = metadata
        }
    }
    
    final class NongenericExecution{
        
        let metadata: MyMetaData
        
        init(metadata: MyMetaData) {
            self.metadata = metadata
        }
    }
    
    @Test func testExecution() throws {
        
        let iterations = 10_000_000
        
        do {
            
            var counter = 0
            
            func step1_nongeneric(during execution: NongenericExecution) {
                counter += 1 // do something
                step2_nongeneric(during: execution)
            }
            
            func step2_nongeneric(during execution: NongenericExecution) {
                counter += 1 // do something
                step3_nongeneric(during: execution)
            }
            
            func step3_nongeneric(during execution: NongenericExecution) {
                counter += 1 // do something
            }
            
            let nongenericExecution = NongenericExecution(metadata: metadata)
            
            let time_nongeneric = elapsedTime {
                for _ in 1...iterations {
                    step1_nongeneric(during: nongenericExecution)
                }
            }
            
            #expect(counter == 3 * iterations)
            
            print("time non-generic: \(time_nongeneric)")
            
        }
        
        do {
            
            var counter = 0
            
            func step1_generic<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step2_generic(during: execution)
            }
            
            func step2_generic<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step3_generic(during: execution)
            }
            
            func step3_generic<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
            }
            
            let genericExecution = GenericExecution(metadata: metadata)
            
            let time_generic = elapsedTime {
                for _ in 1...iterations {
                    step1_generic(during: genericExecution)
                }
            }
            
            #expect(counter == 3 * iterations)
            
            print("time generic: \(time_generic)")
            
        }
        
    }
    
}
