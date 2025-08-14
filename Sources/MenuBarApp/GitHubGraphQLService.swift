import Foundation
import Combine

class GitHubGraphQLService: ObservableObject {
    static let shared = GitHubGraphQLService()
    
    @Published var validationResult: GitHubValidationResult?
    @Published var isValidating: Bool = false
    
    private let graphQLClient = MinimalGraphQLClient()
    private let restClient = GitHubAPIService.shared // Keep REST client for workflow jobs
    
    private init() {}
    
    func validateToken(_ token: String) async {
        await MainActor.run {
            isValidating = true
            validationResult = nil
        }
        
        do {
            // Use simple GraphQL query for validation
            let query = """
                query {
                    viewer {
                        login
                        id
                        repositories(first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
                            nodes {
                                id
                                name
                                nameWithOwner
                                isPrivate
                                owner {
                                    login
                                }
                            }
                            totalCount
                        }
                        organizations(first: 100) {
                            nodes {
                                id
                                login
                                description
                            }
                        }
                    }
                }
                """
            
            struct ValidationResponse: Codable {
                let viewer: Viewer
                
                struct Viewer: Codable {
                    let login: String
                    let id: String
                    let repositories: RepositoryConnection
                    let organizations: OrganizationConnection
                    
                    struct RepositoryConnection: Codable {
                        let nodes: [Repository]
                        let totalCount: Int
                        
                        struct Repository: Codable {
                            let id: String
                            let name: String
                            let nameWithOwner: String
                            let isPrivate: Bool
                            let owner: Owner
                            
                            struct Owner: Codable {
                                let login: String
                            }
                        }
                    }
                    
                    struct OrganizationConnection: Codable {
                        let nodes: [Organization]
                        
                        struct Organization: Codable {
                            let id: String
                            let login: String
                            let description: String?
                        }
                    }
                }
            }
            
            let response: ValidationResponse = try await graphQLClient.execute(
                query: query,
                token: token
            )
            
            // Convert to existing types
            let user = GitHubUser(
                login: response.viewer.login,
                id: Int(response.viewer.id.dropFirst(4).prefix(while: { $0.isNumber })) ?? 0
            )
            
            let repositories = response.viewer.repositories.nodes.map { repo in
                GitHubRepository(
                    id: Int(repo.id.dropFirst(4).prefix(while: { $0.isNumber })) ?? 0,
                    name: repo.name,
                    fullName: repo.nameWithOwner,
                    private: repo.isPrivate,
                    owner: GitHubOwner(login: repo.owner.login, type: "User")
                )
            }
            
            let organizations = response.viewer.organizations.nodes.map { org in
                GitHubOrganization(
                    id: Int(org.id.dropFirst(4).prefix(while: { $0.isNumber })) ?? 0,
                    login: org.login,
                    description: org.description
                )
            }
            
            let result = GitHubValidationResult(
                isValid: true,
                user: user,
                error: nil,
                repositories: repositories,
                organizations: organizations,
                hasMoreRepositories: repositories.count >= 100,
                totalRepositoryCount: response.viewer.repositories.totalCount
            )
            
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
            }
            
        } catch {
            let errorMessage = error.localizedDescription
            
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
    
    func clearValidation() {
        validationResult = nil
    }
    
    func searchPullRequests(query: String, token: String) async throws -> [GitHubPullRequest] {
        // Use comprehensive GraphQL query for pull request search
        let graphQLQuery = """
            query($searchQuery: String!) {
                search(query: $searchQuery, type: ISSUE, first: 50) {
                    nodes {
                        ... on PullRequest {
                            id
                            number
                            title
                            url
                            state
                            isDraft
                            createdAt
                            updatedAt
                            mergeable
                            mergeStateStatus
                            
                            author {
                                login
                                ... on User {
                                    id
                                }
                            }
                            
                            repository {
                                name
                                owner {
                                    login
                                }
                            }
                            
                            headRefOid
                            
                            reviewRequests(first: 10) {
                                nodes {
                                    requestedReviewer {
                                        ... on User {
                                            login
                                            id
                                        }
                                        ... on Team {
                                            name
                                            id
                                        }
                                    }
                                }
                            }
                            
                            assignees(first: 10) {
                                nodes {
                                    login
                                    id
                                }
                            }
                            
                            commits(last: 1) {
                                nodes {
                                    commit {
                                        checkSuites(first: 10) {
                                            nodes {
                                                checkRuns(first: 100) {
                                                    nodes {
                                                        id
                                                        name
                                                        status
                                                        conclusion
                                                        startedAt
                                                        completedAt
                                                        detailsUrl
                                                        
                                                        checkSuite {
                                                            app {
                                                                slug
                                                            }
                                                            workflowRun {
                                                                databaseId
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        status {
                                            contexts {
                                                id
                                                state
                                                description
                                                targetUrl
                                                context
                                                createdAt
                                                creator {
                                                    login
                                                    ... on User {
                                                        id
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            """
        
        struct PullRequestSearchResponse: Codable {
            let search: Search
            
            struct Search: Codable {
                let nodes: [PullRequestNode?]
                
                struct PullRequestNode: Codable {
                    let id: String
                    let number: Int
                    let title: String
                    let url: String
                    let state: String
                    let isDraft: Bool
                    let createdAt: String
                    let updatedAt: String
                    let mergeable: String?
                    let mergeStateStatus: String
                    let headRefOid: String
                    let author: Author?
                    let repository: Repository
                    let reviewRequests: ReviewRequests?
                    let assignees: Assignees?
                    let commits: Commits
                    
                    struct Author: Codable {
                        let login: String
                        let id: String?
                    }
                    
                    struct Repository: Codable {
                        let name: String
                        let owner: Owner
                        
                        struct Owner: Codable {
                            let login: String
                        }
                    }
                    
                    struct ReviewRequests: Codable {
                        let nodes: [ReviewRequestNode?]
                        
                        struct ReviewRequestNode: Codable {
                            let requestedReviewer: RequestedReviewer?
                            
                            struct RequestedReviewer: Codable {
                                let login: String?
                                let id: String?
                                let name: String? // For teams
                            }
                        }
                    }
                    
                    struct Assignees: Codable {
                        let nodes: [AssigneeNode?]
                        
                        struct AssigneeNode: Codable {
                            let login: String
                            let id: String
                        }
                    }
                    
                    struct Commits: Codable {
                        let nodes: [CommitNode?]
                        
                        struct CommitNode: Codable {
                            let commit: Commit
                            
                            struct Commit: Codable {
                                let checkSuites: CheckSuites?
                                let status: Status?
                                
                                struct CheckSuites: Codable {
                                    let nodes: [CheckSuiteNode?]
                                    
                                    struct CheckSuiteNode: Codable {
                                        let checkRuns: CheckRuns?
                                        
                                        struct CheckRuns: Codable {
                                            let nodes: [CheckRunNode?]
                                            
                                            struct CheckRunNode: Codable {
                                                let id: String
                                                let name: String
                                                let status: String
                                                let conclusion: String?
                                                let startedAt: String?
                                                let completedAt: String?
                                                let detailsUrl: String?
                                                let checkSuite: CheckSuite
                                                
                                                struct CheckSuite: Codable {
                                                    let app: App?
                                                    let workflowRun: WorkflowRun?
                                                    
                                                    struct App: Codable {
                                                        let slug: String
                                                    }
                                                    
                                                    struct WorkflowRun: Codable {
                                                        let databaseId: Int?
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                struct Status: Codable {
                                    let contexts: [StatusContext]
                                    
                                    struct StatusContext: Codable {
                                        let id: String
                                        let state: String
                                        let description: String?
                                        let targetUrl: String?
                                        let context: String
                                        let createdAt: String
                                        let creator: Creator?
                                        
                                        struct Creator: Codable {
                                            let login: String
                                            let id: String?
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let response: PullRequestSearchResponse = try await graphQLClient.execute(
            query: graphQLQuery,
            variables: ["searchQuery": query],
            token: token
        )
        
        // Convert GraphQL response to existing GitHubPullRequest models
        var pullRequests: [GitHubPullRequest] = []
        
        for node in response.search.nodes {
            guard let prNode = node else { continue }
            
            // Parse dates
            let dateFormatter = ISO8601DateFormatter()
            let createdAt = dateFormatter.date(from: prNode.createdAt) ?? Date()
            let updatedAt = dateFormatter.date(from: prNode.updatedAt) ?? Date()
            
            // Create the PR object
            var pr = GitHubPullRequest(
                id: prNode.number, // Use PR number as ID instead of parsing GraphQL ID
                number: prNode.number,
                title: prNode.title,
                htmlUrl: prNode.url,
                state: prNode.state.lowercased(),
                draft: prNode.isDraft,
                createdAt: createdAt,
                updatedAt: updatedAt,
                user: GitHubUser(
                    login: prNode.author?.login ?? "unknown",
                    id: extractNumericId(from: prNode.author?.id ?? "")
                ),
                pullRequest: PullRequestInfo(url: prNode.url, htmlUrl: prNode.url),
                repositoryUrl: "https://api.github.com/repos/\(prNode.repository.owner.login)/\(prNode.repository.name)",
                headSha: prNode.headRefOid
            )
            
            // Set mergeable state
            pr.mergeable = prNode.mergeable == "MERGEABLE"
            pr.mergeableState = mapMergeStateStatus(prNode.mergeStateStatus)
            
            // Map requested reviewers
            pr.requestedReviewers = prNode.reviewRequests?.nodes.compactMap { reviewRequest in
                guard let reviewer = reviewRequest?.requestedReviewer else { return nil }
                return GitHubUser(
                    login: reviewer.login ?? reviewer.name ?? "unknown",
                    id: extractNumericId(from: reviewer.id ?? "")
                )
            } ?? []
            
            // Map assignees
            pr.assignees = prNode.assignees?.nodes.compactMap { assignee in
                guard let assignee = assignee else { return nil }
                return GitHubUser(
                    login: assignee.login,
                    id: extractNumericId(from: assignee.id)
                )
            } ?? []
            
            // Map check runs and commit statuses
            if let lastCommit = prNode.commits.nodes.last??.commit {
                // Map check runs (deduplicate by ID since multiple check suites can contain same check run)
                var checkRunsById: [Int: GitHubCheckRun] = [:]
                if let checkSuites = lastCommit.checkSuites {
                    for suite in checkSuites.nodes {
                        guard let suite = suite, let runs = suite.checkRuns else { continue }
                        for run in runs.nodes {
                            guard let run = run else { continue }
                            
                            let checkRunId = extractNumericId(from: run.id)
                            // Use hash-based fallback ID if GraphQL ID parsing fails to prevent duplicates
                            let uniqueId = checkRunId != 0 ? checkRunId : run.id.hashValue
                            let checkRun = GitHubCheckRun(
                                id: uniqueId,
                                headSha: prNode.headRefOid,
                                status: run.status.lowercased(),
                                conclusion: run.conclusion?.lowercased(),
                                name: run.name,
                                startedAt: run.startedAt.flatMap { dateFormatter.date(from: $0) },
                                completedAt: run.completedAt.flatMap { dateFormatter.date(from: $0) },
                                output: nil,
                                htmlUrl: run.detailsUrl,
                                detailsUrl: run.detailsUrl,
                                app: run.checkSuite.app.map { 
                                    CheckRunApp(id: 0, slug: $0.slug, name: $0.slug) 
                                },
                                jobs: []
                            )
                            checkRunsById[uniqueId] = checkRun
                        }
                    }
                }
                pr.checkRuns = Array(checkRunsById.values)
                
                // Map commit statuses
                if let status = lastCommit.status {
                    pr.commitStatuses = status.contexts.map { context in
                        GitHubCommitStatus(
                            id: extractNumericId(from: context.id),
                            state: context.state.lowercased(),
                            description: context.description,
                            targetUrl: context.targetUrl,
                            context: context.context,
                            createdAt: dateFormatter.date(from: context.createdAt) ?? Date(),
                            updatedAt: Date(),
                            creator: context.creator.map { 
                                GitHubUser(login: $0.login, id: extractNumericId(from: $0.id ?? "")) 
                            }
                        )
                    }
                }
            }
            
            pullRequests.append(pr)
        }
        
        // For GitHub Actions check runs, still need to fetch workflow jobs via REST
        await fetchWorkflowJobsForPullRequests(&pullRequests, token: token)
        
        
        return pullRequests
    }
    
    private func extractNumericId(from graphQLId: String) -> Int {
        // GitHub GraphQL IDs are base64 encoded, extract numeric part
        if let data = Data(base64Encoded: graphQLId),
           let decoded = String(data: data, encoding: .utf8) {
            let components = decoded.components(separatedBy: ":")
            if components.count >= 2, let numericId = Int(components[1]) {
                return numericId
            }
        }
        return 0
    }
    
    private func mapMergeStateStatus(_ status: String) -> String {
        switch status.uppercased() {
        case "BEHIND":
            return "behind"
        case "BLOCKED":
            return "blocked"
        case "CLEAN":
            return "clean"
        case "DIRTY":
            return "dirty"
        case "DRAFT":
            return "draft"
        case "HAS_HOOKS":
            return "has_hooks"
        case "UNKNOWN":
            return "unknown"
        case "UNSTABLE":
            return "unstable"
        default:
            return "unknown"
        }
    }
    
    private func fetchWorkflowJobsForPullRequests(_ pullRequests: inout [GitHubPullRequest], token: String) async {
        await withTaskGroup(of: (Int, Int, [GitHubWorkflowJob]?).self) { group in
            for (prIndex, pr) in pullRequests.enumerated() {
                guard let repoName = pr.repositoryName,
                      let repoOwner = pr.repositoryOwner else {
                    continue
                }
                
                // Check if any check runs are GitHub Actions with workflow run IDs
                for (checkIndex, checkRun) in pr.checkRuns.enumerated() {
                    if checkRun.isGitHubActions, let runId = checkRun.workflowRunId {
                        group.addTask {
                            do {
                                let jobs = try await self.restClient.fetchWorkflowJobs(
                                    for: repoOwner,
                                    repo: repoName,
                                    runId: runId,
                                    token: token
                                )
                                return (prIndex, checkIndex, jobs)
                            } catch {
                                #if DEBUG
                                print("Failed to fetch workflow jobs for run \(runId): \(error)")
                                #endif
                                return (prIndex, checkIndex, nil)
                            }
                        }
                    }
                }
            }
            
            // Collect results and update PRs
            for await (prIndex, checkIndex, jobs) in group {
                if let jobs = jobs {
                    pullRequests[prIndex].checkRuns[checkIndex].jobs = jobs
                }
            }
        }
    }
    
    // Keep these REST methods for backwards compatibility during migration
    func fetchUser(token: String) async throws -> GitHubUser {
        return try await restClient.fetchUser(token: token)
    }
    
    func fetchCheckRuns(for owner: String, repo: String, sha: String, token: String) async throws -> [GitHubCheckRun] {
        return try await restClient.fetchCheckRuns(for: owner, repo: repo, sha: sha, token: token)
    }
    
    func fetchCommitStatuses(for owner: String, repo: String, sha: String, token: String) async throws -> [GitHubCommitStatus] {
        return try await restClient.fetchCommitStatuses(for: owner, repo: repo, sha: sha, token: token)
    }
    
    func fetchPullRequestDetails(owner: String, repo: String, number: Int, token: String) async throws -> GitHubPullRequestDetails {
        return try await restClient.fetchPullRequestDetails(owner: owner, repo: repo, number: number, token: token)
    }
    
    func fetchWorkflowJobs(for owner: String, repo: String, runId: Int, token: String) async throws -> [GitHubWorkflowJob] {
        return try await restClient.fetchWorkflowJobs(for: owner, repo: repo, runId: runId, token: token)
    }
}

// Helper to extract owner from repository URL
private func extractOwnerFromRepositoryUrl(_ url: String) -> String? {
    let pattern = #"^https://api\.github\.com/repos/([^/]+)/[^/]+(?:/.*)?$"#
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(url.startIndex..<url.endIndex, in: url)
        if let match = regex.firstMatch(in: url, options: [], range: range) {
            let ownerRange = Range(match.range(at: 1), in: url)
            if let ownerRange = ownerRange {
                return String(url[ownerRange])
            }
        }
    } catch {
        if let url = URL(string: url),
           url.pathComponents.count >= 3 {
            return url.pathComponents[2]
        }
    }
    return nil
}