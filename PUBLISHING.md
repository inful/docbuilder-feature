# DocBuilder Feature - Publishing Guide

This guide explains how the DocBuilder feature is published to the GitHub Container Registry (ghcr.io).

## Automated Publishing

The feature is automatically published to `ghcr.io/inful/docbuilder-feature/docbuilder` when:
- Code is pushed to the `main` branch
- Changes are made to the `features/docbuilder/` directory or the workflow file itself
- A workflow is manually triggered

## Manual Publishing

To manually publish the feature:

```bash
# Install Dev Containers CLI if not already installed
npm install -g @devcontainers/cli

# Authenticate with GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin

# Publish the feature
devcontainer features publish \
  --registry ghcr.io \
  --namespace inful \
  ./features/docbuilder
```

## Using the Published Feature

Once published, reference the feature in your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.1.46",
            "hugoVersion": "0.154.1"
        }
    }
}
```

Or with a specific version tag:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:0.1.0": {}
    }
}
```

## Release Process

To create a new release:

1. Update the `version` field in `features/docbuilder/devcontainer-feature.json`
2. Commit and push to `main` branch
3. The GitHub Actions workflow will automatically publish the feature
4. Create a GitHub release tag matching the version

## Troubleshooting

### Authentication Failures
Ensure your `GITHUB_TOKEN` has `write:packages` permission and is set in the GitHub Actions secrets.

### Publishing Errors
Check the workflow logs in the Actions tab for detailed error messages.

### Testing Locally
Before publishing, you can test the feature locally:

```bash
# Using the local path
devcontainer up --workspace-folder . --config .devcontainer/devcontainer.json

# Or with a test devcontainer.json pointing to the feature registry
```
