# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS menu bar application for viewing and managing GitHub pull requests. The app is built using SwiftUI and targets macOS 13+.

### Intended Features
- View all open PRs for the authenticated user
- Display PR status with passing/failing CI jobs
- Show PRs requiring review from the user
- Support custom filter queries for team PRs or other criteria

## Development Commands

```bash
# Build the application
swift build

# Run the application
swift run

# Build for release
swift build -c release
```

## Architecture

The app uses SwiftUI's `MenuBarExtra` API for menu bar integration. Key architectural considerations:

- **App Entry Point**: `Sources/MenuBarApp/App.swift` contains the main app structure using `@main` attribute
- **Menu Bar Integration**: Uses `MenuBarExtra` scene type for native macOS menu bar support
- **Info.plist Configuration**: LSUIElement is set to true to run as a menu bar-only app (no dock icon)

## Development Principles

- Prioritize clean code, maintainability, and readability
- Use modern SwiftUI patterns and best practices for macOS development
- Follow Apple's Human Interface Guidelines for menu bar apps
- Implement proper error handling and user feedback mechanisms