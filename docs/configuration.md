# Configuration Reference

Complete reference for all configuration options available in the DocBuilder DevContainer feature.

## Options

### `docbuilderVersion`

- **Type:** `string`
- **Default:** `"0.5.0"`
- **Proposals:** `"0.5.0"`, `"latest"`
- **Description:** Version of DocBuilder to install

Specify the exact version of DocBuilder to install, or use `"latest"` to always get the newest release. When using `"latest"`, the feature queries the GitHub API to resolve the latest version number.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.1.45"
        }
    }
}
```

### `hugoVersion`

- **Type:** `string`
- **Default:** `"0.154.1"`
- **Proposals:** `"0.154.1"`, `"latest"`
- **Description:** Version of Hugo Extended to install

The feature installs the extended edition of Hugo, which includes additional features like SCSS processing. When using `"latest"`, the feature queries the GitHub API to resolve the latest version number.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "hugoVersion": "0.153.0"
        }
    }
}
```

### `autoPreview`

- **Type:** `boolean`
- **Default:** `true`
- **Description:** Automatically start docbuilder preview server when container starts

When enabled, the DocBuilder preview server starts automatically in the background when you open a terminal in the container. The server runs in the workspace directory and serves the documentation on the configured port.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "autoPreview": false
        }
    }
}
```

### `docsDir`

- **Type:** `string`
- **Default:** `"docs"`
- **Description:** Directory containing documentation source files for docbuilder preview

This directory will be created automatically if it doesn't exist. The preview server uses this as the source for documentation files.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docsDir": "documentation"
        }
    }
}
```

### `previewPort`

- **Type:** `string`
- **Default:** `"1316"`
- **Description:** Port for docbuilder preview server

The main HTTP port where the documentation preview will be served. Make sure to include this in your `forwardPorts` configuration.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "previewPort": "8080"
        }
    },
    "forwardPorts": [8080, 8083]
}
```

**Note:** DocBuilder uses the preview port and the LiveReload port (preview port + 3).

### `livereloadPort`

- **Type:** `string`
- **Default:** `"0"`
- **Description:** Port for LiveReload server

When set to `"0"` (default), DocBuilder automatically calculates the LiveReload port as `previewPort + 3`. Set to a specific port number if you need explicit control over the LiveReload port.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "previewPort": "8080",
            "livereloadPort": "9000"
        }
    },
    "forwardPorts": [8080, 9000]
}
```

### `verbose`

- **Type:** `boolean`
- **Default:** `false`
- **Description:** Enable verbose output for docbuilder preview

Enables detailed logging from the DocBuilder preview server. Useful for debugging issues.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "verbose": true
        }
    }
}
```

### `httpProxy`

- **Type:** `string`
- **Default:** `""`
- **Description:** HTTP proxy URL for downloading binaries

Used when downloading DocBuilder, Hugo, and Go binaries during container build. Supports environment variable references.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "httpProxy": "${localEnv:HTTP_PROXY}"
        }
    }
}
```

### `httpsProxy`

- **Type:** `string`
- **Default:** `""`
- **Description:** HTTPS proxy URL for downloading binaries

Used for HTTPS connections when downloading binaries.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "httpsProxy": "${localEnv:HTTPS_PROXY}"
        }
    }
}
```

### `noProxy`

- **Type:** `string`
- **Default:** `""`
- **Description:** Comma-separated list of hosts to exclude from proxying

Specifies hosts that should bypass the proxy. Common values include localhost, internal domains, and IP ranges.

**Example:**
```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "noProxy": "localhost,127.0.0.1,.example.com"
        }
    }
}
```

## Complete Configuration Example

Here's a complete example showing all options:

```json
{
    "name": "My Documentation Project",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.5.0",
            "hugoVersion": "0.154.1",
            "autoPreview": true,
            "docsDir": "docs",
            "previewPort": "1316",
            "livereloadPort": "0",
            "verbose": false,
            "httpProxy": "${localEnv:HTTP_PROXY}",
            "httpsProxy": "${localEnv:HTTPS_PROXY}",
            "noProxy": "${localEnv:NO_PROXY}"
        }
    },
    "forwardPorts": [1316, 1319],
    "portsAttributes": {
        "1316": {
            "label": "DocBuilder Preview",
            "onAutoForward": "notify"
        },
        "1319": {
            "label": "DocBuilder LiveReload",
            "onAutoForward": "silent"
        }
    }
}
```

## Installation Behavior

### Version Checking

The feature includes smart version checking. If the requested versions of DocBuilder, Hugo, or Go are already installed, the downloads are skipped, improving rebuild performance.

### Binary Locations

All binaries are installed to `/usr/local/bin`:
- `/usr/local/bin/docbuilder`
- `/usr/local/bin/hugo`
- `/usr/local/bin/go` (in `/usr/local/go/bin`, added to PATH)

### Auto-Preview Mechanism

When `autoPreview` is enabled:
1. A script is added to `/etc/bash.bashrc`
2. The script runs when the first shell session opens
3. It checks for the workspace directory
4. Creates the docs directory if needed
5. Starts `docbuilder preview` in the background
6. Logs output to `/tmp/docbuilder-preview.log`

The preview server only starts once per container (controlled by the `DOCBUILDER_PREVIEW_STARTED` environment variable).

## Supported Platforms

- **Linux amd64** (x86_64)
- **Linux arm64** (aarch64)

The feature automatically detects the architecture and downloads the appropriate binaries.
