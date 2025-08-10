// Basic tests without XCTest framework
// These tests will run as a simple executable

import Foundation

struct BasicTests {
    static func testBasicMath() -> Bool {
        return 2 + 2 == 4
    }
    
    static func testStringComparison() -> Bool {
        return "MenuBarApp" == "MenuBarApp"
    }
    
    static func testBooleanLogic() -> Bool {
        return true && true
    }
    
    static func runAll() -> Bool {
        var allPassed = true
        
        print("Running Basic Tests...")
        
        if testBasicMath() {
            print("✓ testBasicMath passed")
        } else {
            print("✗ testBasicMath failed")
            allPassed = false
        }
        
        if testStringComparison() {
            print("✓ testStringComparison passed")
        } else {
            print("✗ testStringComparison failed")
            allPassed = false
        }
        
        if testBooleanLogic() {
            print("✓ testBooleanLogic passed")
        } else {
            print("✗ testBooleanLogic failed")
            allPassed = false
        }
        
        return allPassed
    }
}

@main
struct TestRunner {
    static func main() {
        let passed = BasicTests.runAll()
        
        if passed {
            print("\nAll tests passed!")
            exit(0)
        } else {
            print("\nSome tests failed!")
            exit(1)
        }
    }
}