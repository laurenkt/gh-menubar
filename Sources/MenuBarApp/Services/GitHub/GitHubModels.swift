import Foundation

// MARK: - Core Models

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

// MARK: - Pull Request Models

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
    var mergeable: Bool?
    var mergeableState: String?
    var checkRuns: [GitHubCheckRun] = []
    var commitStatuses: [GitHubCommitStatus] = []
    var requestedReviewers: [GitHubUser]?
    var assignees: [GitHubUser]?
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, state, draft, user, mergeable, assignees
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pullRequest = "pull_request"
        case repositoryUrl = "repository_url"
        case headSha = "head_sha"
        case mergeableState = "mergeable_state"
        case requestedReviewers = "requested_reviewers"
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
    
    var hasBranchConflicts: Bool {
        // Check if PR has merge conflicts that prevent checks from running
        let hasConflicts = mergeable == false && mergeableState == "dirty"
        #if DEBUG
        print("PR #\(number): mergeable=\(mergeable?.description ?? "nil"), mergeableState=\(mergeableState ?? "nil"), hasBranchConflicts=\(hasConflicts)")
        #endif
        return hasConflicts
    }
    
    var hasFailingChecks: Bool {
        checkRuns.contains { $0.isFailed } || commitStatuses.contains { $0.isFailure }
    }
    
    var hasInProgressChecks: Bool {
        checkRuns.contains { $0.isInProgress } || commitStatuses.contains { $0.isPending }
    }
    
    var allChecksSuccessful: Bool {
        let hasChecks = !checkRuns.isEmpty || !commitStatuses.isEmpty
        let checkRunsSuccess = checkRuns.isEmpty || checkRuns.allSatisfy { $0.isSuccessful }
        let statusesSuccess = commitStatuses.isEmpty || commitStatuses.allSatisfy { $0.isSuccess }
        return hasChecks && checkRunsSuccess && statusesSuccess
    }
    
    var isReadyToMerge: Bool {
        // A PR is ready to merge when:
        // 1. It's not a draft
        // 2. It's mergeable (no conflicts)
        // 3. Either has no checks OR all checks have passed
        let checksOk = checkRuns.isEmpty || allChecksSuccessful
        let ready = !draft && checksOk && mergeable == true
        #if DEBUG
        print("PR #\(number): isReadyToMerge=\(ready), draft=\(draft), checksOk=\(checksOk), checkRuns.count=\(checkRuns.count), mergeable=\(mergeable?.description ?? "nil")")
        #endif
        return ready
    }
    
    var checkStatus: CheckStatus {
        // Branch conflicts take precedence over check status
        if hasBranchConflicts {
            return .failed
        }
        if checkRuns.isEmpty && commitStatuses.isEmpty {
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
    
    var needsReview: Bool {
        // A PR needs review if it has requested reviewers and is assigned to someone
        // This indicates someone is assigned to review it but hasn't reviewed yet
        if let requestedReviewers = requestedReviewers,
           !requestedReviewers.isEmpty,
           let assignees = assignees,
           !assignees.isEmpty {
            return true
        }
        return false
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

struct GitHubPullRequestDetails: Codable {
    let head: PRHead
    let mergeable: Bool?
    let mergeableState: String?
    let requestedReviewers: [GitHubUser]?
    let assignees: [GitHubUser]?
    
    struct PRHead: Codable {
        let sha: String
    }
    
    enum CodingKeys: String, CodingKey {
        case head, mergeable, assignees
        case mergeableState = "mergeable_state"
        case requestedReviewers = "requested_reviewers"
    }
}

// MARK: - Check Run Models

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
    let app: CheckRunApp?
    var jobs: [GitHubWorkflowJob] = []
    
    enum CodingKeys: String, CodingKey {
        case id, status, conclusion, name, output, app
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
    
    var isGitHubActions: Bool {
        app?.slug == "github-actions"
    }
    
    var workflowRunId: Int? {
        guard let detailsUrl = detailsUrl,
              let url = URL(string: detailsUrl) else { return nil }
        
        // GitHub Actions details URLs have format: 
        // https://github.com/owner/repo/actions/runs/{run_id}/job/{job_id}
        let pathComponents = url.pathComponents
        if let runsIndex = pathComponents.firstIndex(of: "runs"),
           runsIndex + 1 < pathComponents.count,
           let runId = Int(pathComponents[runsIndex + 1]) {
            return runId
        }
        return nil
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

struct CheckRunApp: Codable {
    let id: Int
    let slug: String
    let name: String
}

struct GitHubCheckRunsResponse: Codable {
    let checkRuns: [GitHubCheckRun]
    
    enum CodingKeys: String, CodingKey {
        case checkRuns = "check_runs"
    }
}

// MARK: - Commit Status Models

struct GitHubCommitStatus: Codable, Identifiable {
    let id: Int
    let state: String
    let description: String?
    let targetUrl: String?
    let context: String
    let createdAt: Date
    let updatedAt: Date
    let creator: GitHubUser?
    
    enum CodingKeys: String, CodingKey {
        case id, state, description, context, creator
        case targetUrl = "target_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isSuccess: Bool {
        state == "success"
    }
    
    var isFailure: Bool {
        state == "failure" || state == "error"
    }
    
    var isPending: Bool {
        state == "pending"
    }
    
    var displayName: String {
        // Extract a cleaner name from context (e.g., "ci/circleci: build" -> "CircleCI: build")
        if context.contains("circleci") {
            return context.replacingOccurrences(of: "ci/circleci:", with: "CircleCI:")
                          .replacingOccurrences(of: "ci/circleci/", with: "CircleCI/")
        } else if context.contains("travis") {
            return context.replacingOccurrences(of: "continuous-integration/travis-ci/", with: "Travis CI/")
        } else if context.contains("jenkins") {
            return context.replacingOccurrences(of: "continuous-integration/jenkins/", with: "Jenkins/")
        } else if context.contains("buildkite") {
            return context.replacingOccurrences(of: "buildkite/", with: "Buildkite/")
        } else if context.contains("appveyor") {
            return context.replacingOccurrences(of: "continuous-integration/appveyor/", with: "AppVeyor/")
        }
        return context
    }
}

struct GitHubCombinedStatus: Codable {
    let state: String
    let statuses: [GitHubCommitStatus]
    let sha: String
    let totalCount: Int
    let repository: GitHubRepository
    
    enum CodingKeys: String, CodingKey {
        case state, statuses, sha, repository
        case totalCount = "total_count"
    }
}

// MARK: - Workflow Models

struct GitHubWorkflowJob: Codable, Identifiable {
    let id: Int
    let runId: Int
    let runUrl: String
    let nodeId: String
    let headSha: String
    let url: String
    let htmlUrl: String?
    let status: String
    let conclusion: String?
    let createdAt: Date
    let startedAt: Date
    let completedAt: Date?
    let name: String
    let steps: [GitHubWorkflowStep]
    let checkRunUrl: String?
    let labels: [String]
    let runnerId: Int?
    let runnerName: String?
    let runnerGroupId: Int?
    let runnerGroupName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status, conclusion, name, steps, labels
        case runId = "run_id"
        case runUrl = "run_url"
        case nodeId = "node_id"
        case headSha = "head_sha"
        case url
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case checkRunUrl = "check_run_url"
        case runnerId = "runner_id"
        case runnerName = "runner_name"
        case runnerGroupId = "runner_group_id"
        case runnerGroupName = "runner_group_name"
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

struct GitHubWorkflowStep: Codable, Identifiable {
    let name: String
    let status: String
    let conclusion: String?
    let number: Int
    let startedAt: Date?
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case name, status, conclusion, number
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
    
    var id: Int { number }
    
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

struct GitHubWorkflowJobsResponse: Codable {
    let totalCount: Int
    let jobs: [GitHubWorkflowJob]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case jobs
    }
}

// MARK: - Validation and Error Models

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