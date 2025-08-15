import XCTest
@testable import MenuBarApp

final class SettingsServiceTests: XCTestCase {
    var settingsService: MockSettingsService!
    
    override func setUp() {
        super.setUp()
        settingsService = MockSettingsService()
    }
    
    override func tearDown() {
        settingsService = nil
        super.tearDown()
    }
    
    func testInitialSettings() {
        // Then: Should have default values
        XCTAssertFalse(settingsService.hasAPIKey)
        XCTAssertTrue(settingsService.queries.isEmpty)
        XCTAssertEqual(settingsService.refreshInterval, 300)
        XCTAssertTrue(settingsService.useGraphQL)
        XCTAssertEqual(settingsService.appUpdateInterval, 1.0)
    }
    
    func testAddQuery() {
        // Given: A test query configuration
        let testQuery = QueryConfiguration(
            title: "Test Query",
            query: "is:open is:pr author:@me"
        )
        
        // When: Adding the query
        settingsService.queries.append(testQuery)
        settingsService.saveQueries()
        
        // Then: Query should be added
        XCTAssertEqual(settingsService.queries.count, 1)
        XCTAssertEqual(settingsService.queries.first?.title, "Test Query")
        XCTAssertEqual(settingsService.queries.first?.query, "is:open is:pr author:@me")
    }
    
    func testUpdateRefreshInterval() {
        // Given: A new refresh interval
        let newInterval: Double = 600
        
        // When: Updating the refresh interval
        settingsService.refreshInterval = newInterval
        
        // Then: Refresh interval should be updated
        XCTAssertEqual(settingsService.refreshInterval, newInterval)
    }
    
    func testResetToDefaults() {
        // Given: Modified settings
        settingsService.refreshInterval = 600
        settingsService.useGraphQL = false
        settingsService.appUpdateInterval = 2.0
        let testQuery = QueryConfiguration(title: "Test", query: "is:open")
        settingsService.queries = [testQuery]
        
        // When: Resetting to defaults
        settingsService.resetToDefaults()
        
        // Then: Should return to default values
        XCTAssertEqual(settingsService.refreshInterval, 300)
        XCTAssertTrue(settingsService.useGraphQL)
        XCTAssertEqual(settingsService.appUpdateInterval, 1.0)
        XCTAssertTrue(settingsService.queries.isEmpty)
    }
    
    func testToggleGraphQLUsage() {
        // Given: GraphQL is enabled by default
        XCTAssertTrue(settingsService.useGraphQL)
        
        // When: Disabling GraphQL
        settingsService.useGraphQL = false
        
        // Then: Should be disabled
        XCTAssertFalse(settingsService.useGraphQL)
        
        // When: Re-enabling GraphQL
        settingsService.useGraphQL = true
        
        // Then: Should be enabled again
        XCTAssertTrue(settingsService.useGraphQL)
    }
    
    func testHasAPIKeyForTesting() {
        // Given: Initially no API key
        XCTAssertFalse(settingsService.hasAPIKeyForTesting)
        
        // When: Setting API key for testing
        settingsService.hasAPIKeyForTesting = true
        
        // Then: Should reflect the change
        XCTAssertTrue(settingsService.hasAPIKeyForTesting)
        XCTAssertTrue(settingsService.hasAPIKey) // Should also update the main property
    }
    
    func testQueryConfigurationProperties() {
        // Given: A query configuration with various settings
        let queryConfig = QueryConfiguration(
            title: "My PRs",
            query: "is:open is:pr author:@me",
            displayLayout: [
                .component(.statusSymbol),
                .text(" "),
                .component(.title),
                .text(" - "),
                .component(.orgName),
                .text("/"),
                .component(.projectName)
            ],
            includeInFailingChecksCount: true,
            includeInPendingReviewsCount: false
        )
        
        // When: Adding the query
        settingsService.queries = [queryConfig]
        
        // Then: All properties should be preserved
        let savedQuery = settingsService.queries.first!
        XCTAssertEqual(savedQuery.title, "My PRs")
        XCTAssertEqual(savedQuery.query, "is:open is:pr author:@me")
        XCTAssertTrue(savedQuery.includeInFailingChecksCount)
        XCTAssertFalse(savedQuery.includeInPendingReviewsCount)
        XCTAssertEqual(savedQuery.displayLayout.count, 7)
    }
}