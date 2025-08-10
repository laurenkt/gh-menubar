import SwiftUI
import AppKit

enum PRDisplayComponent: String, CaseIterable, Codable, Identifiable {
    case statusSymbol = "status_symbol"
    case title = "title"
    case orgName = "org_name"
    case projectName = "project_name"
    case prNumber = "pr_number"
    case authorName = "author_name"
    case separator = "separator"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .statusSymbol: return "Status Symbol"
        case .title: return "Title"
        case .orgName: return "Organization"
        case .projectName: return "Project"
        case .prNumber: return "PR Number"
        case .authorName: return "Author"
        case .separator: return "Separator (–)"
        }
    }
    
    var exampleText: String {
        switch self {
        case .statusSymbol: return "✓"
        case .title: return "Fix login validation bug"
        case .orgName: return "acme-corp"
        case .projectName: return "mobile-app"
        case .prNumber: return "#1234"
        case .authorName: return "@johndoe"
        case .separator: return "–"
        }
    }
}

struct QueryConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var query: String
    
    // Component ordering (new drag & drop interface)
    var componentOrder: [PRDisplayComponent]
    
    // Legacy display preferences (for backward compatibility)
    var showOrgName: Bool
    var showProjectName: Bool
    var showPRNumber: Bool
    var showAuthorName: Bool
    
    // Menu bar count preferences
    var includeInFailingChecksCount: Bool
    var includeInPendingReviewsCount: Bool
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        query = try container.decode(String.self, forKey: .query)
        
        // Component order (new field)
        if let order = try container.decodeIfPresent([PRDisplayComponent].self, forKey: .componentOrder) {
            componentOrder = order
        } else {
            // Create default order based on legacy settings for migration
            var defaultOrder: [PRDisplayComponent] = [.statusSymbol, .title]
            let showOrgName = try container.decodeIfPresent(Bool.self, forKey: .showOrgName) ?? true
            let showProjectName = try container.decodeIfPresent(Bool.self, forKey: .showProjectName) ?? true
            let showPRNumber = try container.decodeIfPresent(Bool.self, forKey: .showPRNumber) ?? true
            let showAuthorName = try container.decodeIfPresent(Bool.self, forKey: .showAuthorName) ?? false
            
            if showOrgName { defaultOrder.append(.orgName) }
            if showProjectName { defaultOrder.append(.projectName) }
            if showPRNumber { defaultOrder.append(.prNumber) }
            if showAuthorName { defaultOrder.append(.authorName) }
            componentOrder = defaultOrder
        }
        
        // Legacy fields with defaults for backward compatibility
        showOrgName = try container.decodeIfPresent(Bool.self, forKey: .showOrgName) ?? true
        showProjectName = try container.decodeIfPresent(Bool.self, forKey: .showProjectName) ?? true
        showPRNumber = try container.decodeIfPresent(Bool.self, forKey: .showPRNumber) ?? true
        showAuthorName = try container.decodeIfPresent(Bool.self, forKey: .showAuthorName) ?? false
        includeInFailingChecksCount = try container.decodeIfPresent(Bool.self, forKey: .includeInFailingChecksCount) ?? true
        includeInPendingReviewsCount = try container.decodeIfPresent(Bool.self, forKey: .includeInPendingReviewsCount) ?? true
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, query
        case componentOrder
        case showOrgName, showProjectName, showPRNumber, showAuthorName
        case includeInFailingChecksCount, includeInPendingReviewsCount
    }
    
    init(title: String, query: String, 
         componentOrder: [PRDisplayComponent]? = nil,
         showOrgName: Bool = true,
         showProjectName: Bool = true,
         showPRNumber: Bool = true,
         showAuthorName: Bool = false,
         includeInFailingChecksCount: Bool = true,
         includeInPendingReviewsCount: Bool = true) {
        self.id = UUID()
        self.title = title
        self.query = query
        
        // Set default component order if not provided
        if let order = componentOrder {
            self.componentOrder = order
        } else {
            var defaultOrder: [PRDisplayComponent] = [.statusSymbol, .title]
            if showOrgName { defaultOrder.append(.orgName) }
            if showProjectName { defaultOrder.append(.projectName) }
            if showPRNumber { defaultOrder.append(.prNumber) }
            if showAuthorName { defaultOrder.append(.authorName) }
            self.componentOrder = defaultOrder
        }
        
        self.showOrgName = showOrgName
        self.showProjectName = showProjectName
        self.showPRNumber = showPRNumber
        self.showAuthorName = showAuthorName
        self.includeInFailingChecksCount = includeInFailingChecksCount
        self.includeInPendingReviewsCount = includeInPendingReviewsCount
    }
    
    mutating func update(
        title: String? = nil,
        query: String? = nil,
        componentOrder: [PRDisplayComponent]? = nil,
        showOrgName: Bool? = nil,
        showProjectName: Bool? = nil,
        showPRNumber: Bool? = nil,
        showAuthorName: Bool? = nil,
        includeInFailingChecksCount: Bool? = nil,
        includeInPendingReviewsCount: Bool? = nil
    ) {
        if let title = title { self.title = title }
        if let query = query { self.query = query }
        if let componentOrder = componentOrder { self.componentOrder = componentOrder }
        if let showOrgName = showOrgName { self.showOrgName = showOrgName }
        if let showProjectName = showProjectName { self.showProjectName = showProjectName }
        if let showPRNumber = showPRNumber { self.showPRNumber = showPRNumber }
        if let showAuthorName = showAuthorName { self.showAuthorName = showAuthorName }
        if let includeInFailingChecksCount = includeInFailingChecksCount { 
            self.includeInFailingChecksCount = includeInFailingChecksCount 
        }
        if let includeInPendingReviewsCount = includeInPendingReviewsCount { 
            self.includeInPendingReviewsCount = includeInPendingReviewsCount 
        }
    }
    
    func updated(
        title: String? = nil,
        query: String? = nil,
        componentOrder: [PRDisplayComponent]? = nil,
        showOrgName: Bool? = nil,
        showProjectName: Bool? = nil,
        showPRNumber: Bool? = nil,
        showAuthorName: Bool? = nil,
        includeInFailingChecksCount: Bool? = nil,
        includeInPendingReviewsCount: Bool? = nil
    ) -> QueryConfiguration {
        var copy = self
        copy.update(
            title: title,
            query: query,
            componentOrder: componentOrder,
            showOrgName: showOrgName,
            showProjectName: showProjectName,
            showPRNumber: showPRNumber,
            showAuthorName: showAuthorName,
            includeInFailingChecksCount: includeInFailingChecksCount,
            includeInPendingReviewsCount: includeInPendingReviewsCount
        )
        return copy
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