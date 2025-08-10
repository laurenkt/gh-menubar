import XCTest
import SwiftUI
import SnapshotTesting
@testable import MenuBarApp

final class MenuBarAppSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Use a consistent device for snapshot testing
        // isRecording is deprecated - record mode should be set via environment variable
    }
    
    func testMenuBarExtraViewWithAPIKey() {
        // Mock the app settings to have an API key
        let mockSettings = AppSettings.shared
        mockSettings.hasAPIKeyForTesting = true
        
        let view = MenuBarExtraView()
            .environmentObject(mockSettings)
        
        assertSnapshot(matching: view, as: .image(size: CGSize(width: 300, height: 200)))
    }
    
    func testMenuBarExtraViewWithoutAPIKey() {
        // Mock the app settings to not have an API key
        let mockSettings = AppSettings.shared
        mockSettings.hasAPIKeyForTesting = false
        
        let view = MenuBarExtraView()
            .environmentObject(mockSettings)
        
        assertSnapshot(matching: view, as: .image(size: CGSize(width: 300, height: 200)))
    }
    
    func testSettingsViewEmpty() {
        let view = SettingsView()
        
        assertSnapshot(matching: view, as: .image(size: CGSize(width: 300, height: 200)))
    }
    
    func testTokenValidationResultViewLoading() {
        let mockGitHubService = GitHubAPIService.shared
        mockGitHubService.setValidationStateForTesting(isValidating: true, result: nil)
        
        let view = TokenValidationResultView()
            .environmentObject(mockGitHubService)
        
        assertSnapshot(matching: view, as: .image(size: CGSize(width: 300, height: 200)))
    }
    
    func testTokenValidationResultViewValid() {
        let mockResult = GitHubValidationResult(
            isValid: true,
            user: GitHubUser(login: "testuser", id: 123),
            error: nil
        )
        
        let mockGitHubService = GitHubAPIService.shared
        mockGitHubService.setValidationStateForTesting(isValidating: false, result: mockResult)
        
        let view = TokenValidationResultView()
            .environmentObject(mockGitHubService)
        
        assertSnapshot(matching: view, as: .image(size: CGSize(width: 300, height: 200)))
    }
    
    func testTokenValidationResultViewInvalid() {
        let mockResult = GitHubValidationResult(
            isValid: false,
            user: nil,
            error: "Invalid token"
        )
        
        let mockGitHubService = GitHubAPIService.shared
        mockGitHubService.setValidationStateForTesting(isValidating: false, result: mockResult)
        
        let view = TokenValidationResultView()
            .environmentObject(mockGitHubService)
        
        assertSnapshot(matching: view, as: .image(size: CGSize(width: 300, height: 200)))
    }
}