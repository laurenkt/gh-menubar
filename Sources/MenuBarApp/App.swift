import SwiftUI

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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appSettings.hasAPIKey {
                Text("GitHub PRs")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Divider()
                
                Text("Pull requests will appear here")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
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
        .frame(width: 280)
        .padding(.vertical, 8)
    }
}