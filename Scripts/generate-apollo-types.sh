#!/bin/bash

# Script to generate Apollo GraphQL types
# Requires: apollo-ios-cli installed via SPM

set -e

echo "Generating Apollo GraphQL types..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required to download GitHub's GraphQL schema"
    echo "Please set it with: export GITHUB_TOKEN=your_github_token"
    exit 1
fi

# Build the project to ensure apollo-ios-cli is available
echo "Building project to ensure apollo-ios-cli is available..."
swift build

# Find the apollo-ios-cli executable
APOLLO_CLI=$(find .build -name "apollo-ios-cli" -type f | head -n 1)

if [ -z "$APOLLO_CLI" ]; then
    echo "Error: apollo-ios-cli not found. Please run 'swift build' first."
    exit 1
fi

echo "Found apollo-ios-cli at: $APOLLO_CLI"

# Download the schema
echo "Downloading GitHub GraphQL schema..."
$APOLLO_CLI generate schema-download

# Generate Swift types
echo "Generating Swift types..."
$APOLLO_CLI generate

echo "Apollo types generated successfully!"
echo ""
echo "Generated files:"
find Sources/MenuBarApp/GraphQL/Generated -name "*.swift" | head -20

echo ""
echo "Next steps:"
echo "1. Build the project: swift build"
echo "2. The GraphQL types are now available in your project"