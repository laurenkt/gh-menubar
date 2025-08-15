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
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var currentUserLogin: String?
    @Published private(set) var lastRefreshTime: Date?
    
    private let apiService: any GitHubServiceProtocol
    private let settingsService: any SettingsServiceProtocol
    private let keychainService: any KeychainServiceProtocol
    private var refreshTimer: Timer?
    
    // MARK: - Computed Properties for Backward Compatibility
    
    var isLoading: Bool {
        state.isLoading
    }
    
    var errorMessage: String? {
        state.errorMessage
    }
    
    var queryResults: [QueryResult] {
        state.queryResults
    }
    
    var pullRequests: [GitHubPullRequest] {
        queryResults.flatMap { $0.pullRequests }
    }
    
    init(dependencies: DependencyContainer = DefaultDependencyContainer()) {
        self.apiService = dependencies.gitHubService
        self.settingsService = dependencies.settingsService
        self.keychainService = dependencies.keychainService
        setupAutoRefresh()
        
        // Listen for query updates from settings
        NotificationCenter.default.addObserver(
            forName: .queriesUpdated, 
            object: nil, 
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
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
    
    
    func fetchPullRequests() async {
        guard let token = keychainService.loadAPIKey() else {
            state = .error("No API key configured")
            return
        }
        
        // Prevent concurrent fetching
        guard !state.isLoading else {
            return
        }
        
        state = .loading
        
        let queries = settingsService.queries
        guard !queries.isEmpty else {
            state = .error("No search queries configured")
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
            
            state = .loaded(results)
            lastRefreshTime = Date()
        } catch {
            let errorMessage: String
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
            state = .error(errorMessage)
        }
    }
    
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        // Initial fetch
        Task {
            await fetchPullRequests()
        }
        
        // Refresh at configured interval using weak self to prevent retain cycles
        let refreshInterval = settingsService.refreshInterval
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
    
    // MARK: - Testing Support
    
    #if DEBUG
    func setState(_ newState: ViewState) {
        state = newState
    }
    
    func setCurrentUserLogin(_ login: String?) {
        currentUserLogin = login
    }
    #endif
    
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