#!/bin/bash
set -e

# Configuration
DOCBUILDER_VERSION="${DOCBUILDERVERSION:-${docbuilderVersion:-0.1.46}}"
HUGO_VERSION="${HUGOVERSION:-${hugoVersion:-0.154.1}}"
INSTALL_DIR="/usr/local/bin"

# Get the directory where this script is located (feature directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect architecture
detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        *)
            echo "ERROR: Unsupported architecture: $arch" >&2
            echo "Supported architectures: x86_64 (amd64), aarch64 (arm64)" >&2
            exit 1
            ;;
    esac
}

# Print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check if installation directory exists and sudo is available
check_install_dir() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Installation directory $INSTALL_DIR does not exist"
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        print_info "sudo password will be required for installation to $INSTALL_DIR"
    fi
    print_status "Installation directory $INSTALL_DIR exists"
}

# Download and install docbuilder
install_docbuilder() {
    local arch=$(detect_architecture)
    local binary_path="$BIN_DIR/${arch}/docbuilder"
    
    print_info "Installing docbuilder v${DOCBUILDER_VERSION} (${arch})..."
    
    # Check if binary exists in the bin directory
    if [ ! -f "$binary_path" ]; then
        print_error "docbuilder binary not found at $binary_path"
        print_error "The binary should be bundled with this feature in bin/${arch}/docbuilder"
        return 1
    fi
    
    # Verify binary is executable
    if [ ! -x "$binary_path" ]; then
        print_info "Making binary executable..."
        chmod +x "$binary_path"
    fi
    
    # Install binary
    if ! sudo -E cp "$binary_path" "$INSTALL_DIR/docbuilder"; then
        print_error "Failed to install docbuilder to $INSTALL_DIR"
        return 1
    fi
    
    if ! sudo -E chmod +x "$INSTALL_DIR/docbuilder"; then
        print_error "Failed to make docbuilder executable"
        return 1
    fi
    
    # Verify installation
    if ! "$INSTALL_DIR/docbuilder" --version > /dev/null 2>&1; then
        print_error "Failed to verify docbuilder installation"
        return 1
    fi
    print_status "docbuilder installed successfully"
}

# Download and install hugo (extended)
install_hugo() {
    local arch=$(detect_architecture)
    local binary_path="$BIN_DIR/${arch}/hugo"
    
    print_info "Installing hugo (extended) v${HUGO_VERSION} (${arch})..."
    
    # Check if binary exists in the bin directory
    if [ ! -f "$binary_path" ]; then
        print_error "hugo binary not found at $binary_path"
        print_error "The binary should be bundled with this feature in bin/${arch}/hugo"
        return 1
    fi
    
    # Verify binary is executable
    if [ ! -x "$binary_path" ]; then
        print_info "Making binary executable..."
        chmod +x "$binary_path"
    fi
    
    # Install binary
    if ! sudo -E cp "$binary_path" "$INSTALL_DIR/hugo"; then
        print_error "Failed to install hugo to $INSTALL_DIR"
        return 1
    fi
    
    if ! sudo -E chmod +x "$INSTALL_DIR/hugo"; then
        print_error "Failed to make hugo executable"
        return 1
    fi
    
    # Verify installation
    if ! "$INSTALL_DIR/hugo" version > /dev/null 2>&1; then
        print_error "Failed to verify hugo installation"
        return 1
    fi
    print_status "hugo installed successfully"
}

# Main installation process
main() {
    echo "=========================================="
    echo "DocBuilder and Hugo Extended Installer"
    echo "=========================================="
    echo ""
    
    check_install_dir
    echo ""
    
    install_docbuilder
    echo ""
    
    install_hugo
    echo ""
    
    echo "=========================================="
    print_status "Installation complete"
    echo "=========================================="
    echo ""
    
    # Display versions
    echo "Installed versions:"
    "$INSTALL_DIR/docbuilder" --version
    "$INSTALL_DIR/hugo" version
}

main "$@"
