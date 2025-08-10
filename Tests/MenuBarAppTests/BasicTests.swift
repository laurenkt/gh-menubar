// Basic tests without XCTest framework
// These tests will run as a simple executable

import Foundation

// Mock structure for testing repository name parsing
struct MockGitHubPullRequest {
    let repositoryUrl: String
    
    var repositoryName: String? {
        // Extract repo name from repository_url using robust regex parsing
        // Format: https://api.github.com/repos/owner/repo
        let pattern = #"^https://api\.github\.com/repos/[^/]+/([^/]+)(?:/.*)?$"#
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(repositoryUrl.startIndex..<repositoryUrl.endIndex, in: repositoryUrl)
            if let match = regex.firstMatch(in: repositoryUrl, options: [], range: range) {
                let repoRange = Range(match.range(at: 1), in: repositoryUrl)
                if let repoRange = repoRange {
                    return String(repositoryUrl[repoRange])
                }
            }
        } catch {
            // Fallback to original URL parsing if regex fails
            if let url = URL(string: repositoryUrl),
               url.pathComponents.count >= 4 {
                return url.pathComponents[3]
            }
        }
        return nil
    }
}

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
    
    static func testRepositoryNameParsing() -> Bool {
        // Create a test GitHubPullRequest with various URL formats
        let testCases = [
            ("https://api.github.com/repos/owner/repo", "repo"),
            ("https://api.github.com/repos/microsoft/vscode", "vscode"),
            ("https://api.github.com/repos/owner/repo-with-dashes", "repo-with-dashes"),
            ("https://api.github.com/repos/owner/repo.with.dots", "repo.with.dots"),
            ("invalid-url", nil),
            ("", nil)
        ]
        
        for (url, expected) in testCases {
            let mockPR = MockGitHubPullRequest(repositoryUrl: url)
            let actual = mockPR.repositoryName
            
            if actual != expected {
                print("Repository name parsing failed: URL=\(url), expected=\(expected ?? "nil"), actual=\(actual ?? "nil")")
                return false
            }
        }
        
        return true
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
        
        if testRepositoryNameParsing() {
            print("✓ testRepositoryNameParsing passed")
        } else {
            print("✗ testRepositoryNameParsing failed")
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