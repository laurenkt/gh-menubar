import SwiftUI

// MARK: - UI Configuration Constants
private enum UIConstants {
    static let menuBarWidth: CGFloat = 320
    static let scrollViewMaxHeight: CGFloat = 400
}

@main
struct MenuBarApp: App {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var viewModel = PullRequestViewModel()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(viewModel: viewModel)
        } label: {
            if viewModel.pendingActionsCount > 0 {
                Text("\(viewModel.pendingActionsCount) PRs")
                    .font(.system(size: 12, weight: .medium))
            } else {
                Image(systemName: "arrow.triangle.pull")
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarExtraView: View {
    @StateObject private var appSettings = AppSettings.shared
    @ObservedObject var viewModel: PullRequestViewModel
    
    private func formatLastRefreshTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        if appSettings.hasAPIKey {
            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .disabled(true)
            } else if viewModel.queryResults.isEmpty && !viewModel.isLoading {
                Text("No pull requests found")
                    .disabled(true)
            } else {
                ForEach(viewModel.queryResults) { queryResult in
                    if !queryResult.query.title.isEmpty {
                        Section(queryResult.query.title) {
                            if queryResult.pullRequests.isEmpty {
                                Text("No PRs found")
                                    .disabled(true)
                            } else {
                                ForEach(queryResult.pullRequests) { pr in
                                    PullRequestMenuItem(pullRequest: pr, queryConfig: queryResult.query)
                                }
                            }
                        }
                    } else {
                        ForEach(queryResult.pullRequests) { pr in
                            PullRequestMenuItem(pullRequest: pr, queryConfig: queryResult.query)
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Refresh") {
                viewModel.refresh()
            }
            .keyboardShortcut("r")
            .disabled(viewModel.isLoading)
            
            if let lastRefresh = viewModel.lastRefreshTime {
                Text("Last updated: \(formatLastRefreshTime(lastRefresh))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .disabled(true)
            }
        } else {
            Text("No API Key Configured")
                .disabled(true)
            
            Text("Configure in Preferences...")
                .disabled(true)
        }
        
        Divider()
        
        Button("Preferences...") {
            appSettings.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

struct PullRequestMenuItem: View {
    let pullRequest: GitHubPullRequest
    let queryConfig: QueryConfiguration
    
    private var statusSymbol: String {
        switch pullRequest.checkStatus {
        case .success:
            return "✅"
        case .failed:
            return "❌"
        case .inProgress:
            return "⏳"
        case .unknown:
            return pullRequest.draft ? "📝" : ""
        }
    }
    
    var body: some View {
        if !pullRequest.checkRuns.isEmpty {
            Menu {
                Button(action: {
                    if let url = URL(string: pullRequest.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Open Pull Request")
                }
                
                Divider()
                
                ForEach(pullRequest.checkRuns) { checkRun in
                    if checkRun.isGitHubActions && !checkRun.jobs.isEmpty {
                        Menu {
                            Button(action: {
                                openCheckRun(checkRun)
                            }) {
                                Text("Open Check Run")
                            }
                            
                            Divider()
                            
                            ForEach(checkRun.jobs) { job in
                                if !job.steps.isEmpty {
                                    Menu {
                                        Button(action: {
                                            openWorkflowJob(job)
                                        }) {
                                            Text("Open Job")
                                        }
                                        
                                        Divider()
                                        
                                        ForEach(job.steps) { step in
                                            Button(action: {
                                                // Steps don't have individual URLs, open the job
                                                openWorkflowJob(job)
                                            }) {
                                                Text("\(stepStatusSymbol(step)) \(step.name)")
                                            }
                                            .disabled(true) // Steps don't have individual URLs
                                        }
                                    } label: {
                                        Text("\(jobStatusSymbol(job)) \(job.name)")
                                    }
                                } else {
                                    Button(action: {
                                        openWorkflowJob(job)
                                    }) {
                                        Text("\(jobStatusSymbol(job)) \(job.name)")
                                    }
                                }
                            }
                        } label: {
                            Text("\(checkRunStatusSymbol(checkRun)) \(checkRun.name)")
                        }
                    } else {
                        Button(action: {
                            openCheckRun(checkRun)
                        }) {
                            Text("\(checkRunStatusSymbol(checkRun)) \(checkRun.name)")
                        }
                    }
                }
            } label: {
                Text(buildCompleteText())
            }
        } else {
            Button(action: {
                if let url = URL(string: pullRequest.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(buildCompleteText())
            }
        }
    }
    
    private func openCheckRun(_ checkRun: GitHubCheckRun) {
        if let htmlUrl = checkRun.htmlUrl, let url = URL(string: htmlUrl) {
            NSWorkspace.shared.open(url)
        } else if let detailsUrl = checkRun.detailsUrl, let url = URL(string: detailsUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openWorkflowJob(_ job: GitHubWorkflowJob) {
        if let htmlUrl = job.htmlUrl, let url = URL(string: htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkRunStatusSymbol(_ checkRun: GitHubCheckRun) -> String {
        if checkRun.isSuccessful {
            return "✅"
        } else if checkRun.isFailed {
            return "❌"
        } else if checkRun.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func jobStatusSymbol(_ job: GitHubWorkflowJob) -> String {
        if job.isSuccessful {
            return "✅"
        } else if job.isFailed {
            return "❌"
        } else if job.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func stepStatusSymbol(_ step: GitHubWorkflowStep) -> String {
        if step.isSuccessful {
            return "✅"
        } else if step.isFailed {
            return "❌"
        } else if step.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func buildCompleteText() -> String {
        var result: [String] = []
        
        for component in queryConfig.componentOrder {
            switch component {
            case .statusSymbol:
                result.append(statusSymbol)
                
            case .title:
                result.append(pullRequest.title)
                
            case .separator:
                result.append("–")
                
            case .orgName:
                if let orgName = pullRequest.repositoryOwner, !orgName.isEmpty {
                    result.append(orgName)
                }
                
            case .projectName:
                if let repoName = pullRequest.repositoryName, !repoName.isEmpty {
                    result.append(repoName)
                }
                
            case .prNumber:
                result.append("#\(pullRequest.number)")
                
            case .authorName:
                if !pullRequest.user.login.isEmpty {
                    result.append("@\(pullRequest.user.login)")
                }
            }
        }
        
        let finalResult = result.joined(separator: " ")
        
        #if DEBUG
        print("buildCompleteText for query '\(queryConfig.title)' with component order: \(queryConfig.componentOrder.map(\.rawValue))")
        print("buildCompleteText result: '\(finalResult)'")
        print("repositoryOwner: \(pullRequest.repositoryOwner ?? "nil")")
        print("repositoryName: \(pullRequest.repositoryName ?? "nil")")
        print("user.login: \(pullRequest.user.login)")
        #endif
        
        return finalResult
    }
    
    private func buildInfoText() -> String {
        var components: [String] = []
        
        // Add organization name if enabled
        if queryConfig.showOrgName, let orgName = pullRequest.repositoryOwner, !orgName.isEmpty {
            components.append(orgName)
        }
        
        // Add project name if enabled
        if queryConfig.showProjectName, let repoName = pullRequest.repositoryName, !repoName.isEmpty {
            components.append(repoName)
        }
        
        // Add PR number if enabled
        if queryConfig.showPRNumber {
            components.append("#\(pullRequest.number)")
        }
        
        // Add author name if enabled
        if queryConfig.showAuthorName, !pullRequest.user.login.isEmpty {
            components.append("@\(pullRequest.user.login)")
        }
        
        return components.joined(separator: " ")
    }
}

struct CheckStatusIcon: View {
    let status: CheckStatus
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(statusColor)
            .font(.caption)
    }
    
    private var iconName: String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .inProgress:
            return "clock.fill"
        case .unknown:
            return "circle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .success:
            return .green
        case .failed:
            return .red
        case .inProgress:
            return .orange
        case .unknown:
            return .secondary
        }
    }
}


struct CheckRunStatusIcon: View {
    let checkRun: GitHubCheckRun
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(statusColor)
            .font(.caption)
    }
    
    private var iconName: String {
        if checkRun.isSuccessful {
            return "checkmark.circle.fill"
        } else if checkRun.isFailed {
            return "xmark.circle.fill"
        } else if checkRun.isInProgress {
            return "clock.fill"
        } else {
            return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        if checkRun.isSuccessful {
            return .green
        } else if checkRun.isFailed {
            return .red
        } else if checkRun.isInProgress {
            return .orange
        } else {
            return .secondary
        }
    }
}