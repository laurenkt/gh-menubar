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
                error: nil
            )
            
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
            }
            
        } catch {
            let result = GitHubValidationResult(
                isValid: false,
                user: nil,
                repositories: [],
                organizations: [],
                error: error.localizedDescription
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw GitHubAPIError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GitHubAPIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }
    
    private func fetchRepositories(token: String) async throws -> [GitHubRepository] {
        guard let url = URL(string: "\(baseURL)/user/repos?per_page=100&sort=updated") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubAPIError.fetchFailed
        }
        
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }
    
    private func fetchOrganizations(token: String) async throws -> [GitHubOrganization] {
        guard let url = URL(string: "\(baseURL)/user/orgs") else {
            throw GitHubAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubAPIError.fetchFailed
        }
        
        return try JSONDecoder().decode([GitHubOrganization].self, from: data)
    }
    
    func clearValidation() {
        validationResult = nil
    }
}

enum GitHubAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub API URL"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .unauthorized:
            return "Invalid or expired GitHub token"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .fetchFailed:
            return "Failed to fetch data from GitHub API"
        }
    }
}