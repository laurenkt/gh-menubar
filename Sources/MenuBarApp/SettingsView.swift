import SwiftUI

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings.shared
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
        }
        .padding(20)
        .frame(width: 450)
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text(saveSuccess ? "Success" : "Error"),
                message: Text(saveSuccess ? "API key saved successfully" : "Failed to save API key"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadExistingAPIKey()
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
    }
}