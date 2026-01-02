# DocBuilder DevContainer Feature

A [DevContainer feature](https://containers.dev/implementors/features/) that installs [DocBuilder](https://github.com/inful/docbuilder), [Hugo Extended](https://github.com/gohugoio/hugo), and Go into your development container with automatic preview server support.

## What's Included

- 🏗️ **DocBuilder** - Static documentation builder
- 📖 **Hugo Extended** - Static site generator with SCSS support
- 🐹 **Go** - Required by Hugo for module management
- 🚀 **Auto-preview** - Documentation server starts automatically
- 🔄 **Smart caching** - Skips downloads if versions already installed
- 🌐 **Proxy support** - Works behind corporate firewalls

## Quick Start

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {}
    },
    "forwardPorts": [1316]
}
```

Rebuild your container and open `http://localhost:1316` to see your documentation.

## Documentation

- **[Usage Guide](docs/usage.md)** - Examples and common workflows
- **[Configuration Reference](docs/configuration.md)** - All available options
- **[Publishing Guide](docs/publishing.md)** - For maintainers

## Supported Platforms

- Linux x86_64 (amd64)
- Linux ARM64 (aarch64)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this feature.

## Related Projects

- [DocBuilder](https://github.com/inful/docbuilder) - The DocBuilder tool
- [Hugo](https://github.com/gohugoio/hugo) - The Hugo static site generator
- [Dev Containers](https://containers.dev/) - Development container specification
