# Usage Guide

This guide covers how to use the DocBuilder DevContainer feature in your projects.

## Quick Start

Add the feature to your `devcontainer.json`:

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {}
    },
    "forwardPorts": [1316, 1319]
}
```

This installs:
- Go v1.25.5
- DocBuilder (latest version by default)
- Hugo Extended v0.154.1 (default)
- Auto-start preview server on container startup

## Port Forwarding

DocBuilder uses two ports that should be forwarded to access the preview server:

```json
{
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

**Ports:**
- **1316**: Preview server (main web interface)
- **1319**: LiveReload server (port + 3 by default, customizable with `livereloadPort`)

## Configuration Examples

### Custom Versions

Pin to specific versions:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "docbuilderVersion": "0.5.0",
            "hugoVersion": "0.154.1"
        }
    }
}
```

### Using Latest Versions

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

### Custom Preview Configuration

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "autoPreview": true,
            "docsDir": "documentation",
            "previewPort": "8080",
            "livereloadPort": "9000",
            "verbose": true
        }
    },
    "forwardPorts": [8080, 9000]
}
```

### Disable Auto-Preview

If you prefer to start the preview server manually:

```json
{
    "features": {
        "ghcr.io/inful/docbuilder-feature/docbuilder:latest": {
            "autoPreview": false
        }
    }
}
```

Then start it manually when needed:

```bash
docbuilder preview
```

### Behind a Corporate Proxy

Configure proxy settings for downloading binaries:

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

## Common Workflows

### Starting the Preview Server

If auto-preview is disabled or you stopped the server:

```bash
docbuilder preview
```

With custom options:

```bash
docbuilder preview --docs-dir ./my-docs --port 8080 --verbose
```

### Viewing Logs

The preview server logs are written to `/tmp/docbuilder-preview.log`:

```bash
# View logs
cat /tmp/docbuilder-preview.log

# Follow logs in real-time
tail -f /tmp/docbuilder-preview.log
```

### Stopping the Preview Server

```bash
# Find the process
ps aux | grep docbuilder

# Kill the process
pkill docbuilder
```

## Troubleshooting

### Preview Server Not Starting

1. Check the logs: `cat /tmp/docbuilder-preview.log`
2. Verify Go is installed: `go version`
3. Check if docs directory exists
4. Try starting manually: `docbuilder preview --verbose`

### Download Failures

If binaries fail to download during container build:
- Check network connectivity
- Configure proxy settings if behind a firewall
- Check the devcontainer build logs for detailed errors

### Port Already in Use

If you see "port already in use" errors:
- Stop any existing docbuilder processes: `pkill docbuilder`
- Change the preview port in your configuration
- Rebuild the container

## Next Steps

- See [Configuration Reference](configuration.md) for all available options
- See [Publishing Guide](publishing.md) for information about releases and versions
- Visit the [DocBuilder repository](https://github.com/inful/docbuilder) for more documentation
