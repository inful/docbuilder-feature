# DocBuilder Feature

A DevContainer feature that installs [DocBuilder](https://github.com/inful/docbuilder) and [Hugo Extended](https://github.com/gohugoio/hugo) binaries into a development container.

## Features

- 🏗️ Installs **DocBuilder** - A static documentation builder
- 📖 Installs **Hugo Extended** - A fast and flexible static site generator
- 🐹 Installs **Go** - Required by Hugo for module management
- 🏗️ Supports both **amd64** and **arm64** architectures
- ⚙️ Configurable versions for all tools
- 🚀 Automatic preview server startup (configurable)
- 🔄 Smart version checking to skip redundant downloads
- 🌐 Proxy support for downloads

## Quick Start

Add this feature to your `devcontainer.json`:

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {}
    }
}
```

This will install:
- Go v1.23.4
- DocBuilder v0.1.46 (default)
- Hugo Extended v0.154.1 (default)
- Auto-start preview server on container startup

## Options

### `docbuilderVersion`
- Type: `string`
- Default: `0.1.46`
- Proposals: `0.1.46`, `latest`
- Description: Version of DocBuilder to install

### `hugoVersion`
- Type: `string`
- Default: `0.154.1`
- Proposals: `0.154.1`, `latest`
- Description: Version of Hugo Extended to install

### `autoPreview`
- Type: `boolean`
- Default: `true`
- Description: Automatically start docbuilder preview server when container starts

### `docsDir`
- Type: `string`
- Default: `"docs"`
- Description: Directory containing documentation source files for docbuilder preview

### `previewPort`
- Type: `string`
- Default: `"1316"`
- Description: Port for docbuilder preview server

### `verbose`
- Type: `boolean`
- Default: `false`
- Description: Enable verbose output for docbuilder preview

### `httpProxy`
- Type: `string`
- Default: `""`
- Description: HTTP proxy URL for downloading binaries

### `httpsProxy`
- Type: `string`
- Default: `""`
- Description: HTTPS proxy URL for downloading binaries

### `noProxy`
- Type: `string`
- Default: `""`
- Description: Comma-separated list of hosts to exclude from proxying

## Examples

### Custom Versions

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.1.45",
            "hugoVersion": "0.153.0"
        }
    }
}
```

### Latest Versions

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

## Verification

After the container is created, verify the tools are installed:

```bash
docbuilder --version
hugo version
go version
```

Check if the preview server is running:

```bash
ps aux | grep docbuilder
cat /tmp/docbuilder-preview.log
```

## Supported Platforms

- Linux x86_64 (amd64)
- Linux ARM64 (arm64)

## Installation Details

The feature performs the following steps:

1. Detects system architecture (x86_64 or aarch64)
2. Installs Go 1.23.4 (if not already present)
3. Downloads DocBuilder from [inful/docbuilder releases](https://github.com/inful/docbuilder/releases)
4. Downloads Hugo Extended from [gohugoio/hugo releases](https://github.com/gohugoio/hugo/releases)
5. Extracts and installs binaries to `/usr/local/bin`
6. Configures automatic preview server startup (if enabled)
7. Verifies all binaries are functional
8. Displays installed versions

The installation script includes version checking to skip downloads if the correct versions are already installed, improving rebuild performance.

## Error Handling

The installation script includes comprehensive error checking for:
- Unsupported architectures
- Network/download failures
- Archive extraction issues
- Invalid or missing binaries
- Installation directory permission issues

## Publishing

This feature is published to the GitHub Container Registry. For more information about publishing and releases, see [PUBLISHING.md](PUBLISHING.md).

## License

See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please submit pull requests to the [docbuilder-feature](https://github.com/inful/docbuilder-feature) repository.

## Related Projects

- [DocBuilder](https://github.com/inful/docbuilder) - The DocBuilder tool
- [Hugo](https://github.com/gohugoio/hugo) - The Hugo static site generator
- [Dev Containers](https://containers.dev/) - The Dev Containers specification
