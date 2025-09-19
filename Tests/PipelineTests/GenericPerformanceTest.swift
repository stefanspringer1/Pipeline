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
        
        let allIterations = 1_000_000 // must be at least 1_000 and divisible by innerIterations
        let innerIterations = 1_000   // must be at least 100
        
        #expect(allIterations >= 1_000)
        #expect(innerIterations >= 100)
        #expect(innerIterations < allIterations)
        #expect(allIterations % innerIterations == 0)
        
        var timeNongeneric: Double = 0
        var timeGeneric: Double = 0
        
        var counter = 0
        
        let nongenericExecution = NongenericExecution(metadata: metadata)
        let genericExecution = GenericExecution(metadata: metadata)
        
        func testNongeneric() {
            
            func step1Nongeneric(during execution: NongenericExecution) {
                counter += 1 // do something
                step2Nongeneric(during: execution)
            }
            
            func step2Nongeneric(during execution: NongenericExecution) {
                counter += 1 // do something
                step3Nongeneric(during: execution)
            }
            
            func step3Nongeneric(during execution: NongenericExecution) {
                counter += 1 // do something
            }
            
            timeNongeneric += elapsedTime {
                for _ in 1...innerIterations {
                    step1Nongeneric(during: nongenericExecution)
                }
            }
            
        }
        
        func testGeneric() {
            
            func step1Generic<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step2Generic(during: execution)
            }
            
            func step2Generic<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step3Generic(during: execution)
            }
            
            func step3Generic<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
            }
            
            timeGeneric += elapsedTime {
                for _ in 1...innerIterations {
                    step1Generic(during: genericExecution)
                }
            }
            
        }
        
        for _ in 1...(allIterations/innerIterations) {
            testNongeneric()
            testGeneric()
        }
        
        #expect(counter == 2 * 3 * allIterations)
        
        print("time non-generic: \(timeNongeneric)")
        print("time generic: \(timeGeneric)")
        
        let deviationPercent = (timeGeneric - timeNongeneric) * 100 / timeNongeneric
        print("deviation: \(String(format: "%.1f", deviationPercent)) %")
        
        #expect(abs(deviationPercent) < 10) // actual deviations should be < 1 %, but we do not want a test to fail
        
    }
    
}
