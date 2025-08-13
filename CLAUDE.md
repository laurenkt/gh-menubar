# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS menu bar application for viewing and managing GitHub pull requests. The app is built using SwiftUI and targets macOS 13+.

### Core Features
- Query-based PR organization with customizable search filters
- Real-time PR status display with CI/CD check integration  
- Configurable PR display components with drag-and-drop editing
- Menu bar notification counts for pending actions
- Secure API key management via Keychain
- Auto-refresh with configurable intervals

## Development Commands

```bash
# Build the application
swift build

# Run the application
swift run

# Build for release
swift build -c release
```

## Project Structure

```
Sources/MenuBarApp/
├── App.swift                    # Main entry point with MenuBarExtra
├── PullRequestViewModel.swift   # Core data layer with async GitHub operations
├── GitHubAPIService.swift       # GitHub API client with comprehensive models
├── AppSettings.swift           # Settings management and query configuration
├── SettingsView.swift          # Complex settings UI with sidebar navigation
├── KeychainManager.swift       # Secure API key storage
└── Info.plist                 # App configuration (LSUIElement: true)

Tests/MenuBarAppTests/
├── SnapshotTests.swift         # SwiftUI snapshot testing
└── __Snapshots__/             # Baseline snapshot images
```

## Architecture

### Core Components

1. **MenuBarApp** (`App.swift`)
   - Main entry point using SwiftUI's `MenuBarExtra`
   - Menu bar integration with dynamic label based on pending actions
   - Uses `.menu` style for dropdown interface

2. **PullRequestViewModel** (`PullRequestViewModel.swift`)
   - ObservableObject managing PR data and state
   - Async GitHub API operations with TaskGroup concurrency
   - Auto-refresh timer with configurable intervals
   - Query-based result organization with `QueryResult` model

3. **GitHubGraphQLService** (`GitHubGraphQLService.swift`)
   - Primary GitHub API service using GraphQL for improved performance
   - Maintains same interface as legacy REST service for compatibility
   - Reduces API calls by ~75% through comprehensive single queries
   - Falls back to REST only for workflow jobs (GitHub API limitation)

4. **GitHubAPIService** (`GitHubAPIService.swift`)
   - Legacy REST API service kept for reference and fallback
   - Models: `GitHubPullRequest`, `GitHubCheckRun`, `GitHubUser`, etc.
   - Used by GraphQL service for workflow job details

5. **MinimalGraphQLClient** (`MinimalGraphQLClient.swift`)
   - Lightweight GraphQL client for GitHub API
   - Handles JSON serialization and HTTP communication
   - Error handling with proper GraphQL error parsing

6. **AppSettings** (`AppSettings.swift`)
   - Settings persistence via UserDefaults and Keychain
   - Query configuration management with `QueryConfiguration` model
   - Window management for LSUIElement apps
   - Legacy compatibility for display preferences

7. **SettingsView** (`SettingsView.swift`)
   - Modern sidebar navigation using `NavigationSplitView`
   - Drag-and-drop PR component editor with `HorizontalDragDropEditor`
   - Token validation with detailed access information display
   - Query management with suggestions and custom editor

8. **KeychainManager** (`KeychainManager.swift`)
   - Secure API key storage using Security framework
   - Standard keychain operations: save, retrieve, delete

### Key Patterns

- **MVVM Architecture**: ViewModels as ObservableObjects with Published properties
- **Async/Await**: Throughout data layer with proper error handling
- **Concurrent Operations**: TaskGroup for parallel API calls
- **Configuration-Driven UI**: Customizable PR display using `PRDisplayComponent` enum
- **Query System**: Flexible GitHub search integration with `QueryConfiguration`
- **Secure Storage**: API keys stored in system Keychain
- **Menu Bar Best Practices**: LSUIElement configuration, proper activation policy handling
- **GraphQL Integration**: Comprehensive single queries reduce API calls by ~75%

## GraphQL Query System

The app now uses GitHub's GraphQL API as the primary data source, with significant performance benefits.

### Query Architecture

**Main Query Types:**
1. **Token Validation Query**: Validates API tokens and fetches user/org data
2. **Pull Request Search Query**: Comprehensive query that fetches PRs with all associated data

**Key Files:**
- `MinimalGraphQLClient.swift`: Lightweight GraphQL client handling HTTP requests
- `GitHubGraphQLService.swift`: Service layer with embedded GraphQL queries
- `GraphQL/Queries.graphql`: Reference queries (actual queries are in Swift code)

### Modifying GraphQL Queries

When you need to add/modify data fetching:

**1. Update the GraphQL Query String**
Located in `GitHubGraphQLService.swift`:
```swift
let graphQLQuery = """
    query($searchQuery: String!) {
        search(query: $searchQuery, type: ISSUE, first: 50) {
            nodes {
                ... on PullRequest {
                    # Add new fields here
                    newField
                }
            }
        }
    }
    """
```

**2. Update the Response Model**
Add corresponding Swift types in the same file:
```swift
struct PullRequestSearchResponse: Codable {
    // Add new fields to match GraphQL response
}
```

**3. Update the Mapping Code**
Add mapping logic to convert GraphQL response to existing models:
```swift
// In mapToExistingModels function
pr.newProperty = prNode.newField
```

**4. Test with GraphQL Explorer**
Use GitHub's GraphQL explorer (https://docs.github.com/en/graphql/overview/explorer) to test queries before implementing.

### Performance Benefits

- **Before (REST)**: ~4-5 API calls per pull request
- **After (GraphQL)**: ~1-2 API calls per pull request
- **Hybrid Approach**: GraphQL for most data, REST only for workflow jobs (GitHub limitation)

### Error Handling

GraphQL errors are handled at multiple levels:
- HTTP errors (network issues, rate limits)  
- GraphQL query errors (syntax, permissions)
- Data mapping errors (response structure changes)

## Development Guidelines

### Making Changes

1. **Data Layer Updates**: Modify `PullRequestViewModel` or `GitHubGraphQLService`
   - Always maintain async/await patterns
   - Add proper error handling with user-friendly messages  
   - Test GraphQL queries using GitHub's GraphQL Explorer first
   - For new data fields, update query → response models → mapping code

2. **UI Changes**: Update SwiftUI views following existing patterns
   - Use ObservableObject bindings consistently
   - Follow iOS-style design patterns adapted for macOS
   - Test with different query configurations

3. **Settings Changes**: Update `AppSettings` and `SettingsView`
   - Maintain backward compatibility for stored preferences
   - Add migration logic for new configuration options
   - Update `QueryConfiguration` model as needed

4. **New GitHub API Integration**: Extend `GitHubGraphQLService`
   - Add new fields to GraphQL queries first (test in GraphQL Explorer)
   - Add corresponding fields to Swift response models
   - Update mapping logic to existing `GitHubPullRequest` models
   - Add appropriate tests via snapshot testing
   - Only use REST API if data is not available via GraphQL

### Testing

- Use SwiftUI snapshot testing for UI validation
- Test different API states (loading, error, success)
- Verify menu bar behavior in different macOS states
- Test query configuration edge cases

### Building & Distribution

- Target macOS 13+ for modern SwiftUI features
- LSUIElement: true for menu bar-only operation
- Consider notarization for distribution outside App Store