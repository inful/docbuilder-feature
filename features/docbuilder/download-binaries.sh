#!/bin/bash
set -e

# Script to download binaries for both architectures
# This is used by CI before publishing the feature

DOCBUILDER_VERSION="${1:-0.1.46}"
HUGO_VERSION="${2:-0.154.1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

echo "Downloading binaries for docbuilder v${DOCBUILDER_VERSION} and hugo v${HUGO_VERSION}"
echo "=============================================="

# Download docbuilder for amd64
echo "Downloading docbuilder for amd64..."
curl -fSsL "https://github.com/inful/docbuilder/releases/download/v${DOCBUILDER_VERSION}/docbuilder_linux_amd64.tar.gz" | \
  tar -xz -C "$BIN_DIR/amd64" docbuilder
chmod +x "$BIN_DIR/amd64/docbuilder"
echo "✓ docbuilder amd64 downloaded"

# Download docbuilder for arm64
echo "Downloading docbuilder for arm64..."
curl -fSsL "https://github.com/inful/docbuilder/releases/download/v${DOCBUILDER_VERSION}/docbuilder_linux_arm64.tar.gz" | \
  tar -xz -C "$BIN_DIR/arm64" docbuilder
chmod +x "$BIN_DIR/arm64/docbuilder"
echo "✓ docbuilder arm64 downloaded"

# Download hugo extended for amd64
echo "Downloading hugo extended for amd64..."
curl -fSsL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" | \
  tar -xz -C "$BIN_DIR/amd64" hugo
chmod +x "$BIN_DIR/amd64/hugo"
echo "✓ hugo amd64 downloaded"

# Download hugo extended for arm64
echo "Downloading hugo extended for arm64..."
curl -fSsL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-arm64.tar.gz" | \
  tar -xz -C "$BIN_DIR/arm64" hugo
chmod +x "$BIN_DIR/arm64/hugo"
echo "✓ hugo arm64 downloaded"

echo ""
echo "=============================================="
echo "All binaries downloaded successfully!"
echo ""
echo "Verifying binaries..."
echo ""

# Verify binaries
echo "amd64 docbuilder version:"
"$BIN_DIR/amd64/docbuilder" --version || echo "Failed to verify"

echo ""
echo "arm64 docbuilder version:"
"$BIN_DIR/arm64/docbuilder" --version || echo "Failed to verify (requires arm64 system)"

echo ""
echo "amd64 hugo version:"
"$BIN_DIR/amd64/hugo" version || echo "Failed to verify"

echo ""
echo "arm64 hugo version:"
"$BIN_DIR/arm64/hugo" version || echo "Failed to verify (requires arm64 system)"

echo ""
echo "Binary sizes:"
du -h "$BIN_DIR/amd64/"* "$BIN_DIR/arm64/"*
