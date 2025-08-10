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
                } else if viewModel.pullRequests.isEmpty && !viewModel.isLoading {
                    Text("No open pull requests")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.pullRequests) { pr in
                                PullRequestRow(pullRequest: pr)
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
                    Text("#\(pullRequest.number)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
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