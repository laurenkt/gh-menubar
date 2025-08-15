import Foundation

protocol DependencyContainer {
    var gitHubService: any GitHubServiceProtocol { get }
    var settingsService: any SettingsServiceProtocol { get }
    var keychainService: any KeychainServiceProtocol { get }
}

class DefaultDependencyContainer: DependencyContainer {
    lazy var gitHubService: any GitHubServiceProtocol = GitHubAPIService.shared
    lazy var settingsService: any SettingsServiceProtocol = AppSettings.shared
    lazy var keychainService: any KeychainServiceProtocol = KeychainManager.shared
}

class MockDependencyContainer: DependencyContainer {
    let gitHubService: any GitHubServiceProtocol
    let settingsService: any SettingsServiceProtocol
    let keychainService: any KeychainServiceProtocol
    
    init(
        gitHubService: any GitHubServiceProtocol = MockGitHubService(),
        settingsService: any SettingsServiceProtocol = MockSettingsService(),
        keychainService: any KeychainServiceProtocol = MockKeychainService()
    ) {
        self.gitHubService = gitHubService
        self.settingsService = settingsService
        self.keychainService = keychainService
    }
}

// MARK: - Mock Services for Testing

class MockGitHubService: ObservableObject, GitHubServiceProtocol {
    @Published var isValidating: Bool = false
    @Published var validationResult: GitHubValidationResult? = nil
    
    var mockUser: GitHubUser?
    var mockPullRequests: [GitHubPullRequest] = []
    
    func validateToken(_ token: String) async -> GitHubValidationResult {
        return GitHubValidationResult(
            isValid: true,
            user: mockUser ?? GitHubUser(login: "testuser", id: 123),
            error: nil,
            repositories: [],
            organizations: [],
            hasMoreRepositories: false,
            totalRepositoryCount: 0
        )
    }
    
    func fetchUser(token: String) async throws -> GitHubUser {
        if let user = mockUser {
            return user
        }
        return GitHubUser(login: "testuser", id: 123)
    }
    
    func searchPullRequests(query: String, token: String) async throws -> [GitHubPullRequest] {
        return mockPullRequests
    }
    
    func fetchPullRequestDetails(owner: String, repo: String, number: Int, token: String) async throws -> GitHubPullRequestDetails {
        return GitHubPullRequestDetails(
            head: GitHubPullRequestDetails.PRHead(sha: "abc123"),
            mergeable: true,
            mergeableState: "clean",
            requestedReviewers: [],
            assignees: []
        )
    }
    
    func fetchRepositories(token: String) async throws -> [GitHubRepository] {
        return []
    }
    
    func fetchOrganizations(token: String) async throws -> [GitHubOrganization] {
        return []
    }
    
    func setValidationStateForTesting(isValidating: Bool, result: GitHubValidationResult?) {
        self.isValidating = isValidating
        self.validationResult = result
    }
}

class MockSettingsService: ObservableObject, SettingsServiceProtocol {
    @Published var hasAPIKey: Bool = false
    @Published var queries: [QueryConfiguration] = []
    @Published var refreshInterval: Double = 300
    @Published var useGraphQL: Bool = true
    @Published var appUpdateInterval: Double = 1.0
    @Published var hasAPIKeyForTesting: Bool = false
    
    func openSettings() {}
    func saveQueries() {}
    func resetToDefaults() {
        refreshInterval = 300
        useGraphQL = true
        appUpdateInterval = 1.0
        queries = []
    }
}

class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: Data] = [:]
    
    func save(key: String, data: Data) -> Bool {
        storage[key] = data
        return true
    }
    
    func load(key: String) -> Data? {
        return storage[key]
    }
    
    func delete(key: String) -> Bool {
        storage.removeValue(forKey: key)
        return true
    }
    
    func saveAPIKey(_ apiKey: String) -> Bool {
        return save(key: "apiKey", data: apiKey.data(using: .utf8) ?? Data())
    }
    
    func loadAPIKey() -> String? {
        guard let data = load(key: "apiKey") else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAPIKey() -> Bool {
        return delete(key: "apiKey")
    }
}