# Snapshot Testing

This project uses snapshot testing to help detect visual regressions in the SwiftUI views. Snapshot tests capture images of the UI components and compare them against reference images.

## Running Snapshot Tests

To run the snapshot tests:

```bash
swift test
```

## Recording New Snapshots

When you make changes to the UI or add new tests, you'll need to record new snapshots:

1. Set `isRecording = true` in the test setup in `SnapshotTests.swift`
2. Run the tests: `swift test`
3. The tests will fail but generate new reference images
4. Set `isRecording = false` to return to normal testing mode
5. Run the tests again to verify they pass

## Test Coverage

The snapshot tests cover:

- **MenuBarExtraView**: Main menu bar content in both states (with/without API key)
- **SettingsView**: Settings/preferences window
- **TokenValidationResultView**: Different states of GitHub token validation (loading, valid, invalid)

## Snapshot Storage

Reference snapshot images are stored in the `Tests/MenuBarAppTests/__Snapshots__/` directory and should be committed to version control to enable visual regression detection in CI/PR workflows.

## Benefits

- **Visual Regression Detection**: Automatically catch unintended visual changes
- **PR Review**: See visual diffs in pull requests 
- **Confidence**: Ensure UI changes are intentional
- **Documentation**: Snapshots serve as visual documentation of the UI states