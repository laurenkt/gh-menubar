import SwiftUI

struct MenuBarExtraView: View {
    @ObservedObject var viewModel: PullRequestViewModel
    private let settingsService: any SettingsServiceProtocol
    
    init(viewModel: PullRequestViewModel, dependencies: DependencyContainer = DefaultDependencyContainer()) {
        self.viewModel = viewModel
        self.settingsService = dependencies.settingsService
    }
    
    private func formatLastRefreshTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        if settingsService.hasAPIKey {
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
            settingsService.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}