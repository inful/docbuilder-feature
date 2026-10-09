#!/bin/bash
set -e

# Source the devcontainer-features.env file if it exists
# This file contains the feature options passed from devcontainer.json
if [ -f "$(dirname "$0")/devcontainer-features.env" ]; then
    # shellcheck source=/dev/null
    source "$(dirname "$0")/devcontainer-features.env"
fi

DOCBUILDER_VERSION="${DOCBUILDERVERSION:-${docbuilderVersion:-latest}}"
HUGO_VERSION="${HUGOVERSION:-${hugoVersion:-0.154.1}}"
GO_VERSION="1.25.5"
AUTO_PREVIEW="${AUTOPREVIEW:-${autoPreview:-true}}"
DOCS_DIR="${DOCSDIR:-${docsDir:-docs}}"
PREVIEW_PORT="${PREVIEWPORT:-${previewPort:-1316}}"
LIVERELOAD_PORT="${LIVERELOADPORT:-${livereloadPort:-0}}"
VERBOSE="${VERBOSE:-${verbose:-false}}"
VSCODE_LINKS="${VSCODELINKS:-${vscodeLinks:-true}}"
INSTALL_MCP="${INSTALLMCP:-${installMcp:-false}}"
INSTALL_DIR="/usr/local/bin"
CURL_OPTS="-fSsL --connect-timeout 30 --max-time 120 --retry 2"

# Proxy settings - from devcontainer-features.env or environment
HTTP_PROXY="${HTTPPROXY:-${httpProxy:-${http_proxy:-}}}"
HTTPS_PROXY="${HTTPSPROXY:-${httpsProxy:-${https_proxy:-}}}"
NO_PROXY="${NOPROXY:-${noProxy:-${no_proxy:-}}}"

# Export them for curl and other tools to use
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export HTTP_PROXY HTTPS_PROXY NO_PROXY

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

# ----------------------------------------------------------------------------
# TLS / certificate fixup.
#
# In a devcontainer, three things commonly trip curl:
#   (a) The host forwarded SSL_CERT_FILE / CURL_CA_BUNDLE pointing at a
#       path that does not exist inside the container (corporate CA leaked
#       from a Fedora/RHEL laptop, or VS Code forwarding for a proxy).
#   (b) The container's /etc/ssl/certs/ca-certificates.crt is a 0-byte
#       file, a dangling symlink, or otherwise unreadable by curl even
#       though bash's `[ -s -r ]` test passes — leading to
#       `error setting certificate file: <path>` (curl exit 77).
#   (c) Setting SSL_CERT_FILE via environment variable on certain curl +
#       OpenSSL builds can silently stall the connection (TLS handshake
#       completes but the response never arrives) instead of using
#       OpenSSL's compiled-in defaults.
#
# ----------------------------------------------------------------------------
# Download helpers. Plain curl only. We inherit SSL_CERT_FILE /
# CURL_CA_BUNDLE / NODE_EXTRA_CA_CERTS from the environment so any
# upstream devcontainer feature that configures a corporate CA (e.g.
# bdsoha/devcontainers' custom-root-ca) is honored as-is. We never
# touch, unset, or replace the system trust store — that is the base
# image's responsibility, not ours.
download() {
    # shellcheck disable=SC2086
    curl $CURL_OPTS "$1" -o "$2"
}

fetch_text() {
    # shellcheck disable=SC2086
    curl -sSL "$1"
}

# Install Go (required by Hugo for module management)
install_go() {
    # Check if Go is already installed
    if command -v go > /dev/null 2>&1; then
        local installed_version=$(go version | awk '{print $3}')
        print_status "Go is already installed: $installed_version"
        return 0
    fi
    
    local arch=$(detect_architecture)
    local download_url="https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN
    
    print_info "Installing Go ${GO_VERSION} (${arch})..."
    print_info "URL: $download_url"
    
    # Download with retries
    local max_attempts=3
    local attempt=1
    
    if [ -n "$HTTP_PROXY" ]; then
        print_info "Using HTTP proxy: $HTTP_PROXY"
    fi
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Download attempt $attempt of $max_attempts..."
        if download "$download_url" "$temp_dir/go.tar.gz"; then
            if [ -f "$temp_dir/go.tar.gz" ] && [ -s "$temp_dir/go.tar.gz" ]; then
                print_status "Downloaded Go"
                break
            fi
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            print_info "Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    if [ ! -f "$temp_dir/go.tar.gz" ] || [ ! -s "$temp_dir/go.tar.gz" ]; then
        print_error "Failed to download Go from $download_url after $max_attempts attempts"
        return 1
    fi
    
    # Extract to /usr/local
    print_info "Extracting Go..."
    if ! sudo -E tar -C /usr/local -xzf "$temp_dir/go.tar.gz"; then
        print_error "Failed to extract Go archive"
        return 1
    fi
    print_status "Extracted Go"
    
    # Add Go to PATH for all users
    if ! grep -q "/usr/local/go/bin" /etc/profile.d/go.sh 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' | sudo -E tee /etc/profile.d/go.sh > /dev/null
        sudo -E chmod +x /etc/profile.d/go.sh
    fi
    
    # Add to current session
    export PATH=$PATH:/usr/local/go/bin
    
    # Verify installation
    if ! /usr/local/go/bin/go version > /dev/null 2>&1; then
        print_error "Failed to verify Go installation"
        return 1
    fi
    print_status "Go installed successfully: $(/usr/local/go/bin/go version)"
}

# Download and install docbuilder
install_docbuilder() {
    local version="$DOCBUILDER_VERSION"
    local check_existing=true
    
    # Resolve "latest" to actual version number
    if [ "$version" = "latest" ]; then
        print_info "Resolving 'latest' version for docbuilder..."
        version=$(fetch_text "https://api.github.com/repos/inful/docbuilder/releases/latest" | grep -oP '"tag_name":\s*"v?\K[0-9.]+' || echo "")
        if [ -z "$version" ]; then
            print_error "Failed to resolve 'latest' version for docbuilder"
            return 1
        fi
        print_info "Resolved to version: $version"
        # When using "latest", always download to ensure we get the newest version
        check_existing=false
    fi
    
    # Check if docbuilder is already installed with the correct version
    if [ "$check_existing" = "true" ] && command -v docbuilder > /dev/null 2>&1; then
        local installed_version=$(docbuilder --version 2>&1 | head -n1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        if [ "$installed_version" = "$version" ]; then
            print_status "docbuilder v${version} is already installed"
            return 0
        else
            print_info "docbuilder v${installed_version} is installed, but v${version} is requested. Updating..."
        fi
    elif [ "$check_existing" = "false" ] && command -v docbuilder > /dev/null 2>&1; then
        local installed_version=$(docbuilder --version 2>&1 | head -n1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        print_info "Using 'latest' - will download v${version} (currently have v${installed_version})"
    fi
    
    local arch=$(detect_architecture)
    local download_url="https://github.com/inful/docbuilder/releases/download/v${version}/docbuilder_linux_${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN
    
    print_info "Installing docbuilder v${version} (${arch})..."
    print_info "URL: $download_url"
    
    # Download with retries
    local max_attempts=3
    local attempt=1
    
    # Note: Proxy is handled via environment variables (http_proxy, https_proxy, no_proxy)
    # which are exported at the beginning of this script
    if [ -n "$HTTP_PROXY" ]; then
        print_info "Using HTTP proxy: $HTTP_PROXY"
    fi
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Download attempt $attempt of $max_attempts..."
        if download "$download_url" "$temp_dir/docbuilder.tar.gz"; then
            if [ -f "$temp_dir/docbuilder.tar.gz" ] && [ -s "$temp_dir/docbuilder.tar.gz" ]; then
                print_status "Downloaded docbuilder"
                break
            else
                print_error "Download succeeded but file is missing or empty"
                print_error "File exists: $([ -f "$temp_dir/docbuilder.tar.gz" ] && echo yes || echo no)"
                print_error "File size: $([ -f "$temp_dir/docbuilder.tar.gz" ] && stat -f%z "$temp_dir/docbuilder.tar.gz" 2>/dev/null || stat -c%s "$temp_dir/docbuilder.tar.gz" 2>/dev/null || echo unknown)"
            fi
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            print_info "Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    if [ ! -f "$temp_dir/docbuilder.tar.gz" ] || [ ! -s "$temp_dir/docbuilder.tar.gz" ]; then
        print_error "Failed to download docbuilder from $download_url after $max_attempts attempts"
        return 1
    fi
    
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
    
    if ! sudo -E mv "$binary" "$INSTALL_DIR/docbuilder"; then
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

# Download and install docbuilder-mcp from the release tarball.
#
# This is a separate function (rather than a tail block of install_docbuilder)
# so it runs regardless of the docbuilder early-return optimization. The
# dev-container layer cache commonly reuses the docbuilder install across
# rebuilds, and the early-return in install_docbuilder would otherwise skip
# this step whenever docbuilder is already at the right version.
#
# Archive layout history (upstream inful/docbuilder):
#   v0.14.1 - v0.15.1 : docbuilder-mcp is bundled inside the main tarball
#   v0.15.2+          : docbuilder-mcp is shipped as its own tarball
#                       (docbuilder-mcp_linux_<arch>.tar.gz)
# We try the dedicated tarball first and fall back to extracting from the
# main tarball so installs pinned to older versions keep working.
install_docbuilder_mcp() {
    print_info "docbuilder-mcp: installMcp=${INSTALL_MCP}; INSTALLMCP_env=${INSTALLMCP:-unset}; installMcp_env=${installMcp:-unset}; INSTALL_DIR=${INSTALL_DIR}"
    if [ "$INSTALL_MCP" != "true" ]; then
        print_info "docbuilder-mcp: skipping install (installMcp is not 'true')"
        return 0
    fi

    if [ -x "$INSTALL_DIR/docbuilder-mcp" ]; then
        print_status "docbuilder-mcp is already installed"
        return 0
    fi

    local version="$DOCBUILDER_VERSION"

    # Resolve "latest" to actual version number
    if [ "$version" = "latest" ]; then
        print_info "Resolving 'latest' version for docbuilder-mcp..."
        version=$(fetch_text "https://api.github.com/repos/inful/docbuilder/releases/latest" | grep -oP '"tag_name":\s*"v?\K[0-9.]+' || echo "")
        if [ -z "$version" ]; then
            print_error "Failed to resolve 'latest' version for docbuilder-mcp"
            return 1
        fi
        print_info "Resolved to version: $version"
    fi

    local arch
    arch=$(detect_architecture)
    local mcp_tarball_url="https://github.com/inful/docbuilder/releases/download/v${version}/docbuilder-mcp_linux_${arch}.tar.gz"
    local main_tarball_url="https://github.com/inful/docbuilder/releases/download/v${version}/docbuilder_linux_${arch}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$temp_dir'" RETURN

    print_info "Installing docbuilder-mcp v${version} (${arch})..."

    if [ -n "$HTTP_PROXY" ]; then
        print_info "Using HTTP proxy: $HTTP_PROXY"
    fi

    local mcp_binary=""

    # Primary path: dedicated MCP tarball (v0.15.2+).
    # download() returns non-zero on HTTP errors / network failure, which
    # short-circuits this `if` cleanly under set -e.
    if download "$mcp_tarball_url" "$temp_dir/mcp.tar.gz" \
        && [ -s "$temp_dir/mcp.tar.gz" ] \
        && tar -xzf "$temp_dir/mcp.tar.gz" -C "$temp_dir" 2>/dev/null; then
        mcp_binary=$(find "$temp_dir" -maxdepth 1 -type f -name "docbuilder-mcp" || true)
    fi

    # Fallback: extract from the main tarball (v0.14.1 - v0.15.1).
    if [ -z "$mcp_binary" ]; then
        print_info "Dedicated MCP tarball not available for v${version}; checking main tarball..."
        if download "$main_tarball_url" "$temp_dir/docbuilder.tar.gz" \
            && [ -s "$temp_dir/docbuilder.tar.gz" ] \
            && tar -xzf "$temp_dir/docbuilder.tar.gz" -C "$temp_dir" 2>/dev/null; then
            mcp_binary=$(find "$temp_dir" -maxdepth 1 -type f -name "docbuilder-mcp" || true)
        fi
    fi

    if [ -z "$mcp_binary" ]; then
        print_error "docbuilder-mcp binary not available for v${version} (requested via installMcp=true). It is bundled in the main tarball for v0.14.1-v0.15.1 and shipped as its own tarball from v0.15.2 onwards; pin docbuilderVersion to a version with a release tarball (or disable installMcp)."
        return 1
    fi

    if ! sudo -E mv "$mcp_binary" "$INSTALL_DIR/docbuilder-mcp"; then
        print_error "Failed to install docbuilder-mcp to $INSTALL_DIR"
        return 1
    fi

    if ! sudo -E chmod +x "$INSTALL_DIR/docbuilder-mcp"; then
        print_error "Failed to make docbuilder-mcp executable"
        return 1
    fi

    if ! "$INSTALL_DIR/docbuilder-mcp" --version > /dev/null 2>&1; then
        print_error "Failed to verify docbuilder-mcp installation"
        return 1
    fi
    print_status "docbuilder-mcp installed successfully"
}

# Download and install hugo (extended)
install_hugo() {
    local version="$HUGO_VERSION"
    local check_existing=true
    
    # Resolve "latest" to actual version number
    if [ "$version" = "latest" ]; then
        print_info "Resolving 'latest' version for hugo..."
        version=$(fetch_text "https://api.github.com/repos/gohugoio/hugo/releases/latest" | grep -oP '"tag_name":\s*"v?\K[0-9.]+' || echo "")
        if [ -z "$version" ]; then
            print_error "Failed to resolve 'latest' version for hugo"
            return 1
        fi
        print_info "Resolved to version: $version"
        # When using "latest", always download to ensure we get the newest version
        check_existing=false
    fi
    
    # Check if hugo is already installed with the correct version
    if [ "$check_existing" = "true" ] && command -v hugo > /dev/null 2>&1; then
        local installed_version=$(hugo version 2>&1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
        if [ "$installed_version" = "$version" ]; then
            # Also check if it's the extended version
            if hugo version 2>&1 | grep -q "extended"; then
                print_status "hugo (extended) v${version} is already installed"
                return 0
            else
                print_info "hugo v${installed_version} is installed but not the extended version. Updating..."
            fi
        else
            print_info "hugo v${installed_version} is installed, but v${version} is requested. Updating..."
        fi
    elif [ "$check_existing" = "false" ] && command -v hugo > /dev/null 2>&1; then
        local installed_version=$(hugo version 2>&1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
        print_info "Using 'latest' - will download v${version} (currently have v${installed_version})"
    fi
    
    local arch=$(detect_architecture)
    local download_url="https://github.com/gohugoio/hugo/releases/download/v${version}/hugo_extended_${version}_linux-${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN
    
    print_info "Installing hugo (extended) v${version} (${arch})..."
    print_info "URL: $download_url"
    
    # Download with retries
    local max_attempts=3
    local attempt=1
    
    # Note: Proxy is handled via environment variables (http_proxy, https_proxy, no_proxy)
    # which are exported at the beginning of this script
    if [ -n "$HTTP_PROXY" ]; then
        print_info "Using HTTP proxy: $HTTP_PROXY"
    fi
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Download attempt $attempt of $max_attempts..."
        if download "$download_url" "$temp_dir/hugo.tar.gz"; then
            if [ -f "$temp_dir/hugo.tar.gz" ] && [ -s "$temp_dir/hugo.tar.gz" ]; then
                print_status "Downloaded hugo"
                break
            else
                print_error "Download succeeded but file is missing or empty"
                print_error "File exists: $([ -f "$temp_dir/hugo.tar.gz" ] && echo yes || echo no)"
                print_error "File size: $([ -f "$temp_dir/hugo.tar.gz" ] && stat -f%z "$temp_dir/hugo.tar.gz" 2>/dev/null || stat -c%s "$temp_dir/hugo.tar.gz" 2>/dev/null || echo unknown)"
            fi
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            print_info "Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    if [ ! -f "$temp_dir/hugo.tar.gz" ] || [ ! -s "$temp_dir/hugo.tar.gz" ]; then
        print_error "Failed to download hugo from $download_url after $max_attempts attempts"
        [ -f /tmp/curl_err.log ] && cat /tmp/curl_err.log
        return 1
    fi
    
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
    
    if ! sudo -E mv "$temp_dir/hugo" "$INSTALL_DIR/hugo"; then
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

# Setup auto-preview script
setup_auto_preview() {
    if [ "$AUTO_PREVIEW" = "true" ]; then
        print_info "Setting up auto-preview..."
        
        # Get the directory where this script is located
        local script_dir="$(cd "$(dirname "$0")" && pwd)"
        
        # Install startup script with variable substitution
        local startup_script="/usr/local/share/docbuilder-preview.sh"
        if [ -f "$script_dir/preview-startup.sh" ]; then
            sed -e "s|__DOCS_DIR__|${DOCS_DIR}|g" \
                -e "s|__PREVIEW_PORT__|${PREVIEW_PORT}|g" \
                -e "s|__LIVERELOAD_PORT__|${LIVERELOAD_PORT}|g" \
                -e "s|__VERBOSE__|${VERBOSE}|g" \
                -e "s|__VSCODE_LINKS__|${VSCODE_LINKS}|g" \
                "$script_dir/preview-startup.sh" | sudo -E tee "$startup_script" > /dev/null
            sudo -E chmod +x "$startup_script"
            print_status "Auto-preview script installed"
            print_info "Preview will start via postAttachCommand lifecycle hook"
        else
            print_error "preview-startup.sh not found in $script_dir"
            return 1
        fi
    else
        print_info "Auto-preview disabled"
    fi
}

# Setup update-on-attach script (works around Docker layer caching)
setup_update_on_attach() {
    print_info "Installing update-on-attach script..."

    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    local update_script="/usr/local/share/docbuilder-update.sh"

    if [ -f "$script_dir/update-on-attach.sh" ]; then
        sed -e "s|__DOCBUILDER_VERSION_REQUESTED__|${DOCBUILDER_VERSION}|g" \
            -e "s|__HUGO_VERSION_REQUESTED__|${HUGO_VERSION}|g" \
            -e "s|__INSTALL_MCP_REQUESTED__|${INSTALL_MCP}|g" \
            "$script_dir/update-on-attach.sh" | sudo -E tee "$update_script" > /dev/null
        sudo -E chmod +x "$update_script"
        print_status "Update-on-attach script installed"
    else
        print_error "update-on-attach.sh not found in $script_dir"
        return 1
    fi
}

# Main installation process
main() {
    echo "=========================================="
    echo "DocBuilder and Hugo Extended Installer"
    echo "=========================================="
    echo ""
    
    check_install_dir
    echo ""

    install_go
    echo ""
    
    install_docbuilder
    echo ""

    install_docbuilder_mcp
    echo ""

    install_hugo
    echo ""

    setup_update_on_attach
    echo ""
    
    setup_auto_preview
    echo ""
    
    echo "=========================================="
    print_status "Installation complete"
    echo "=========================================="
    echo ""
    
    # Display versions
    echo "Installed versions:"
    "$INSTALL_DIR/docbuilder" --version
    "$INSTALL_DIR/hugo" version
    if [ "$INSTALL_MCP" = "true" ] && [ -x "$INSTALL_DIR/docbuilder-mcp" ]; then
        "$INSTALL_DIR/docbuilder-mcp" --version
    fi
}

main "$@"
