#!/bin/bash
set -e

# CodeMie Code Release Script
# Simple script to automate releases following KISS principles

DRY_RUN=false
VERSION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo "Usage: $0 [VERSION] [--dry-run]"
            echo "Examples:"
            echo "  $0 0.0.3        # Release version 0.0.3"
            echo "  $0 --dry-run    # Preview next patch release"
            exit 0 ;;
        *) VERSION="$1"; shift ;;
    esac
done

# Get current version
CURRENT=$(grep '"version"' package.json | sed 's/.*"version": "\(.*\)".*/\1/')
echo "Current version: $CURRENT"

# Determine target version
if [[ -z "$VERSION" ]]; then
    # Auto-increment patch version
    IFS='.' read -r major minor patch <<< "$CURRENT"
    VERSION="$major.$minor.$((patch + 1))"
    echo "Auto-incrementing to: $VERSION"
fi

echo "Target version: $VERSION"

# Pre-flight checks
echo ""
echo "🔍 Pre-flight checks:"

# Check git status
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Working directory has uncommitted changes"
    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
else
    echo "✅ Working directory is clean"
fi

# Check if version tag exists
if git tag -l "v$VERSION" | grep -q "v$VERSION"; then
    echo "⚠️  Tag v$VERSION already exists"
    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
else
    echo "✅ Tag v$VERSION does not exist"
fi

# Show what will be done
echo ""
echo "📋 Actions that will be performed:"
echo "1. Update package.json version to $VERSION"
echo "2. Commit version bump"
echo "3. Create git tag v$VERSION"
echo "4. Push commit and tag to origin"
if command -v gh >/dev/null 2>&1; then
    echo "5. Create GitHub Release (if gh CLI available)"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "🔍 DRY RUN - No changes will be made"
    exit 0
fi

echo ""
read -p "❓ Proceed with release? (y/N): " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# Execute release
echo ""
echo "🚀 Executing release..."

# Update version in package.json and package-lock.json
echo "📝 Updating package versions..."
npm version "$VERSION" --no-git-tag-version

# Commit changes
echo "💾 Committing version bump..."
git add package.json package-lock.json
git commit -m "chore: bump version to $VERSION

🤖 Generated with release script"

# Create tag
echo "🏷️  Creating tag v$VERSION..."
git tag -a "v$VERSION" -m "Release version $VERSION"

# Push to origin
echo "📤 Pushing to origin..."
git push origin main
git push origin "v$VERSION"

# Create GitHub release if gh CLI is available
if command -v gh >/dev/null 2>&1; then
    echo "🐱 Creating GitHub Release..."

    # Generate simple release notes
    LAST_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
    if [[ -n "$LAST_TAG" ]]; then
        COMMITS=$(git log "$LAST_TAG..HEAD" --oneline --no-merges | wc -l)
        RANGE="$LAST_TAG..v$VERSION"
    else
        COMMITS=$(git rev-list --count HEAD)
        RANGE="v$VERSION"
    fi

    # Create release notes
    cat > /tmp/release-notes.md << EOF
## What's Changed

This release includes $COMMITS commits with improvements and updates.

### Recent Changes:
$(git log --oneline --no-merges -10 ${LAST_TAG:+$LAST_TAG..HEAD} | sed 's/^/- /')

**Full Changelog**: https://github.com/EPMCDME/codemie-ai/compare/${LAST_TAG:-initial}...v$VERSION
EOF

    gh release create "v$VERSION" \
        --title "Release v$VERSION" \
        --notes-file /tmp/release-notes.md \
        --latest

    rm -f /tmp/release-notes.md
    echo "✅ GitHub Release created"
else
    echo "⚠️  GitHub CLI not available - create release manually at:"
    echo "   https://github.com/EPMCDME/codemie-ai/releases/new?tag=v$VERSION"
fi

echo ""
echo "🎉 Release v$VERSION completed successfully!"
echo ""
echo "📦 Next steps:"
echo "• Monitor GitHub Actions for npm publish: https://github.com/EPMCDME/codemie-ai/actions"
echo "• Package will be available: npm install @codemieai/code@$VERSION"
echo "• View release: https://github.com/EPMCDME/codemie-ai/releases/tag/v$VERSION"