import SwiftUI

// MARK: - UI Configuration Constants
private enum UIConstants {
    static let menuBarWidth: CGFloat = 320
    static let scrollViewMaxHeight: CGFloat = 400
}

@main
struct MenuBarApp: App {
    @StateObject private var appSettings = AppSettings.shared
    
    var body: some Scene {
        MenuBarExtra("GitHub PRs", systemImage: "arrow.triangle.pull") {
            MenuBarExtraView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarExtraView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var viewModel = PullRequestViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appSettings.hasAPIKey {
                HStack {
                    Text("GitHub PRs")
                        .font(.headline)
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button(action: { viewModel.refresh() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 6)
                
                Divider()
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity)
                } else if viewModel.queryResults.isEmpty && !viewModel.isLoading {
                    Text("No pull requests found")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.queryResults) { queryResult in
                                VStack(alignment: .leading, spacing: 4) {
                                    if !queryResult.query.title.isEmpty {
                                        HStack {
                                            Text(queryResult.query.title)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            if !queryResult.pullRequests.isEmpty {
                                                Text("\(queryResult.pullRequests.count)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.top, queryResult.query.id == viewModel.queryResults.first?.query.id ? 0 : 8)
                                    }
                                    
                                    if queryResult.pullRequests.isEmpty {
                                        Text("No PRs found for this query")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .italic()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 4)
                                    } else {
                                        ForEach(queryResult.pullRequests) { pr in
                                            PullRequestRow(pullRequest: pr)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: UIConstants.scrollViewMaxHeight)
                }
            } else {
                Label("No API Key Configured", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .padding(.vertical, 8)
                
                Text("Please configure your GitHub API key in Preferences")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
        .frame(width: UIConstants.menuBarWidth)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct PullRequestRow: View {
    let pullRequest: GitHubPullRequest
    
    var body: some View {
        Button(action: {
            if let url = URL(string: pullRequest.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if pullRequest.draft {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Text(pullRequest.title)
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Text("#\(pullRequest.number)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        CheckStatusMenu(pullRequest: pullRequest)
                    }
                    
                    if let repoName = pullRequest.repositoryName {
                        Text(repoName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(relativeTime(from: pullRequest.updatedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.0001))
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CheckStatusIndicator: View {
    let status: CheckStatus
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            if status != .unknown {
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(statusColor)
            }
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
    
    private var statusText: String {
        switch status {
        case .success:
            return "✓"
        case .failed:
            return "✗"
        case .inProgress:
            return "⏳"
        case .unknown:
            return ""
        }
    }
}

struct CheckStatusMenu: View {
    let pullRequest: GitHubPullRequest
    
    var body: some View {
        if !pullRequest.checkRuns.isEmpty {
            Menu {
                ForEach(pullRequest.checkRuns) { checkRun in
                    Button(action: {
                        openCheckRun(checkRun)
                    }) {
                        HStack {
                            Text(checkRun.name)
                            Spacer()
                            CheckRunStatusIcon(checkRun: checkRun)
                        }
                    }
                }
            } label: {
                CheckStatusIndicator(status: pullRequest.checkStatus)
            }
            .menuStyle(.borderlessButton)
        } else {
            CheckStatusIndicator(status: pullRequest.checkStatus)
        }
    }
    
    private func openCheckRun(_ checkRun: GitHubCheckRun) {
        if let htmlUrl = checkRun.htmlUrl, let url = URL(string: htmlUrl) {
            NSWorkspace.shared.open(url)
        } else if let detailsUrl = checkRun.detailsUrl, let url = URL(string: detailsUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct CheckRunStatusIcon: View {
    let checkRun: GitHubCheckRun
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
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
    
    private var statusText: String {
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
}