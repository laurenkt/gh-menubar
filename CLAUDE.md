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

3. **GitHubAPIService** (`GitHubAPIService.swift`)
   - Centralized GitHub API client with comprehensive error handling
   - Models: `GitHubPullRequest`, `GitHubCheckRun`, `GitHubUser`, etc.
   - Token validation with repository/organization access verification
   - Concurrent check run fetching for PR status

4. **AppSettings** (`AppSettings.swift`)
   - Settings persistence via UserDefaults and Keychain
   - Query configuration management with `QueryConfiguration` model
   - Window management for LSUIElement apps
   - Legacy compatibility for display preferences

5. **SettingsView** (`SettingsView.swift`)
   - Modern sidebar navigation using `NavigationSplitView`
   - Drag-and-drop PR component editor with `HorizontalDragDropEditor`
   - Token validation with detailed access information display
   - Query management with suggestions and custom editor

6. **KeychainManager** (`KeychainManager.swift`)
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

## Development Guidelines

### Making Changes

1. **Data Layer Updates**: Modify `PullRequestViewModel` or `GitHubAPIService`
   - Always maintain async/await patterns
   - Add proper error handling with user-friendly messages
   - Test API changes with token validation flow

2. **UI Changes**: Update SwiftUI views following existing patterns
   - Use ObservableObject bindings consistently
   - Follow iOS-style design patterns adapted for macOS
   - Test with different query configurations

3. **Settings Changes**: Update `AppSettings` and `SettingsView`
   - Maintain backward compatibility for stored preferences
   - Add migration logic for new configuration options
   - Update `QueryConfiguration` model as needed

4. **New GitHub API Integration**: Extend `GitHubAPIService`
   - Add new models to the existing data types
   - Follow existing error handling patterns
   - Add appropriate tests via snapshot testing

### Testing

- Use SwiftUI snapshot testing for UI validation
- Test different API states (loading, error, success)
- Verify menu bar behavior in different macOS states
- Test query configuration edge cases

### Building & Distribution

- Target macOS 13+ for modern SwiftUI features
- LSUIElement: true for menu bar-only operation
- Consider notarization for distribution outside App Store