import Testing
import Foundation

@Suite(.serialized) struct UUIDTests {
    
    @Test func testUUIDPerformance() {
        let clock = ContinuousClock()
        
        let duration = clock.measure {
            for _ in 1...1_000_000 {
                let _ = UUID()
            }
        }
        
        print("duration: \(duration)")
        #expect(duration < .seconds(1))
    }
    
}
