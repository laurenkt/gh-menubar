import SwiftUI
import Combine

struct QueryResult: Identifiable {
    let id = UUID()
    let query: QueryConfiguration
    var pullRequests: [GitHubPullRequest]
    
    init(query: QueryConfiguration, pullRequests: [GitHubPullRequest] = []) {
        self.query = query
        self.pullRequests = pullRequests
    }
}

// MARK: - Configuration Constants
private enum ViewModelConstants {
    static let autoRefreshInterval: TimeInterval = 300 // 5 minutes
}

@MainActor
class PullRequestViewModel: ObservableObject {
    @Published var pullRequests: [GitHubPullRequest] = []
    @Published var queryResults: [QueryResult] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentUserLogin: String?
    @Published var lastRefreshTime: Date?
    
    private let apiService = GitHubGraphQLService.shared
    private let appSettings = AppSettings.shared
    private var refreshTimer: Timer?
    
    var pendingActionsCount: Int {
        guard let userLogin = currentUserLogin else { return 0 }
        
        var count = 0
        
        for queryResult in queryResults {
            for pr in queryResult.pullRequests {
                // Count PRs that need review (only if query allows it)
                if pr.needsReview && queryResult.query.includeInPendingReviewsCount {
                    count += 1
                }
                // Count PRs authored by user with failing checks or branch conflicts (only if query allows it)
                else if pr.user.login == userLogin && 
                        (pr.hasFailingChecks || pr.hasBranchConflicts) && 
                        queryResult.query.includeInFailingChecksCount {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    init() {
        startAutoRefresh()
        
        // Listen for query updates from settings
        NotificationCenter.default.addObserver(
            forName: .queriesUpdated, 
            object: nil, 
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    func fetchPullRequests() async {
        guard let token = appSettings.getAPIKey() else {
            errorMessage = "No API key configured"
            return
        }
        
        // Prevent concurrent fetching
        guard !isLoading else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let queries = appSettings.queries
        guard !queries.isEmpty else {
            errorMessage = "No search queries configured"
            isLoading = false
            return
        }
        
        do {
            // Fetch current user info first
            let user = try await apiService.fetchUser(token: token)
            currentUserLogin = user.login
            
            var results: [QueryResult] = []
            
            // Fetch PRs for each query
            await withTaskGroup(of: (QueryConfiguration, [GitHubPullRequest]?).self) { group in
                for query in queries {
                    group.addTask {
                        do {
                            let prs = try await self.apiService.searchPullRequests(query: query.query, token: token)
                            return (query, prs)
                        } catch {
                            #if DEBUG
                            print("Failed to fetch PRs for query '\(query.title)': \(error)")
                            #endif
                            return (query, nil)
                        }
                    }
                }
                
                for await (query, prs) in group {
                    let queryResult = QueryResult(
                        query: query,
                        pullRequests: prs ?? []
                    )
                    results.append(queryResult)
                }
            }
            
            // GraphQL service already fetches workflow jobs for GitHub Actions check runs
            
            // Sort results by query order from settings
            let queryOrder = queries.map { $0.id }
            results.sort { first, second in
                let firstIndex = queryOrder.firstIndex(of: first.query.id) ?? Int.max
                let secondIndex = queryOrder.firstIndex(of: second.query.id) ?? Int.max
                return firstIndex < secondIndex
            }
            
            queryResults = results
            
            // Keep the old pullRequests for backward compatibility
            pullRequests = results.flatMap { $0.pullRequests }
            
            lastRefreshTime = Date()
            errorMessage = nil
        } catch {
            queryResults = []
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
        let refreshInterval = appSettings.refreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
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