#!/bin/bash
#
# setup-hooks.sh
# Installs Swift code quality tools and pre-commit hooks.
#
# This script is idempotent - safe to run multiple times.
#

set -e

echo "=== Nathaniel Code Quality Setup ==="
echo

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is required but not installed."
    echo "Install from: https://brew.sh"
    exit 1
fi

# Install SwiftLint
if ! command -v swiftlint &> /dev/null; then
    echo "Installing SwiftLint..."
    brew install swiftlint
else
    echo "SwiftLint already installed: $(swiftlint version)"
fi

# Install SwiftFormat
if ! command -v swiftformat &> /dev/null; then
    echo "Installing SwiftFormat..."
    brew install swiftformat
else
    echo "SwiftFormat already installed: $(swiftformat --version)"
fi

# Install pre-commit
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."
    brew install pre-commit
else
    echo "pre-commit already installed: $(pre-commit --version)"
fi

echo

# Install git hooks
echo "Installing git hooks..."
pre-commit install

echo
echo "=== Setup Complete ==="
echo
echo "The following hooks are now active:"
echo "  - SwiftFormat: Auto-formats Swift code on commit"
echo "  - SwiftLint: Checks for code quality issues"
echo
echo "To bypass hooks temporarily: git commit --no-verify"
echo "To run manually:"
echo "  swiftformat .        # Format all Swift files"
echo "  swiftlint            # Lint all Swift files"
echo "  swiftlint --fix      # Auto-fix some lint issues"
echo
