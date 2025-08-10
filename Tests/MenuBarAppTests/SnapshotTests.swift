import XCTest
import SwiftUI
import AppKit
import SnapshotTesting
@testable import MenuBarApp

final class MenuBarAppSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Use a consistent device for snapshot testing
        // isRecording is deprecated - record mode should be set via environment variable
    }
    
    override class func setUp() {
        super.setUp()
        // Record new snapshots if needed - comment out after recording
        // SnapshotTesting.isRecording = true
    }
    
    @MainActor
    func testMenuBarExtraViewWithAPIKey() {
        // Mock the app settings to have an API key
        let mockSettings = AppSettings.shared
        mockSettings.hasAPIKeyForTesting = true
        
        let viewModel = PullRequestViewModel()
        let view = MenuBarExtraView(viewModel: viewModel)
            .environmentObject(mockSettings)
            .frame(width: 300, height: 200)
        
        // Use NSView-based snapshot testing instead of AnyView
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        
        assertSnapshot(of: hostingView, as: .image)
    }
    
    @MainActor
    func testMenuBarExtraViewWithoutAPIKey() {
        // Mock the app settings to not have an API key
        let mockSettings = AppSettings.shared
        mockSettings.hasAPIKeyForTesting = false
        
        let viewModel = PullRequestViewModel()
        let view = MenuBarExtraView(viewModel: viewModel)
            .environmentObject(mockSettings)
            .frame(width: 300, height: 200)
        
        // Use NSView-based snapshot testing instead of AnyView
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        
        assertSnapshot(of: hostingView, as: .image)
    }
    
    func testSettingsViewEmpty() {
        let view = SettingsView()
            .frame(width: 700, height: 500)
        
        // Use NSView-based snapshot testing instead of AnyView
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 500)
        
        assertSnapshot(of: hostingView, as: .image)
    }
    
    func testTokenValidationResultViewLoading() {
        let mockGitHubService = GitHubAPIService.shared
        mockGitHubService.setValidationStateForTesting(isValidating: true, result: nil)
        
        let view = TokenValidationResultView()
            .environmentObject(mockGitHubService)
            .frame(width: 300, height: 100)
        
        // Use NSView-based snapshot testing instead of AnyView
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
        
        assertSnapshot(of: hostingView, as: .image)
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
            .frame(width: 400, height: 300)
        
        // Use NSView-based snapshot testing instead of AnyView
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        
        assertSnapshot(of: hostingView, as: .image)
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
            .frame(width: 300, height: 150)
        
        // Use NSView-based snapshot testing instead of AnyView
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 150)
        
        assertSnapshot(of: hostingView, as: .image)
    }
}