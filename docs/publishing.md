# DocBuilder Feature - Publishing Guide

This guide explains how the DocBuilder feature is published to the GitHub Container Registry (ghcr.io).

## How It Works

The feature uses a dynamic download approach where binaries are fetched during container build:

1. The feature code (install.sh, devcontainer-feature.json, etc.) is published to the OCI registry
2. When a devcontainer is built, the install.sh script runs and:
   - Downloads Go from official Go distribution
   - Downloads docbuilder from GitHub releases
   - Downloads Hugo Extended from GitHub releases
   - Installs binaries to `/usr/local/bin`
   - Configures auto-preview if enabled

**Benefits:**
- No large binaries stored in git or OCI registry
- Version checking skips redundant downloads on rebuild
- Supports proxy configuration for corporate networks
- Always fetches the exact version requested

## Automated Publishing

The feature is automatically published to `ghcr.io/inful/docbuilder-feature/docbuilder` when:
- Code is pushed to the `main` branch
- Changes are made to the `features/docbuilder/` directory or `.github/workflows/publish-feature.yml`
- A workflow is manually triggered via GitHub Actions

The GitHub Actions workflow:
1. Checks out the repository
2. Uses the official `devcontainers/action` to publish
3. Tags the feature with the version from `devcontainer-feature.json`
4. Also tags with `latest`

## Manual Publishing

To manually publish the feature:

```bash
# Install Dev Containers CLI if not already installed
npm install -g @devcontainers/cli

# Authenticate with GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Publish the feature
devcontainer features publish \
  --registry ghcr.io \
  --namespace inful/docbuilder-feature \
  ./features
```

Note: No need to download binaries before publishing - they're downloaded during container build.

## Updating Binary Versions

To update the default binary versions:

1. Update the `default` values in `features/docbuilder/devcontainer-feature.json`:
   - `docbuilderVersion`
   - `hugoVersion`
2. **Important:** Bump the `version` field (see Release Process below)
3. Test locally if possible
4. Commit and push - CI will automatically publish
5. Users will get the new defaults when they rebuild with the new version

## Using the Published Feature

Once published, reference the feature in your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.1.46",
            "hugoVersion": "0.154.1",
            "autoPreview": true,
            "docsDir": "docs",
            "previewPort": "1316"
        }
    },
    "forwardPorts": [1316, 1317, 1318, 1319]
}
```

Or with a specific version tag:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:0.3.5": {}
    }
}
```

Available options:
- `docbuilderVersion`: Version to install (default: "0.1.46")
- `hugoVersion`: Hugo version (default: "0.154.1")
- `autoPreview`: Auto-start preview server (default: true)
- `docsDir`: Documentation directory (default: "docs")
- `previewPort`: Preview server port (default: "1316")
- `verbose`: Verbose output (default: false)
- `httpProxy`, `httpsProxy`, `noProxy`: Proxy configuration

## Release Process

**⚠️ CRITICAL: Always bump the version before pushing changes!**

The OCI registry will skip publishing if the version already exists, even if the code has changed.

To create a new release:

1. **Update the `version` field in `features/docbuilder/devcontainer-feature.json`**
   - Patch (0.0.X): Bug fixes, minor changes
   - Minor (0.X.0): New features, significant improvements
   - Major (X.0.0): Breaking changes

2. Commit with a conventional commit message:
   ```bash
   git commit -m "feat: add new feature" # or fix:, docs:, chore:, etc.
   ```

3. Push to `main` branch:
   ```bash
   git push origin main
   ```

4. Monitor the GitHub Actions workflow to ensure publish succeeds

5. (Optional) Create a GitHub release tag matching the version

## Troubleshooting

### Authentication Failures
Ensure your `GITHUB_TOKEN` has `write:packages` permission and is set in the GitHub Actions secrets or repository settings.

### Publishing Errors
- Check the workflow logs in the Actions tab for detailed error messages
- Verify the version was bumped if making changes
- Check if the version already exists in the registry

### Download Failures During Container Build
If binaries fail to download during container build:
- Check network connectivity
- Configure proxy settings if behind a corporate firewall:
  ```json
  {
      "features": {
          "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
              "httpProxy": "${localEnv:HTTP_PROXY}",
              "httpsProxy": "${localEnv:HTTPS_PROXY}"
          }
      }
  }
  ```
- Check the installation logs in the devcontainer build output

### Version Check Issues
The feature checks if the correct versions are already installed to skip downloads. If you're having issues:
- Rebuild the container from scratch
- Check `/tmp/docbuilder-preview.log` for preview server issues
- Verify installed versions:
  ```bash
  docbuilder --version
  hugo version
  go version
  ```

### Testing Locally
Test the feature before publishing by building the devcontainer in this repository (it uses the local feature).
