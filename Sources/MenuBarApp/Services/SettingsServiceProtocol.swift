import Foundation
import Combine

protocol SettingsServiceProtocol: ObservableObject {
    var hasAPIKey: Bool { get }
    var queries: [QueryConfiguration] { get set }
    var refreshInterval: Double { get set }
    var useGraphQL: Bool { get set }
    var appUpdateInterval: Double { get set }
    
    func openSettings()
    func saveQueries()
    func resetToDefaults()
    
    // For testing
    var hasAPIKeyForTesting: Bool { get set }
}