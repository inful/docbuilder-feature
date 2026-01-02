# DocBuilder and Hugo Extended

This is a DevContainer feature that installs [docbuilder](https://github.com/inful/docbuilder), [Hugo Extended](https://github.com/gohugoio/hugo), and Go binaries into a development container.

## Contents

- Installs `docbuilder` binary
- Installs `hugo` (extended edition) binary
- Installs `go` binary (required by Hugo for module management)
- Configures automatic preview server startup (optional)

## Options

### `docbuilderVersion` (default: `0.1.46`)

The version of docbuilder to install. Can be set to any released version or `latest`.

### `hugoVersion` (default: `0.154.1`)

The version of Hugo Extended to install. Can be set to any released version or `latest`.

### `autoPreview` (default: `true`)

Automatically start the docbuilder preview server when the container starts.

### `docsDir` (default: `"docs"`)

Directory containing documentation source files for docbuilder preview. The directory will be created if it doesn't exist.

### `previewPort` (default: `"1316"`)

Port for the docbuilder preview server.

### `verbose` (default: `false`)

Enable verbose output for docbuilder preview.

## Supported Architectures

- `linux/amd64`
- `linux/arm64`

## Usage

### Default Installation

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {}
    }
}
```

This will install:

- Go 1.23.4
- docbuilder v0.1.46
- Hugo Extended v0.154.1
- Auto-start preview server on container startup

### Port Forwarding

To access the docbuilder preview server, add port forwarding to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {}
    },
    "forwardPorts": [1316, 1317, 1318, 1319],
    "portsAttributes": {
        "1316": {
            "label": "DocBuilder Preview",
            "onAutoForward": "notify"
        },
        "1317": {
            "label": "DocBuilder Webhooks",
            "onAutoForward": "silent"
        },
        "1318": {
            "label": "DocBuilder Admin",
            "onAutoForward": "silent"
        },
        "1319": {
            "label": "DocBuilder LiveReload",
            "onAutoForward": "silent"
        }
    }
}
```

The ports used by docbuilder:
- **1316**: Preview server (main web interface)
- **1317**: Webhook server
- **1318**: Admin interface
- **1319**: LiveReload server

### Custom Versions and Options

To use specific versions and configure preview options:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.1.45",
            "hugoVersion": "0.153.0",
            "autoPreview": true,
            "docsDir": "documentation",
            "previewPort": "8080",
            "verbose": false
        }
    }
}
```

### Disable Auto-Preview

To disable automatic preview server startup:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "autoPreview": false
        }
    }
}
```

You can then manually start the preview with:

```bash
docbuilder preview
```

### Using Latest Versions

To always use the latest available versions:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "latest",
            "hugoVersion": "latest"
        }
    }
}
```

### Using with a Proxy

If you're behind a corporate proxy, you can configure proxy settings:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "httpProxy": "${localEnv:HTTP_PROXY}",
            "httpsProxy": "${localEnv:HTTPS_PROXY}",
            "noProxy": "${localEnv:NO_PROXY}"
        }
    }
}
```

The feature will use these proxy settings when downloading the binaries from GitHub.

## Installation Details

The feature installation script:

1. Detects the system architecture (x86_64 or aarch64)
2. Installs Go (if not already present)
3. Downloads docbuilder binary from [inful/docbuilder releases](https://github.com/inful/docbuilder/releases)
4. Downloads Hugo Extended binary from [gohugoio/hugo releases](https://github.com/gohugoio/hugo/releases)
5. Extracts binaries and places them in `/usr/local/bin`
6. Configures automatic preview server startup (if enabled)
7. Verifies that all binaries are executable and functional
8. Displays installed versions

The installation script includes version checking to skip downloads if the correct versions are already installed, improving rebuild performance.

## Error Handling

The installation script includes comprehensive error checking for:

- Unsupported architectures
- Network/download failures
- Archive extraction issues
- Invalid or missing binaries
- Installation directory permission issues

Clear error messages are provided for each failure case to aid troubleshooting.

## Verification

After installation, you can verify the tools are available:

```bash
docbuilder --version
hugo version
go version
```

Check if the preview server is running:

```bash
ps aux | grep docbuilder
# or check the logs
cat /tmp/docbuilder-preview.log
```

## Local Development

To test this feature locally in its own devcontainer:

```bash
# The .devcontainer/devcontainer.json includes this feature
devcontainer open .
```

## License

This feature is provided as-is. See the docbuilder and Hugo projects for their respective licenses.
