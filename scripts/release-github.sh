#!/bin/bash

# GitHub Release Script for VS Code Jest Runner Extension
# This script builds the extension and creates a GitHub release with the .vsix package

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get version from package.json
VERSION=$(node -p "require('./package.json').version")
PACKAGE_NAME="vscode-jest-runner-${VERSION}.vsix"

echo -e "${BLUE}🚀 Starting GitHub release process for version ${VERSION}${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if GitHub CLI is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI is not authenticated${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Parse command line arguments
DRAFT_MODE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --draft)
            DRAFT_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --draft     Create a draft release"
            echo "  --dry-run   Show what would be done without executing"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
    echo "Would create release: v${VERSION}"
    echo "Would build extension (validate first)"
    echo "Would package extension: ${PACKAGE_NAME}"
    echo "Would commit and push changes (only after successful build)"
    if [ "$DRAFT_MODE" = true ]; then
        echo "Would create DRAFT GitHub release with tag: v${VERSION}"
    else
        echo "Would create GitHub release with tag: v${VERSION}"
    fi
    echo "Would upload ${PACKAGE_NAME} to the release"
    exit 0
fi

# Check if tag already exists
if git tag -l | grep -q "^v${VERSION}$"; then
    echo -e "${RED}❌ Error: Tag v${VERSION} already exists${NC}"
    echo "Please update the version in package.json or delete the existing tag"
    exit 1
fi

# Check if release already exists on GitHub
if gh release view "v${VERSION}" &> /dev/null; then
    echo -e "${RED}❌ Error: Release v${VERSION} already exists on GitHub${NC}"
    exit 1
fi

# Build the extension first (before any git operations)
echo -e "${BLUE}🔨 Building extension...${NC}"
if ! npm run vscode:prepublish; then
    echo -e "${RED}❌ Error: Extension build failed${NC}"
    echo -e "${RED}🛑 Aborting release process${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Extension built successfully${NC}"

# Package the extension
echo -e "${BLUE}📦 Packaging extension...${NC}"
if ! echo "y" | npx vsce package; then
    echo -e "${RED}❌ Error: Extension packaging failed${NC}"
    echo -e "${RED}🛑 Aborting release process${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Extension packaged: ${PACKAGE_NAME}${NC}"

# Verify the package exists
if [ ! -f "${PACKAGE_NAME}" ]; then
    echo -e "${RED}❌ Error: Package file ${PACKAGE_NAME} not found${NC}"
    echo -e "${RED}🛑 Aborting release process${NC}"
    exit 1
fi

# Now that build is successful, commit and push changes
echo -e "${BLUE}📝 Committing and pushing changes...${NC}"
git add -A
if git commit -m "Release v${VERSION}"; then
    echo -e "${GREEN}✅ Changes committed${NC}"
else
    echo -e "${YELLOW}⚠️  No changes to commit${NC}"
fi

echo -e "${BLUE}📤 Pushing to GitHub...${NC}"
if ! git push; then
    echo -e "${RED}❌ Error: Failed to push to GitHub${NC}"
    echo -e "${RED}🛑 Aborting release process${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Changes pushed to GitHub${NC}"

# Create GitHub release
echo -e "${BLUE}🎉 Creating GitHub release...${NC}"
RELEASE_ARGS="v${VERSION} --title \"Release v${VERSION}\" --notes \"Release v${VERSION}\""

if [ "$DRAFT_MODE" = true ]; then
    RELEASE_ARGS="${RELEASE_ARGS} --draft"
    echo -e "${YELLOW}📋 Creating draft release...${NC}"
else
    echo -e "${BLUE}🚀 Creating public release...${NC}"
fi

if gh release create $RELEASE_ARGS; then
    echo -e "${GREEN}✅ GitHub release created${NC}"
else
    echo -e "${RED}❌ Error: Failed to create GitHub release${NC}"
    exit 1
fi

# Upload the package
echo -e "${BLUE}⬆️  Uploading package to release...${NC}"
if gh release upload "v${VERSION}" "${PACKAGE_NAME}"; then
    echo -e "${GREEN}✅ Package uploaded successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to upload package${NC}"
    exit 1
fi

# Final success message
if [ "$DRAFT_MODE" = true ]; then
    echo -e "${GREEN}🎉 Draft release v${VERSION} created successfully!${NC}"
    echo -e "${BLUE}📋 Review and publish at: $(gh release view v${VERSION} --web --json url --jq .url)${NC}"
else
    echo -e "${GREEN}🎉 Release v${VERSION} created and published successfully!${NC}"
    echo -e "${BLUE}🔗 View release at: $(gh release view v${VERSION} --web --json url --jq .url)${NC}"
fi

echo -e "${GREEN}✅ Process completed successfully!${NC}"
