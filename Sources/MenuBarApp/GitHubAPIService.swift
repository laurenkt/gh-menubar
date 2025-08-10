import Foundation

struct GitHubRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let `private`: Bool
    let owner: GitHubOwner
    
    enum CodingKeys: String, CodingKey {
        case id, name, `private`, owner
        case fullName = "full_name"
    }
}

struct GitHubOwner: Codable {
    let login: String
    let type: String
}

struct GitHubUser: Codable {
    let login: String
    let id: Int
    let type: String
    
    init(login: String, id: Int, type: String = "User") {
        self.login = login
        self.id = id
        self.type = type
    }
}

struct GitHubOrganization: Codable, Identifiable {
    let id: Int
    let login: String
    let description: String?
}

struct GitHubPullRequest: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let state: String
    let draft: Bool
    let createdAt: Date
    let updatedAt: Date
    let user: GitHubUser
    let pullRequest: PullRequestInfo?
    let repositoryUrl: String
    let headSha: String?
    var checkRuns: [GitHubCheckRun] = []
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, state, draft, user
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pullRequest = "pull_request"
        case repositoryUrl = "repository_url"
        case headSha = "head_sha"
    }
    
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
    
    var repositoryOwner: String? {
        // Extract owner from repository_url using robust regex parsing
        // Format: https://api.github.com/repos/owner/repo
        let pattern = #"^https://api\.github\.com/repos/([^/]+)/[^/]+(?:/.*)?$"#
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(repositoryUrl.startIndex..<repositoryUrl.endIndex, in: repositoryUrl)
            if let match = regex.firstMatch(in: repositoryUrl, options: [], range: range) {
                let ownerRange = Range(match.range(at: 1), in: repositoryUrl)
                if let ownerRange = ownerRange {
                    return String(repositoryUrl[ownerRange])
                }
            }
        } catch {
            // Fallback to original URL parsing if regex fails
            if let url = URL(string: repositoryUrl),
               url.pathComponents.count >= 3 {
                return url.pathComponents[2]
            }
        }
        return nil
    }
    
    var hasFailingChecks: Bool {
        checkRuns.contains { $0.isFailed }
    }
    
    var hasInProgressChecks: Bool {
        checkRuns.contains { $0.isInProgress }
    }
    
    var allChecksSuccessful: Bool {
        !checkRuns.isEmpty && checkRuns.allSatisfy { $0.isSuccessful }
    }
    
    var checkStatus: CheckStatus {
        if checkRuns.isEmpty {
            return .unknown
        }
        if hasFailingChecks {
            return .failed
        }
        if hasInProgressChecks {
            return .inProgress
        }
        if allChecksSuccessful {
            return .success
        }
        return .unknown
    }
}

enum CheckStatus: String, CaseIterable {
    case success = "success"
    case failed = "failed"
    case inProgress = "in_progress"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .success:
            return "Passing"
        case .failed:
            return "Failed"
        case .inProgress:
            return "In Progress"
        case .unknown:
            return "Unknown"
        }
    }
}

struct PullRequestInfo: Codable {
    let url: String
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case htmlUrl = "html_url"
    }
}

struct GitHubCheckRun: Codable, Identifiable {
    let id: Int
    let headSha: String
    let status: String
    let conclusion: String?
    let name: String
    let startedAt: Date?
    let completedAt: Date?
    let output: CheckRunOutput?
    let htmlUrl: String?
    let detailsUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status, conclusion, name, output
        case headSha = "head_sha"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case htmlUrl = "html_url"
        case detailsUrl = "details_url"
    }
    
    var isComplete: Bool {
        status == "completed"
    }
    
    var isSuccessful: Bool {
        conclusion == "success"
    }
    
    var isFailed: Bool {
        conclusion == "failure"
    }
    
    var isInProgress: Bool {
        status == "in_progress" || status == "queued"
    }
}

struct CheckRunOutput: Codable {
    let title: String?
    let summary: String?
    let annotationsCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case title, summary
        case annotationsCount = "annotations_count"
    }
}

struct GitHubCheckRunsResponse: Codable {
    let checkRuns: [GitHubCheckRun]
    
    enum CodingKeys: String, CodingKey {
        case checkRuns = "check_runs"
    }
}

struct GitHubPullRequestDetails: Codable {
    let head: PRHead
    
    struct PRHead: Codable {
        let sha: String
    }
}

struct GitHubValidationResult {
    let isValid: Bool
    let user: GitHubUser?
    let error: String?
    let repositories: [GitHubRepository]
    let organizations: [GitHubOrganization]
    let hasMoreRepositories: Bool
    let totalRepositoryCount: Int?
    
    init(isValid: Bool, user: GitHubUser?, error: String?, repositories: [GitHubRepository] = [], organizations: [GitHubOrganization] = [], hasMoreRepositories: Bool = false, totalRepositoryCount: Int? = nil) {
        self.isValid = isValid
        self.user = user
        self.error = error
        self.repositories = repositories
        self.organizations = organizations
        self.hasMoreRepositories = hasMoreRepositories
        self.totalRepositoryCount = totalRepositoryCount
    }
    
    var accessibleReposCount: Int {
        repositories.count
    }
    
    var displayedRepositories: [GitHubRepository] {
        Array(repositories.prefix(5))
    }
    
    var remainingReposCount: Int {
        max(0, repositories.count - 5)
    }
}

class GitHubAPIService: ObservableObject {
    static let shared = GitHubAPIService()
    
    @Published var validationResult: GitHubValidationResult?
    @Published var isValidating: Bool = false
    
    private let baseURL = "https://api.github.com"
    
    private var urlSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        return URLSession(configuration: config)
    }
    
    private let jsonDecoder: JSONDecoder
    
    // Testing support
    #if DEBUG
    func setValidationStateForTesting(isValidating: Bool, result: GitHubValidationResult?) {
        self.isValidating = isValidating
        self.validationResult = result
    }
    #endif
    
    private init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
    }
    
    func validateToken(_ token: String) async {
        await MainActor.run {
            isValidating = true
            validationResult = nil
        }
        
        do {
            // Validate token by getting user info
            let user = try await fetchUser(token: token)
            
            // Fetch repositories (limited to first 100 for performance)
            let repositories = try await fetchRepositories(token: token)
            
            // Fetch organizations
            let organizations = try await fetchOrganizations(token: token)
            
            let result = GitHubValidationResult(
                isValid: true,
                user: user,
                error: nil,
                repositories: repositories,
                organizations: organizations,
                hasMoreRepositories: repositories.count >= 100,
                totalRepositoryCount: repositories.count >= 100 ? nil : repositories.count
            )
            
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
            }
            
        } catch {
            let errorMessage: String
            if let gitHubError = error as? GitHubAPIError {
                errorMessage = gitHubError.userFriendlyDescription
            } else {
                errorMessage = "Unable to connect to GitHub. Please check your token and network connection."
            }
            
            let result = GitHubValidationResult(
                isValid: false,
                user: nil,
                error: errorMessage,
                repositories: [],
                organizations: [],
                hasMoreRepositories: false,
                totalRepositoryCount: nil
            )
            
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
            }
        }
    }
    
    func fetchUser(token: String) async throws -> GitHubUser {
        guard let url = URL(string: "\(baseURL)/user") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        return try jsonDecoder.decode(GitHubUser.self, from: data)
    }
    
    private func fetchRepositories(token: String) async throws -> [GitHubRepository] {
        guard let url = URL(string: "\(baseURL)/user/repos?per_page=100&sort=updated") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        return try jsonDecoder.decode([GitHubRepository].self, from: data)
    }
    
    private func fetchOrganizations(token: String) async throws -> [GitHubOrganization] {
        guard let url = URL(string: "\(baseURL)/user/orgs") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        return try jsonDecoder.decode([GitHubOrganization].self, from: data)
    }
    
    func clearValidation() {
        validationResult = nil
    }
    
    func fetchCheckRuns(for owner: String, repo: String, sha: String, token: String) async throws -> [GitHubCheckRun] {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/commits/\(sha)/check-runs") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        do {
            let checkRunsResponse = try jsonDecoder.decode(GitHubCheckRunsResponse.self, from: data)
            return checkRunsResponse.checkRuns
        } catch {
            #if DEBUG
            print("Check runs JSON decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                let truncated = String(responseString.prefix(200))
                print("Response preview: \(truncated)...")
            }
            #endif
            throw error
        }
    }
    
    func fetchOpenPullRequests(token: String) async throws -> [GitHubPullRequest] {
        // First get user info to get the username
        let user = try await fetchUser(token: token)
        
        guard let url = URL(string: "\(baseURL)/search/issues?q=is:pr+is:open+author:\(user.login)&sort=updated&per_page=50") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        struct SearchResponse: Codable {
            let items: [GitHubPullRequest]
        }
        
        do {
            let searchResponse = try jsonDecoder.decode(SearchResponse.self, from: data)
            return searchResponse.items
        } catch {
            // Log non-sensitive debugging information
            #if DEBUG
            print("GitHub API JSON decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                // Only log first 200 characters to avoid exposing sensitive data
                let truncated = String(responseString.prefix(200))
                print("Response preview: \(truncated)...")
            }
            #endif
            throw error
        }
    }
    
    func searchPullRequests(query: String, token: String) async throws -> [GitHubPullRequest] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/search/issues?q=\(encodedQuery)&sort=updated&per_page=50") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        struct SearchResponse: Codable {
            let items: [GitHubPullRequest]
        }
        
        do {
            let searchResponse = try jsonDecoder.decode(SearchResponse.self, from: data)
            return searchResponse.items
        } catch {
            #if DEBUG
            print("GitHub API JSON decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                let truncated = String(responseString.prefix(200))
                print("Response preview: \(truncated)...")
            }
            #endif
            throw error
        }
    }
    
    func fetchPullRequestDetails(owner: String, repo: String, number: Int, token: String) async throws -> GitHubPullRequestDetails {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/pulls/\(number)") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        try handleAPIResponse(httpResponse)
        
        return try jsonDecoder.decode(GitHubPullRequestDetails.self, from: data)
    }
    
    private func handleAPIResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            break
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            if let rateLimitRemaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
               rateLimitRemaining == "0" {
                throw GitHubAPIError.rateLimitExceeded
            } else {
                throw GitHubAPIError.forbidden
            }
        case 404:
            throw GitHubAPIError.notFound
        default:
            throw GitHubAPIError.httpError(response.statusCode)
        }
    }
}

enum GitHubAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimitExceeded
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub API URL"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .unauthorized:
            return "Invalid or expired GitHub token"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
    
    var userFriendlyDescription: String {
        switch self {
        case .unauthorized:
            return "Invalid or expired GitHub token. Please check your token in Preferences."
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded. Please try again in a few minutes."
        case .forbidden:
            return "Access denied. Your token may need 'repo' scope to access pull requests."
        case .notFound:
            return "API endpoint not found. This may indicate an issue with your token's permissions."
        case .httpError(let code):
            return "GitHub API error (HTTP \(code)). Please try again or check your token."
        case .invalidURL:
            return "Invalid API URL. This is a bug - please report it."
        case .invalidResponse:
            return "Invalid response from GitHub. Please try again."
        }
    }
}