# DocBuilder and Hugo Extended

This is a DevContainer feature that installs both [docbuilder](https://github.com/inful/docbuilder) and [Hugo Extended](https://github.com/gohugoio/hugo) binaries into a development container.

## Contents

- Installs `docbuilder` binary
- Installs `hugo` (extended edition) binary

## Options

### `docbuilderVersion` (default: `0.1.46`)

The version of docbuilder to install. Can be set to any released version or `latest`.

### `hugoVersion` (default: `0.154.1`)

The version of Hugo Extended to install. Can be set to any released version or `latest`.

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
- docbuilder v0.1.46
- Hugo Extended v0.154.1

### Custom Versions

To use specific versions, override the options:

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

## Installation Details

The feature installation script:

1. Detects the system architecture (x86_64 or aarch64)
2. Downloads docbuilder binary from [inful/docbuilder releases](https://github.com/inful/docbuilder/releases)
3. Downloads Hugo Extended binary from [gohugoio/hugo releases](https://github.com/gohugoio/hugo/releases)
4. Extracts binaries and places them in `/usr/local/bin`
5. Verifies that both binaries are executable and functional
6. Displays installed versions

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
```

## Local Development

To test this feature locally in its own devcontainer:

```bash
# The .devcontainer/devcontainer.json includes this feature
devcontainer open .
```

## License

This feature is provided as-is. See the docbuilder and Hugo projects for their respective licenses.
