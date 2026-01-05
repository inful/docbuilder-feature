#!/bin/bash
set -e

# Source the devcontainer-features.env file if it exists
# This file contains the feature options passed from devcontainer.json
if [ -f "$(dirname "$0")/devcontainer-features.env" ]; then
    # shellcheck source=/dev/null
    source "$(dirname "$0")/devcontainer-features.env"
fi

# Configuration
DOCBUILDER_VERSION="${DOCBUILDERVERSION:-${docbuilderVersion:-latest}}"
HUGO_VERSION="${HUGOVERSION:-${hugoVersion:-0.154.1}}"
GO_VERSION="1.25.5"
AUTO_PREVIEW="${AUTOPREVIEW:-${autoPreview:-true}}"
DOCS_DIR="${DOCSDIR:-${docsDir:-docs}}"
PREVIEW_PORT="${PREVIEWPORT:-${previewPort:-1316}}"
LIVERELOAD_PORT="${LIVERELOADPORT:-${livereloadPort:-0}}"
VERBOSE="${VERBOSE:-${verbose:-false}}"
VSCODE_LINKS="${VSCODELINKS:-${vscodeLinks:-true}}"
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
        # shellcheck disable=SC2086
        if curl $CURL_OPTS "$download_url" -o "$temp_dir/go.tar.gz" 2>"$temp_dir/curl_error.log"; then
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
        # shellcheck disable=SC2086
        version=$(curl $CURL_OPTS "https://api.github.com/repos/inful/docbuilder/releases/latest" | grep -oP '"tag_name":\s*"v?\K[0-9.]+' || echo "")
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
        print_info "Environment: http_proxy='$http_proxy' https_proxy='$https_proxy' no_proxy='$NO_PROXY'"
        print_info "Curl command: curl $CURL_OPTS \"$download_url\" -o \"$temp_dir/docbuilder.tar.gz\""
        # shellcheck disable=SC2086
        if curl $CURL_OPTS -v "$download_url" -o "$temp_dir/docbuilder.tar.gz" 2>"$temp_dir/curl_error.log"; then
            if [ -f "$temp_dir/docbuilder.tar.gz" ] && [ -s "$temp_dir/docbuilder.tar.gz" ]; then
                print_status "Downloaded docbuilder"
                break
            else
                print_error "Download succeeded but file is missing or empty"
                print_error "File exists: $([ -f "$temp_dir/docbuilder.tar.gz" ] && echo yes || echo no)"
                print_error "File size: $([ -f "$temp_dir/docbuilder.tar.gz" ] && stat -f%z "$temp_dir/docbuilder.tar.gz" 2>/dev/null || stat -c%s "$temp_dir/docbuilder.tar.gz" 2>/dev/null || echo unknown)"
            fi
        else
            local exit_code=$?
            print_error "Curl failed with exit code $exit_code"
            if [ -f "$temp_dir/curl_error.log" ]; then
                print_error "Curl error output:"
                cat "$temp_dir/curl_error.log" >&2
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

# Download and install hugo (extended)
install_hugo() {
    local version="$HUGO_VERSION"
    
    # Resolve "latest" to actual version number
    if [ "$version" = "latest" ]; then
        print_info "Resolving 'latest' version for hugo..."
        # shellcheck disable=SC2086
        version=$(curl $CURL_OPTS "https://api.github.com/repos/gohugoio/hugo/releases/latest" | grep -oP '"tag_name":\s*"v?\K[0-9.]+' || echo "")
        if [ -z "$version" ]; then
            print_error "Failed to resolve 'latest' version for hugo"
            return 1
        fi
        print_info "Resolved to version: $version"
    fi
    
    # Check if hugo is already installed with the correct version
    if command -v hugo > /dev/null 2>&1; then
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
        print_info "Environment: http_proxy='$http_proxy' https_proxy='$https_proxy' no_proxy='$NO_PROXY'"
        print_info "Curl command: curl $CURL_OPTS \"$download_url\" -o \"$temp_dir/hugo.tar.gz\""
        # shellcheck disable=SC2086
        if curl $CURL_OPTS -v "$download_url" -o "$temp_dir/hugo.tar.gz" 2>"$temp_dir/curl_error.log"; then
            if [ -f "$temp_dir/hugo.tar.gz" ] && [ -s "$temp_dir/hugo.tar.gz" ]; then
                print_status "Downloaded hugo"
                break
            else
                print_error "Download succeeded but file is missing or empty"
                print_error "File exists: $([ -f "$temp_dir/hugo.tar.gz" ] && echo yes || echo no)"
                print_error "File size: $([ -f "$temp_dir/hugo.tar.gz" ] && stat -f%z "$temp_dir/hugo.tar.gz" 2>/dev/null || stat -c%s "$temp_dir/hugo.tar.gz" 2>/dev/null || echo unknown)"
            fi
        else
            local exit_code=$?
            print_error "Curl failed with exit code $exit_code"
            if [ -f "$temp_dir/curl_error.log" ]; then
                print_error "Curl error output:"
                cat "$temp_dir/curl_error.log" >&2
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

# Setup auto-preview on container start
setup_auto_preview() {
    if [ "$AUTO_PREVIEW" = "true" ]; then
        print_info "Setting up auto-preview..."
        
        # Create startup script
        local startup_script="/usr/local/share/docbuilder-preview.sh"
        sudo -E tee "$startup_script" > /dev/null <<EOF
#!/bin/bash
# Auto-start docbuilder preview server

# Configuration from feature options
DOCS_DIR="${DOCS_DIR}"
PREVIEW_PORT="${PREVIEW_PORT}"
LIVERELOAD_PORT="${LIVERELOAD_PORT}"
VERBOSE="${VERBOSE}"

# Ensure Go is in PATH
export PATH=\$PATH:/usr/local/go/bin

# Wait a moment for container to fully initialize
sleep 2

# Find the workspace directory (typically /workspaces/*)
WORKSPACE_DIR="/workspaces"
if [ -d "\$WORKSPACE_DIR" ]; then
    cd "\$WORKSPACE_DIR" || exit 1
    
    # Find first subdirectory
    FIRST_DIR=\$(find "\$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -n "\$FIRST_DIR" ]; then
        cd "\$FIRST_DIR" || exit 1
    fi
fi

# Create docs directory if it doesn't exist
if [ ! -d "\$DOCS_DIR" ]; then
    echo "Creating \$DOCS_DIR directory..."
    mkdir -p "\$DOCS_DIR"
fi

# Check if docbuilder is available
if ! command -v docbuilder > /dev/null 2>&1; then
    echo "docbuilder not found in PATH"
    exit 1
fi

# Build command with options
CMD="docbuilder preview --docs-dir \$DOCS_DIR --port \$PREVIEW_PORT"
if [ "\$LIVERELOAD_PORT" != "0" ]; then
    CMD="\$CMD --livereload-port \$LIVERELOAD_PORT"
fi
if [ "\$VERBOSE" = "true" ]; then
    CMD="\$CMD --verbose"
fi

echo "Starting docbuilder preview server in \$(pwd)..."
echo "Command: \$CMD"
eval "\$CMD"
EOF
        
        sudo -E chmod +x "$startup_script"
        
        # Add to bashrc for bash users
        local bashrc_snippet="\\n# Auto-start docbuilder preview\\nif [ -z \"\$DOCBUILDER_PREVIEW_STARTED\" ]; then\\n    export DOCBUILDER_PREVIEW_STARTED=1\\n    if command -v docbuilder > /dev/null 2>&1 && [ -d \"/workspaces\" ]; then\\n        # Check if docbuilder is already running\\n        if pgrep -f 'docbuilder preview' > /dev/null 2>&1; then\\n            echo \"DocBuilder preview server is already running\"\\n        else\\n            for ws_dir in /workspaces/*; do\\n                if [ -d \"\$ws_dir\" ]; then\\n                    cd \"\$ws_dir\" || continue\\n                    DOCS_DIR=\"${DOCS_DIR}\"\\n                    [ ! -d \"\$DOCS_DIR\" ] && mkdir -p \"\$DOCS_DIR\"\\n                    CMD=\"docbuilder preview --docs-dir \$DOCS_DIR --port ${PREVIEW_PORT}\"\\n                    [ \"${LIVERELOAD_PORT}\" != \"0\" ] && CMD=\"\$CMD --livereload-port ${LIVERELOAD_PORT}\"\\n                    [ \"${VERBOSE}\" = \"true\" ] && CMD=\"\$CMD --verbose\"\\n                    [ \"${VSCODE_LINKS}\" = \"true\" ] && CMD=\"\$CMD --vscode\"\\n                    (PATH=\"\$PATH:/usr/local/go/bin\" nohup \$CMD > /tmp/docbuilder-preview.log 2>&1 &)\\n                    echo \"DocBuilder preview server started in \$ws_dir. Logs: /tmp/docbuilder-preview.log\"\\n                    break\\n                fi\\n            done\\n        fi\\n    fi\\nfi\\n"
        
        # Add to /etc/bash.bashrc for bash users
        if ! grep -q "DOCBUILDER_PREVIEW_STARTED" /etc/bash.bashrc 2>/dev/null; then
            echo -e "$bashrc_snippet" | sudo -E tee -a /etc/bash.bashrc > /dev/null
        fi
        
        # Add to fish config for fish shell users
        local fish_config_dir="/etc/fish/conf.d"
        if [ -d "$fish_config_dir" ] || command -v fish > /dev/null 2>&1; then
            sudo -E mkdir -p "$fish_config_dir"
            sudo -E tee "$fish_config_dir/docbuilder-preview.fish" > /dev/null <<FISHEOF
# Auto-start docbuilder preview
if not set -q DOCBUILDER_PREVIEW_STARTED
    set -gx DOCBUILDER_PREVIEW_STARTED 1
    if command -v docbuilder > /dev/null 2>&1; and test -d "/workspaces"
        # Check if docbuilder is already running
        if not pgrep -f 'docbuilder preview' > /dev/null 2>&1
            for ws_dir in /workspaces/*
                if test -d "\$ws_dir"
                    cd "\$ws_dir"
                    set DOCS_DIR "$DOCS_DIR"
                    test -d "\$DOCS_DIR"; or mkdir -p "\$DOCS_DIR"
                    set CMD "docbuilder preview --docs-dir \$DOCS_DIR --port $PREVIEW_PORT"
                    test "$LIVERELOAD_PORT" != "0"; and set CMD "\$CMD --livereload-port $LIVERELOAD_PORT"
                    test "$VERBOSE" = "true"; and set CMD "\$CMD --verbose"
                    test "$VSCODE_LINKS" = "true"; and set CMD "\$CMD --vscode"
                    fish -c "set -x PATH \$PATH /usr/local/go/bin; nohup \$CMD > /tmp/docbuilder-preview.log 2>&1 &"
                    echo "DocBuilder preview server started in \$ws_dir. Logs: /tmp/docbuilder-preview.log"
                    break
                end
            end
        else
            echo "DocBuilder preview server is already running"
        end
    end
end
FISHEOF
        fi
        
        print_status "Auto-preview configured (bash/fish shells)"
        print_info "Preview starts when you open a terminal in the container"
        print_info "For other shells, add to your devcontainer.json:"
        print_info '  "postCreateCommand": "docbuilder preview --docs-dir docs --port ${PREVIEW_PORT} > /tmp/docbuilder-preview.log 2>&1 &"'
    else
        print_info "Auto-preview disabled"
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
    
    install_hugo
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
}

main "$@"
