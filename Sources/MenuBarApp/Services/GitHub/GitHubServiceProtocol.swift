import Foundation
import Combine

protocol GitHubServiceProtocol: ObservableObject {
    var isValidating: Bool { get }
    var validationResult: GitHubValidationResult? { get }
    
    func validateToken(_ token: String) async -> GitHubValidationResult
    func fetchUser(token: String) async throws -> GitHubUser
    func searchPullRequests(query: String, token: String) async throws -> [GitHubPullRequest] 
    func fetchPullRequestDetails(owner: String, repo: String, number: Int, token: String) async throws -> GitHubPullRequestDetails
    func fetchRepositories(token: String) async throws -> [GitHubRepository]
    func fetchOrganizations(token: String) async throws -> [GitHubOrganization]
    
    // For testing
    func setValidationStateForTesting(isValidating: Bool, result: GitHubValidationResult?)
}