import SwiftUI

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var githubService = GitHubAPIService.shared
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var saveSuccess: Bool = false
    @State private var selectedTab: SettingsTab = .api
    
    enum SettingsTab: String, CaseIterable {
        case api = "API"
        case queries = "Queries"
        case general = "General"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Settings", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 20)
            
            switch selectedTab {
            case .api:
                APISettingsView(
                    apiKey: $apiKey,
                    showAPIKey: $showAPIKey,
                    showSaveAlert: $showSaveAlert,
                    saveSuccess: $saveSuccess,
                    saveAPIKey: saveAPIKey,
                    removeAPIKey: removeAPIKey
                )
            case .queries:
                QueriesSettingsView()
            case .general:
                GeneralSettingsView()
            }
        }
        .padding(20)
        .frame(width: 500)
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text(saveSuccess ? "Success" : "Error"),
                message: Text(saveSuccess ? "API key saved successfully" : "Failed to save API key"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadExistingAPIKey()
            validateExistingToken()
        }
    }
    
    private func loadExistingAPIKey() {
        if let existingKey = appSettings.getAPIKey() {
            apiKey = existingKey
        }
    }
    
    private func saveAPIKey() {
        let success = appSettings.saveAPIKey(apiKey)
        saveSuccess = success
        showSaveAlert = true
        
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let window = NSApp.keyWindow {
                    window.close()
                }
            }
        }
    }
    
    private func removeAPIKey() {
        _ = appSettings.deleteAPIKey()
        apiKey = ""
        githubService.clearValidation()
    }
    
    private func validateExistingToken() {
        if let existingKey = appSettings.getAPIKey() {
            Task {
                await githubService.validateToken(existingKey)
            }
        }
    }
}

struct TokenValidationResultView: View {
    @StateObject private var githubService = GitHubAPIService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if githubService.isValidating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing GitHub connection...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let result = githubService.validationResult {
                if result.isValid {
                    validTokenView(result: result)
                } else {
                    invalidTokenView(result: result)
                }
            }
        }
    }
    
    private func validTokenView(result: GitHubValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connection successful", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
                .bold()
            
            if let user = result.user {
                Text("Authenticated as: \(user.login)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Repositories section
            VStack(alignment: .leading, spacing: 4) {
                Text("Accessible Repositories:")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.primary)
                
                if result.repositories.isEmpty {
                    Text("No repositories accessible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(result.displayedRepositories) { repo in
                            HStack {
                                Image(systemName: repo.private ? "lock.fill" : "globe")
                                    .font(.caption2)
                                    .foregroundColor(repo.private ? .orange : .blue)
                                Text(repo.fullName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        
                        if result.remainingReposCount > 0 {
                            Text("and \(result.remainingReposCount) more...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
            }
            
            Divider()
            
            // Organizations section
            VStack(alignment: .leading, spacing: 4) {
                Text("Organizations:")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.primary)
                
                if result.organizations.isEmpty {
                    Text("No organizations accessible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(result.organizations) { org in
                            HStack {
                                Image(systemName: "building.2")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Text(org.login)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func invalidTokenView(result: GitHubValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connection failed", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
                .bold()
            
            if let error = result.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct APISettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var githubService = GitHubAPIService.shared
    
    @Binding var apiKey: String
    @Binding var showAPIKey: Bool
    @Binding var showSaveAlert: Bool
    @Binding var saveSuccess: Bool
    
    let saveAPIKey: () -> Void
    let removeAPIKey: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("GitHub API Settings")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Personal Access Token")
                    .font(.headline)
                
                HStack {
                    if showAPIKey {
                        TextField("Enter your GitHub personal access token", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter your GitHub personal access token", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("You can create a personal access token at github.com/settings/tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Save") {
                    saveAPIKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty)
                
                Button("Test Token") {
                    Task {
                        await githubService.validateToken(apiKey)
                    }
                }
                .disabled(apiKey.isEmpty || githubService.isValidating)
                
                if appSettings.hasAPIKey {
                    Button("Remove Saved Token") {
                        removeAPIKey()
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            
            if appSettings.hasAPIKey && apiKey.isEmpty {
                Label("API key is already saved in Keychain", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            TokenValidationResultView()
        }
    }
}

struct QueriesSettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @State private var editingQuery: QueryConfiguration?
    @State private var showingSuggestions = false
    @State private var newQueryTitle = ""
    @State private var newQueryText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Search Queries")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Menu {
                    ForEach(QueryConfiguration.suggestedQueries) { suggestion in
                        Button(suggestion.title) {
                            appSettings.addQuery(suggestion)
                        }
                        .disabled(appSettings.queries.contains(where: { $0.query == suggestion.query }))
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
                .menuStyle(.borderlessButton)
            }
            
            Text("Configure custom search queries to organize your pull requests")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(appSettings.queries.enumerated()), id: \.element.id) { index, query in
                        QueryRowView(
                            query: query,
                            onEdit: { editingQuery = query },
                            onDelete: { appSettings.removeQuery(at: index) }
                        )
                    }
                    
                    if appSettings.queries.isEmpty {
                        Text("No queries configured")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .sheet(item: $editingQuery) { query in
            QueryEditSheet(
                query: query,
                onSave: { updatedQuery in
                    if let index = appSettings.queries.firstIndex(where: { $0.id == query.id }) {
                        appSettings.updateQuery(at: index, with: updatedQuery)
                    }
                }
            )
        }
    }
}

struct QueryRowView: View {
    let query: QueryConfiguration
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(query.title)
                    .font(.headline)
                
                Text(query.query)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Edit") { onEdit() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                
                Button("Delete") { onDelete() }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QueryEditSheet: View {
    @State private var title: String
    @State private var query: String
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (QueryConfiguration) -> Void
    
    init(query: QueryConfiguration, onSave: @escaping (QueryConfiguration) -> Void) {
        self._title = State(initialValue: query.title)
        self._query = State(initialValue: query.query)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Query")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Title:")
                    .font(.headline)
                TextField("Query title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Query:")
                    .font(.headline)
                TextField("GitHub search query", text: $query)
                    .textFieldStyle(.roundedBorder)
                
                Text("Examples: is:open is:pr author:@me, is:open is:pr review-requested:@me")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    let updatedQuery = QueryConfiguration(title: title, query: query)
                    onSave(updatedQuery)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || query.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

struct GeneralSettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var viewModel = PullRequestViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Refresh Interval")
                    .font(.headline)
                
                Text("How often to automatically check for pull request updates")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Refresh Interval", selection: Binding(
                    get: { appSettings.refreshInterval },
                    set: { newInterval in
                        appSettings.setRefreshInterval(newInterval)
                        viewModel.startAutoRefresh()
                    }
                )) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.interval) { option in
                        Text(option.title).tag(option.interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200, alignment: .leading)
            }
            
            Spacer()
        }
    }
}