import Foundation

protocol KeychainServiceProtocol {
    func save(key: String, data: Data) -> Bool
    func load(key: String) -> Data?
    func delete(key: String) -> Bool
    
    // Convenience methods for API key
    func saveAPIKey(_ apiKey: String) -> Bool
    func loadAPIKey() -> String?
    func deleteAPIKey() -> Bool
}