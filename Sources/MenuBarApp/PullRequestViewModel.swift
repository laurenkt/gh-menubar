import SwiftUI
import Combine

// MARK: - Configuration Constants
private enum ViewModelConstants {
    static let autoRefreshInterval: TimeInterval = 300 // 5 minutes
}

@MainActor
class PullRequestViewModel: ObservableObject {
    @Published var pullRequests: [GitHubPullRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let apiService = GitHubAPIService.shared
    private let appSettings = AppSettings.shared
    private var refreshTimer: Timer?
    
    init() {
        startAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    func fetchPullRequests() async {
        guard let token = appSettings.getAPIKey() else {
            errorMessage = "No API key configured"
            return
        }
        
        isLoading = true
        // Clear any previous error when attempting a new request
        errorMessage = nil
        
        do {
            var prs = try await apiService.fetchOpenPullRequests(token: token)
            
            // Fetch check runs for each PR
            await withTaskGroup(of: (Int, [GitHubCheckRun]?).self) { group in
                for (index, pr) in prs.enumerated() {
                    guard let repoName = pr.repositoryName,
                          let repoOwner = extractOwnerFromRepositoryUrl(pr.repositoryUrl) else {
                        continue
                    }
                    
                    group.addTask {
                        do {
                            // First get the PR details to get the head SHA
                            let prDetails = try await self.apiService.fetchPullRequestDetails(
                                owner: repoOwner,
                                repo: repoName,
                                number: pr.number,
                                token: token
                            )
                            
                            let checkRuns = try await self.apiService.fetchCheckRuns(
                                for: repoOwner,
                                repo: repoName,
                                sha: prDetails.head.sha,
                                token: token
                            )
                            return (index, checkRuns)
                        } catch {
                            #if DEBUG
                            print("Failed to fetch check runs for PR \(pr.number): \(error)")
                            #endif
                            return (index, nil)
                        }
                    }
                }
                
                for await (index, checkRuns) in group {
                    if let checkRuns = checkRuns {
                        prs[index].checkRuns = checkRuns
                    }
                }
            }
            
            pullRequests = prs
            errorMessage = nil
        } catch {
            pullRequests = []
            if let gitHubError = error as? GitHubAPIError {
                errorMessage = gitHubError.userFriendlyDescription
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "No internet connection"
                case .timedOut:
                    errorMessage = "Request timed out. Please try again."
                case .cannotFindHost, .cannotConnectToHost:
                    errorMessage = "Cannot connect to GitHub. Check your network."
                default:
                    errorMessage = "Network error: \(urlError.localizedDescription)"
                }
            } else {
                errorMessage = "Failed to fetch pull requests: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        
        // Initial fetch
        Task {
            await fetchPullRequests()
        }
        
        // Refresh at configured interval using weak self to prevent retain cycles
        refreshTimer = Timer.scheduledTimer(withTimeInterval: ViewModelConstants.autoRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.fetchPullRequests()
            }
        }
    }
    
    func refresh() {
        Task {
            await fetchPullRequests()
        }
    }
    
    private func extractOwnerFromRepositoryUrl(_ repositoryUrl: String) -> String? {
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
}