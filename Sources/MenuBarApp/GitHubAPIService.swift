import Foundation

class GitHubAPIService: GitHubServiceProtocol {
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
    func setValidationStateForTesting(isValidating: Bool, result: GitHubValidationResult?) {
        self.isValidating = isValidating
        self.validationResult = result
    }
    
    private init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
    }
    
    func validateToken(_ token: String) async -> GitHubValidationResult {
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
            
            return result
            
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
            
            return result
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
    
    func fetchRepositories(token: String) async throws -> [GitHubRepository] {
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
    
    func fetchOrganizations(token: String) async throws -> [GitHubOrganization] {
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
    
    func fetchCommitStatuses(for owner: String, repo: String, sha: String, token: String) async throws -> [GitHubCommitStatus] {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/commits/\(sha)/status") else {
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
            let combinedStatus = try jsonDecoder.decode(GitHubCombinedStatus.self, from: data)
            return combinedStatus.statuses
        } catch {
            #if DEBUG
            print("Commit statuses JSON decoding error: \(error)")
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
    
    func fetchWorkflowJobs(for owner: String, repo: String, runId: Int, token: String) async throws -> [GitHubWorkflowJob] {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs") else {
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
            let jobsResponse = try jsonDecoder.decode(GitHubWorkflowJobsResponse.self, from: data)
            return jobsResponse.jobs
        } catch {
            #if DEBUG
            print("Workflow jobs JSON decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                let truncated = String(responseString.prefix(200))
                print("Response preview: \(truncated)...")
            }
            #endif
            throw error
        }
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

