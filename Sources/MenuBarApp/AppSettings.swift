import SwiftUI
import AppKit

struct QueryConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var query: String
    
    init(title: String, query: String) {
        self.id = UUID()
        self.title = title
        self.query = query
    }
    
    static let defaultQuery = QueryConfiguration(title: "My Open PRs", query: "is:open is:pr author:@me")
    
    static let suggestedQueries = [
        QueryConfiguration(title: "My Open PRs", query: "is:open is:pr author:@me"),
        QueryConfiguration(title: "Review Requests", query: "is:open is:pr review-requested:@me"),
        QueryConfiguration(title: "My Recent PRs", query: "is:pr author:@me sort:updated-desc"),
        QueryConfiguration(title: "Team PRs", query: "is:open is:pr user:YOUR_ORG"),
        QueryConfiguration(title: "Draft PRs", query: "is:open is:pr is:draft author:@me")
    ]
}

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        // Return to accessory app mode when window closes
        NSApp.setActivationPolicy(.accessory)
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var hasAPIKey: Bool = false
    @Published var isSettingsPresented: Bool = false
    @Published var queries: [QueryConfiguration] = []
    @Published var refreshInterval: TimeInterval = 300 // 5 minutes default
    
    private let keychainManager = KeychainManager.shared
    private var settingsWindow: NSWindow?
    private let queriesKey = "configuredQueries"
    private let refreshIntervalKey = "refreshInterval"
    
    // Testing support
    #if DEBUG
    var hasAPIKeyForTesting: Bool {
        get { hasAPIKey }
        set { hasAPIKey = newValue }
    }
    #endif
    
    private init() {
        checkForExistingAPIKey()
        loadQueries()
        loadRefreshInterval()
    }
    
    func checkForExistingAPIKey() {
        hasAPIKey = keychainManager.getAPIKey() != nil
    }
    
    func saveAPIKey(_ apiKey: String) -> Bool {
        let success = keychainManager.saveAPIKey(apiKey)
        if success {
            hasAPIKey = true
        }
        return success
    }
    
    func getAPIKey() -> String? {
        return keychainManager.getAPIKey()
    }
    
    func deleteAPIKey() -> Bool {
        let success = keychainManager.deleteAPIKey()
        if success {
            hasAPIKey = false
        }
        return success
    }
    
    func openSettings() {
        // For LSUIElement apps, we need to temporarily change activation policy
        NSApp.setActivationPolicy(.regular)
        
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "Preferences"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("PreferencesWindow")
            
            // Set delegate to handle window closing
            settingsWindow?.delegate = WindowDelegate.shared
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeFirstResponder(settingsWindow?.contentView)
    }
    
    func loadQueries() {
        if let data = UserDefaults.standard.data(forKey: queriesKey),
           let decodedQueries = try? JSONDecoder().decode([QueryConfiguration].self, from: data) {
            queries = decodedQueries
        } else {
            queries = [QueryConfiguration.defaultQuery]
            saveQueries()
        }
    }
    
    func saveQueries() {
        if let encoded = try? JSONEncoder().encode(queries) {
            UserDefaults.standard.set(encoded, forKey: queriesKey)
        }
    }
    
    func addQuery(_ query: QueryConfiguration) {
        queries.append(query)
        saveQueries()
    }
    
    func removeQuery(at index: Int) {
        guard index >= 0 && index < queries.count else { return }
        queries.remove(at: index)
        saveQueries()
    }
    
    func updateQuery(at index: Int, with query: QueryConfiguration) {
        guard index >= 0 && index < queries.count else { return }
        queries[index] = query
        saveQueries()
    }
    
    func loadRefreshInterval() {
        let stored = UserDefaults.standard.double(forKey: refreshIntervalKey)
        if stored > 0 {
            refreshInterval = stored
        } else {
            refreshInterval = 300 // 5 minutes default
            saveRefreshInterval()
        }
    }
    
    func saveRefreshInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: refreshIntervalKey)
    }
    
    func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        saveRefreshInterval()
    }
    
    static let refreshIntervalOptions: [(title: String, interval: TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("60 minutes", 3600)
    ]
}