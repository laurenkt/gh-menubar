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
                Text("\(viewModel.pendingActionsCount) Pending")
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
            return "✓"
        case .failed:
            return "✗"
        case .inProgress:
            return "⏳"
        case .unknown:
            return pullRequest.draft ? "📝" : "•"
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
                    Button(action: {
                        openCheckRun(checkRun)
                    }) {
                        Text("\(checkRunStatusSymbol(checkRun)) \(checkRun.name)")
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
    
    private func checkRunStatusSymbol(_ checkRun: GitHubCheckRun) -> String {
        if checkRun.isSuccessful {
            return "✓"
        } else if checkRun.isFailed {
            return "✗"
        } else if checkRun.isInProgress {
            return "⏳"
        } else {
            return "?"
        }
    }
    
    private func buildCompleteText() -> String {
        var parts: [String] = []
        var currentGroup: [String] = []
        
        for component in queryConfig.componentOrder {
            switch component {
            case .statusSymbol:
                if !currentGroup.isEmpty {
                    parts.append(currentGroup.joined(separator: " "))
                    currentGroup = []
                }
                parts.append(statusSymbol)
                
            case .title:
                if !currentGroup.isEmpty {
                    parts.append(currentGroup.joined(separator: " "))
                    currentGroup = []
                }
                parts.append(pullRequest.title)
                
            case .separator:
                if !currentGroup.isEmpty {
                    parts.append(currentGroup.joined(separator: " "))
                    currentGroup = []
                }
                // Separator is handled by joining with " – "
                
            case .orgName:
                if let orgName = pullRequest.repositoryOwner, !orgName.isEmpty {
                    currentGroup.append(orgName)
                }
                
            case .projectName:
                if let repoName = pullRequest.repositoryName, !repoName.isEmpty {
                    currentGroup.append(repoName)
                }
                
            case .prNumber:
                currentGroup.append("#\(pullRequest.number)")
                
            case .authorName:
                if !pullRequest.user.login.isEmpty {
                    currentGroup.append("@\(pullRequest.user.login)")
                }
            }
        }
        
        if !currentGroup.isEmpty {
            parts.append(currentGroup.joined(separator: " "))
        }
        
        let result = parts.joined(separator: " – ")
        
        #if DEBUG
        print("buildCompleteText for query '\(queryConfig.title)' with component order: \(queryConfig.componentOrder.map(\.rawValue))")
        print("buildCompleteText result: '\(result)'")
        print("repositoryOwner: \(pullRequest.repositoryOwner ?? "nil")")
        print("repositoryName: \(pullRequest.repositoryName ?? "nil")")
        print("user.login: \(pullRequest.user.login)")
        #endif
        
        return result
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