# Contributing to DocBuilder Feature

## Making Changes to the Feature

When making any changes to the devcontainer feature, follow this checklist:

### ⚠️ CRITICAL: Always Bump Version

**Before pushing any changes to the feature**, you MUST update the version in `features/docbuilder/devcontainer-feature.json`:

```json
{
  "version": "X.Y.Z"  // Increment this!
}
```

**Why?** The OCI registry will skip publishing if the version already exists, even if the code has changed. Your changes won't be published unless you bump the version.

### Version Bumping Guidelines

- **Patch** (0.0.X): Bug fixes, minor changes
- **Minor** (0.X.0): New features, significant improvements
- **Major** (X.0.0): Breaking changes

### Pre-Push Checklist

- [ ] Update version in `features/docbuilder/devcontainer-feature.json`
- [ ] Test changes locally if possible
- [ ] Update README.md if changing behavior or options
- [ ] Commit with descriptive message
- [ ] Push to trigger CI/CD
- [ ] Wait for GitHub Actions to complete
- [ ] Verify publish succeeded (check for version number, not just "skipping")

## Testing Changes

Since local feature paths don't work in this setup (features directory would need to be in .devcontainer), testing requires:

1. Publishing to the registry
2. Rebuilding the devcontainer

## Publishing Process

The GitHub Actions workflow automatically:

1. Checks out the code
2. Publishes the feature to `ghcr.io/inful/docbuilder-feature/docbuilder`
3. Tags with version and `latest`

Monitor the workflow at: https://github.com/inful/docbuilder-feature/actions
