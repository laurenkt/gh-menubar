import SwiftUI

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var githubService = GitHubAPIService.shared
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var saveSuccess: Bool = false
    
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
            
            // Token validation results
            TokenValidationResultView()
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
                NSApp.keyWindow?.close()
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
}