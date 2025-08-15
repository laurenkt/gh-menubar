import XCTest
@testable import MenuBarApp

final class KeychainServiceTests: XCTestCase {
    var keychainService: MockKeychainService!
    
    override func setUp() {
        super.setUp()
        keychainService = MockKeychainService()
    }
    
    override func tearDown() {
        keychainService = nil
        super.tearDown()
    }
    
    func testSaveAndLoadData() {
        // Given: Some test data
        let testData = "test-value".data(using: .utf8)!
        let testKey = "test-key"
        
        // When: Saving and loading data
        let saveSuccess = keychainService.save(key: testKey, data: testData)
        let loadedData = keychainService.load(key: testKey)
        
        // Then: Data should be saved and loaded correctly
        XCTAssertTrue(saveSuccess)
        XCTAssertEqual(loadedData, testData)
    }
    
    func testDeleteData() {
        // Given: Some saved data
        let testData = "test-value".data(using: .utf8)!
        let testKey = "test-key"
        keychainService.save(key: testKey, data: testData)
        
        // When: Deleting the data
        let deleteSuccess = keychainService.delete(key: testKey)
        let loadedData = keychainService.load(key: testKey)
        
        // Then: Data should be deleted
        XCTAssertTrue(deleteSuccess)
        XCTAssertNil(loadedData)
    }
    
    func testSaveAndLoadAPIKey() {
        // Given: An API key
        let testAPIKey = "github_pat_test_token"
        
        // When: Saving and loading the API key
        let saveSuccess = keychainService.saveAPIKey(testAPIKey)
        let loadedAPIKey = keychainService.loadAPIKey()
        
        // Then: API key should be saved and loaded correctly
        XCTAssertTrue(saveSuccess)
        XCTAssertEqual(loadedAPIKey, testAPIKey)
    }
    
    func testDeleteAPIKey() {
        // Given: A saved API key
        let testAPIKey = "github_pat_test_token"
        keychainService.saveAPIKey(testAPIKey)
        
        // When: Deleting the API key
        let deleteSuccess = keychainService.deleteAPIKey()
        let loadedAPIKey = keychainService.loadAPIKey()
        
        // Then: API key should be deleted
        XCTAssertTrue(deleteSuccess)
        XCTAssertNil(loadedAPIKey)
    }
    
    func testLoadNonExistentData() {
        // When: Loading data that doesn't exist
        let loadedData = keychainService.load(key: "non-existent-key")
        
        // Then: Should return nil
        XCTAssertNil(loadedData)
    }
    
    func testOverwriteExistingData() {
        // Given: Existing data
        let testKey = "test-key"
        let originalData = "original-value".data(using: .utf8)!
        let newData = "new-value".data(using: .utf8)!
        
        keychainService.save(key: testKey, data: originalData)
        
        // When: Saving new data with the same key
        let saveSuccess = keychainService.save(key: testKey, data: newData)
        let loadedData = keychainService.load(key: testKey)
        
        // Then: Should overwrite with new data
        XCTAssertTrue(saveSuccess)
        XCTAssertEqual(loadedData, newData)
    }
}