#!/bin/bash
set -e

# Configuration
DOCBUILDER_VERSION="${DOCBUILDER_VERSION:-0.1.46}"
HUGO_VERSION="${HUGO_VERSION:-0.154.1}"
INSTALL_DIR="/usr/local/bin"

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
    local download_url="https://github.com/inful/docbuilder/releases/download/v${DOCBUILDER_VERSION}/docbuilder_linux_${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN
    
    print_info "Installing docbuilder v${DOCBUILDER_VERSION} (${arch})..."
    
    # Download
    if ! curl -sL "$download_url" -o "$temp_dir/docbuilder.tar.gz"; then
        print_error "Failed to download docbuilder from $download_url"
        return 1
    fi
    if [ ! -s "$temp_dir/docbuilder.tar.gz" ]; then
        print_error "Downloaded file is empty or does not exist"
        return 1
    fi
    print_status "Downloaded docbuilder"
    
    # Extract
    if ! tar -xzf "$temp_dir/docbuilder.tar.gz" -C "$temp_dir"; then
        print_error "Failed to extract docbuilder archive"
        return 1
    fi
    print_status "Extracted docbuilder"
    
    # Find and install binary
    local binary=$(find "$temp_dir" -maxdepth 1 -type f -name "docbuilder")
    if [ -z "$binary" ]; then
        print_error "docbuilder binary not found in archive"
        return 1
    fi
    
    if ! sudo mv "$binary" "$INSTALL_DIR/docbuilder"; then
        print_error "Failed to install docbuilder to $INSTALL_DIR"
        return 1
    fi
    
    if ! sudo chmod +x "$INSTALL_DIR/docbuilder"; then
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
    local download_url="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN
    
    print_info "Installing hugo (extended) v${HUGO_VERSION} (${arch})..."
    
    # Download
    if ! curl -sL "$download_url" -o "$temp_dir/hugo.tar.gz"; then
        print_error "Failed to download hugo from $download_url"
        return 1
    fi
    if [ ! -s "$temp_dir/hugo.tar.gz" ]; then
        print_error "Downloaded file is empty or does not exist"
        return 1
    fi
    print_status "Downloaded hugo"
    
    # Extract
    if ! tar -xzf "$temp_dir/hugo.tar.gz" -C "$temp_dir"; then
        print_error "Failed to extract hugo archive"
        return 1
    fi
    print_status "Extracted hugo"
    
    # Install binary
    if [ ! -f "$temp_dir/hugo" ]; then
        print_error "hugo binary not found in archive"
        return 1
    fi
    
    if ! sudo mv "$temp_dir/hugo" "$INSTALL_DIR/hugo"; then
        print_error "Failed to install hugo to $INSTALL_DIR"
        return 1
    fi
    
    if ! sudo chmod +x "$INSTALL_DIR/hugo"; then
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
