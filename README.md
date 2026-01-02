# DocBuilder Feature

A DevContainer feature that installs [DocBuilder](https://github.com/inful/docbuilder) and [Hugo Extended](https://github.com/gohugoio/hugo) binaries into a development container.

## Features

- 🏗️ Installs **DocBuilder** - A static documentation builder
- 📖 Installs **Hugo Extended** - A fast and flexible static site generator
- 🏗️ Supports both **amd64** and **arm64** architectures
- ⚙️ Configurable versions for both tools

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
- DocBuilder v0.1.46 (default)
- Hugo Extended v0.154.1 (default)

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
```

## Supported Platforms

- Linux x86_64 (amd64)
- Linux ARM64 (arm64)

## Installation Details

The feature performs the following steps:

1. Detects system architecture (x86_64 or aarch64)
2. Downloads DocBuilder from [inful/docbuilder releases](https://github.com/inful/docbuilder/releases)
3. Downloads Hugo Extended from [gohugoio/hugo releases](https://github.com/gohugoio/hugo/releases)
4. Extracts and installs binaries to `/usr/local/bin`
5. Verifies both binaries are functional
6. Displays installed versions

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
