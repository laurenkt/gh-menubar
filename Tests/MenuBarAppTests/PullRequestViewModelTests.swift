import XCTest
@testable import MenuBarApp

@MainActor
final class PullRequestViewModelTests: XCTestCase {
    var viewModel: PullRequestViewModel!
    var mockDependencies: MockDependencyContainer!
    var mockGitHubService: MockGitHubService!
    var mockSettingsService: MockSettingsService!
    var mockKeychainService: MockKeychainService!
    
    override func setUp() {
        super.setUp()
        
        mockGitHubService = MockGitHubService()
        mockSettingsService = MockSettingsService()
        mockKeychainService = MockKeychainService()
        
        mockDependencies = MockDependencyContainer(
            gitHubService: mockGitHubService,
            settingsService: mockSettingsService,
            keychainService: mockKeychainService
        )
        
        viewModel = PullRequestViewModel(dependencies: mockDependencies)
    }
    
    override func tearDown() {
        viewModel = nil
        mockDependencies = nil
        mockGitHubService = nil
        mockSettingsService = nil
        mockKeychainService = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(viewModel.pullRequests.isEmpty)
        XCTAssertTrue(viewModel.queryResults.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.currentUserLogin)
        XCTAssertNil(viewModel.lastRefreshTime)
    }
    
    func testFetchPullRequestsWithoutAPIKey() async {
        // Given: No API key stored
        mockKeychainService.deleteAPIKey()
        
        // When: Trying to fetch pull requests
        await viewModel.fetchPullRequests()
        
        // Then: Should set error message
        XCTAssertEqual(viewModel.errorMessage, "No API key configured")
        XCTAssertTrue(viewModel.pullRequests.isEmpty)
        XCTAssertNil(viewModel.currentUserLogin)
    }
    
    func testFetchPullRequestsWithAPIKey() async {
        // Given: API key is stored
        mockKeychainService.saveAPIKey("test-token")
        
        let testUser = GitHubUser(login: "testuser", id: 123)
        mockGitHubService.mockUser = testUser
        
        let testPR = createMockPullRequest(id: 1, number: 1, title: "Test PR")
        mockGitHubService.mockPullRequests = [testPR]
        
        let testQuery = QueryConfiguration(title: "Test Query", query: "is:open")
        mockSettingsService.queries = [testQuery]
        
        // When: Fetching pull requests
        await viewModel.fetchPullRequests()
        
        // Then: Should fetch successfully
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.currentUserLogin, "testuser")
        XCTAssertEqual(viewModel.queryResults.count, 1)
        XCTAssertEqual(viewModel.queryResults.first?.pullRequests.count, 1)
        XCTAssertEqual(viewModel.queryResults.first?.pullRequests.first?.title, "Test PR")
        XCTAssertNotNil(viewModel.lastRefreshTime)
    }
    
    func testPendingActionsCountWithReviewNeeded() {
        // Given: User login is set
        viewModel.setCurrentUserLogin("testuser")
        
        let testQuery = QueryConfiguration(
            title: "Test Query",
            query: "is:open",
            includeInPendingReviewsCount: true
        )
        
        // Create PR that needs review (has requested reviewers)
        var prNeedsReview = createMockPullRequest(id: 1, number: 1, title: "Needs Review")
        prNeedsReview.requestedReviewers = [GitHubUser(login: "reviewer", id: 789)]
        
        let prNoReview = createMockPullRequest(id: 2, number: 2, title: "No Review")
        
        let queryResult = QueryResult(query: testQuery, pullRequests: [prNeedsReview, prNoReview])
        viewModel.setCurrentUserLogin("testuser")
        viewModel.setState(.loaded([queryResult]))
        
        // When: Calculating pending actions count
        let count = viewModel.pendingActionsCount
        
        // Then: Should count only PRs that need review
        XCTAssertEqual(count, 1)
    }
    
    func testPendingActionsCountWithFailingChecks() {
        // Given: User login is set
        viewModel.setCurrentUserLogin("testuser")
        
        let testQuery = QueryConfiguration(
            title: "Test Query",
            query: "is:open",
            includeInFailingChecksCount: true
        )
        
        // Create PR with failing checks (add failed check run)
        var prWithFailingChecks = createMockPullRequest(id: 1, number: 1, title: "Failing Checks", userLogin: "testuser")
        let failedCheckRun = createMockCheckRun(name: "Test", status: "completed", conclusion: "failure")
        prWithFailingChecks.checkRuns = [failedCheckRun]
        
        var prWithPassingChecks = createMockPullRequest(id: 2, number: 2, title: "Passing Checks", userLogin: "testuser")
        let successCheckRun = createMockCheckRun(name: "Test", status: "completed", conclusion: "success")
        prWithPassingChecks.checkRuns = [successCheckRun]
        
        let queryResult = QueryResult(query: testQuery, pullRequests: [prWithFailingChecks, prWithPassingChecks])
        viewModel.setCurrentUserLogin("testuser")
        viewModel.setState(.loaded([queryResult]))
        
        // When: Calculating pending actions count
        let count = viewModel.pendingActionsCount
        
        // Then: Should count only PRs with failing checks authored by user
        XCTAssertEqual(count, 1)
    }
    
    func testRefreshCallsFetchPullRequests() async {
        // Given: API key is stored
        mockKeychainService.saveAPIKey("test-token")
        mockGitHubService.mockUser = GitHubUser(login: "testuser", id: 123)
        mockSettingsService.queries = [QueryConfiguration(title: "Test", query: "is:open")]
        
        // When: Calling refresh
        viewModel.refresh()
        
        // Give the async operation a moment to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Should have attempted to fetch
        XCTAssertNotNil(viewModel.lastRefreshTime)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPullRequest(id: Int, number: Int, title: String, userLogin: String = "author") -> GitHubPullRequest {
        return GitHubPullRequest(
            id: id,
            number: number,
            title: title,
            htmlUrl: "https://github.com/test/repo/pull/\(number)",
            state: "open",
            draft: false,
            createdAt: Date(),
            updatedAt: Date(),
            user: GitHubUser(login: userLogin, id: 456),
            pullRequest: nil,
            repositoryUrl: "https://api.github.com/repos/test/repo",
            headSha: "abc123",
            mergeable: nil,
            mergeableState: nil,
            checkRuns: [],
            commitStatuses: [],
            requestedReviewers: nil,
            assignees: nil
        )
    }
    
    private func createMockCheckRun(name: String, status: String, conclusion: String?) -> GitHubCheckRun {
        return GitHubCheckRun(
            id: Int.random(in: 1...1000),
            headSha: "abc123",
            status: status,
            conclusion: conclusion,
            name: name,
            startedAt: Date(),
            completedAt: Date(),
            output: CheckRunOutput(title: "Test", summary: "Test summary", annotationsCount: 0),
            htmlUrl: "https://github.com/test/repo/runs/123",
            detailsUrl: nil,
            app: CheckRunApp(id: 1, slug: "test-app", name: "Test App"),
            jobs: []
        )
    }
}