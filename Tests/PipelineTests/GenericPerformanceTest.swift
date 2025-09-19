import Testing
import Pipeline
import Foundation

@Suite(.serialized) struct GenericPerformanceTest {
    
    let metadata1 = MyMetaData1(
        applicationName: "myapp",
        processID: "precess123",
        workItemInfo: "item123"
    )
    
    let metadata2 = MyMetaData2(
        server: "00.00.00.00",
        processID: "precess123",
        path: "/"
    )
    
    func elapsedTime(of f: () -> Void) -> Double {
        let startTime = DispatchTime.now()
        f()
        let endTime = DispatchTime.now()
        let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        return Double(elapsedTime) / 1_000_000_000
    }
    
    final class NongenericExecution{
        
        let metadata: MyMetaData1
        
        init(metadata: MyMetaData1) {
            self.metadata = metadata
        }
    }
    
    final class GenericExecution<MetaData: ExecutionMetaData> {
        
        let metadata: MetaData
        
        init(metadata: MetaData) {
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
        var timeGeneric1: Double = 0
        var timeGeneric2: Double = 0
        
        var counter = 0
        
        let nongenericExecution = NongenericExecution(metadata: metadata1)
        let genericExecution1 = GenericExecution(metadata: metadata1)
        // test if time is also OK when a GenericExecution also gets another metadata type:
        let genericExecution2 = GenericExecution(metadata: metadata2)
        
        func testNongeneric() {
            
            @inline(never)
            func step1(during execution: NongenericExecution) {
                counter += 1 // do something
                step2(during: execution)
            }
            
            @inline(never)
            func step2(during execution: NongenericExecution) {
                counter += 1 // do something
                step3(during: execution)
            }
            
            @inline(never)
            func step3(during execution: NongenericExecution) {
                counter += 1 // do something
            }
            
            timeNongeneric += elapsedTime {
                for _ in 1...innerIterations {
                    step1(during: nongenericExecution)
                }
            }
            
        }
        
        func testGeneric1() {
            
            @inline(never)
            func step1<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step2(during: execution)
            }
            
            @inline(never)
            func step2<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step3(during: execution)
            }
            
            @inline(never)
            func step3<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
            }
            
            timeGeneric1 += elapsedTime {
                for _ in 1...innerIterations {
                    step1(during: genericExecution1) // using the first metadata!
                }
            }
            
        }
        
        func testGeneric2() {
            
            @inline(never)
            func step1<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step2(during: execution)
            }
            
            @inline(never)
            func step2<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
                step3(during: execution)
            }
            
            @inline(never)
            func step3<MetaData: ExecutionMetaData>(during execution: GenericExecution<MetaData>) {
                counter += 1 // do something
            }
            
            timeGeneric2 += elapsedTime {
                for _ in 1...innerIterations {
                    step1(during: genericExecution2) // using the other metadata!
                }
            }
            
        }
        
        for _ in 1...(allIterations/innerIterations) {
            testNongeneric()
            testGeneric1()
            testGeneric2()
        }
        
        #expect(counter == 3 * 3 * allIterations)
        
        print("time non-generic: \(timeNongeneric)")
        print("time generic #1:  \(timeGeneric1)")
        print("time generic #2:  \(timeGeneric2)")
        
        let deviationPercent1 = (timeGeneric1 - timeNongeneric) * 100 / timeNongeneric
        let deviationPercent2 = (timeGeneric2 - timeNongeneric) * 100 / timeNongeneric
        
        print("deviation #1: \(String(format: "%.1f", deviationPercent1)) %")
        
        print("deviation #2: \(String(format: "%.1f", deviationPercent2)) %")
        
        // actual deviations should be < 1 %, but we do not want a test to fail
        #expect(abs(deviationPercent1) < 10)
        #expect(abs(deviationPercent2) < 10)
        
    }
    
}
