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
}

struct GitHubOrganization: Codable, Identifiable {
    let id: Int
    let login: String
    let description: String?
}

struct GitHubValidationResult {
    let isValid: Bool
    let user: GitHubUser?
    let repositories: [GitHubRepository]
    let organizations: [GitHubOrganization]
    let error: String?
    let hasMoreRepositories: Bool
    let totalRepositoryCount: Int?
    
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
    
    private init() {}
    
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
                repositories: repositories,
                organizations: organizations,
                error: nil,
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
                repositories: [],
                organizations: [],
                error: errorMessage,
                hasMoreRepositories: false,
                totalRepositoryCount: nil
            )
            
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
            }
        }
    }
    
    private func fetchUser(token: String) async throws -> GitHubUser {
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
        
        return try JSONDecoder().decode(GitHubUser.self, from: data)
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
        
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
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
        
        return try JSONDecoder().decode([GitHubOrganization].self, from: data)
    }
    
    func clearValidation() {
        validationResult = nil
    }
    
    private func handleAPIResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200:
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
            return "Invalid or expired GitHub token. Please check your token."
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded. Please try again later."
        case .forbidden:
            return "Access denied. Please check your token permissions."
        case .notFound:
            return "Resource not found. Please check your token permissions."
        default:
            return "Unable to connect to GitHub. Please check your network connection."
        }
    }
}