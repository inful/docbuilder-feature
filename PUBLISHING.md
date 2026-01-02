# DocBuilder Feature - Publishing Guide

This guide explains how the DocBuilder feature is published to the GitHub Container Registry (ghcr.io).

## How It Works

This feature bundles the binaries directly in the OCI registry image to avoid network/proxy issues during container builds:

1. CI downloads the binaries for both amd64 and arm64 architectures
2. Binaries are placed in `features/docbuilder/bin/{amd64,arm64}/`
3. The feature (including binaries) is published to the OCI registry
4. During container build, binaries are copied from the feature to `/usr/local/bin`

**Note:** Binaries are NOT committed to git - they are downloaded by CI before publishing.

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

# Download the binaries first
cd features/docbuilder
chmod +x download-binaries.sh
./download-binaries.sh 0.1.46 0.154.1  # Use desired versions
cd ../..

# Publish the feature (includes the downloaded binaries)
devcontainer features publish \
  --registry ghcr.io \
  --namespace inful \
  ./features/docbuilder
```

## Updating Binary Versions

To update the default binary versions:

1. Update the `default` values in `features/docbuilder/devcontainer-feature.json`
2. Test locally by running `./features/docbuilder/download-binaries.sh`
3. Commit and push - CI will automatically download the new versions and publish

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
