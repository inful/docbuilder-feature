#!/bin/bash
set -e

DOCBUILDER_VERSION_REQUESTED="__DOCBUILDER_VERSION_REQUESTED__"
HUGO_VERSION_REQUESTED="__HUGO_VERSION_REQUESTED__"
INSTALL_MCP_REQUESTED="__INSTALL_MCP_REQUESTED__"
INSTALL_DIR="/usr/local/bin"
CURL_OPTS="-fSsL --connect-timeout 30 --max-time 120 --retry 2"

# Respect proxy environment variables if present.
# curl will automatically use http_proxy/https_proxy/no_proxy.

print_info() {
    echo "[docbuilder-feature] $*" >&2
}

# Download helpers. Plain curl only.
download() {
    # shellcheck disable=SC2086
    curl $CURL_OPTS "$1" -o "$2"
}

# We do not patch, rebuild, or substitute the system's ca-certificates.
# Whatever SSL_CERT_FILE / CURL_CA_BUNDLE / NODE_EXTRA_CA_CERTS are set
# to by the base image or by upstream devcontainer features (for example
# bdsoha/devcontainers' custom-root-ca feature, which points them at a
# corporate CA bundle path) is honored as-is. curl with default settings
# picks up these env vars; Node.js uses NODE_EXTRA_CA_CERTS automatically.

detect_architecture() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        *)
            print_info "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

resolve_latest_docbuilder() {
    curl -sSL "https://api.github.com/repos/inful/docbuilder/releases/latest" \
        | grep -oP '"tag_name":\s*"v?\K[0-9.]+'
}

resolve_latest_hugo() {
    curl -sSL "https://api.github.com/repos/gohugoio/hugo/releases/latest" \
        | grep -oP '"tag_name":\s*"v?\K[0-9.]+'
}

installed_docbuilder_version() {
    if ! command -v docbuilder >/dev/null 2>&1; then
        echo ""
        return 0
    fi
    docbuilder --version 2>&1 | head -n1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' || true
}

installed_hugo_version() {
    if ! command -v hugo >/dev/null 2>&1; then
        echo ""
        return 0
    fi
    hugo version 2>&1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true
}

installed_docbuilder_mcp_version() {
    if ! command -v docbuilder-mcp >/dev/null 2>&1; then
        echo ""
        return 0
    fi
    docbuilder-mcp --version 2>&1 | head -n1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' || true
}

update_docbuilder_if_needed() {
    if [ "$DOCBUILDER_VERSION_REQUESTED" != "latest" ]; then
        return 0
    fi

    print_info "Checking for latest docbuilder release..."
    local latest
    latest=$(resolve_latest_docbuilder || true)
    if [ -z "$latest" ]; then
        print_info "Could not resolve latest docbuilder version; skipping update."
        return 0
    fi

    local current
    current=$(installed_docbuilder_version)
    if [ "$current" = "$latest" ]; then
        print_info "docbuilder is up-to-date (v$latest)."
        return 0
    fi

    local arch
    arch=$(detect_architecture)

    print_info "Updating docbuilder: ${current:-not installed} -> v$latest (${arch})"

    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    local url
    url="https://github.com/inful/docbuilder/releases/download/v${latest}/docbuilder_linux_${arch}.tar.gz"
    download "$url" "$temp_dir/docbuilder.tar.gz"
    tar -xzf "$temp_dir/docbuilder.tar.gz" -C "$temp_dir"

    local binary
    binary=$(find "$temp_dir" -maxdepth 1 -type f -name "docbuilder" | head -n1)
    if [ -z "$binary" ]; then
        print_info "docbuilder binary not found in archive; skipping update."
        return 0
    fi

    sudo -E mv "$binary" "$INSTALL_DIR/docbuilder"
    sudo -E chmod +x "$INSTALL_DIR/docbuilder"

    print_info "docbuilder updated to: $($INSTALL_DIR/docbuilder --version 2>/dev/null | head -n1 || echo "unknown")"
}

update_hugo_if_needed() {
    if [ "$HUGO_VERSION_REQUESTED" != "latest" ]; then
        return 0
    fi

    print_info "Checking for latest hugo release..."
    local latest
    latest=$(resolve_latest_hugo || true)
    if [ -z "$latest" ]; then
        print_info "Could not resolve latest hugo version; skipping update."
        return 0
    fi

    local current
    current=$(installed_hugo_version)
    if [ "$current" = "$latest" ]; then
        print_info "hugo is up-to-date (v$latest)."
        return 0
    fi

    local arch
    arch=$(detect_architecture)

    print_info "Updating hugo (extended): ${current:-not installed} -> v$latest (${arch})"

    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    local url
    url="https://github.com/gohugoio/hugo/releases/download/v${latest}/hugo_extended_${latest}_linux-${arch}.tar.gz"
    download "$url" "$temp_dir/hugo.tar.gz"
    tar -xzf "$temp_dir/hugo.tar.gz" -C "$temp_dir"

    if [ ! -f "$temp_dir/hugo" ]; then
        print_info "hugo binary not found in archive; skipping update."
        return 0
    fi

    sudo -E mv "$temp_dir/hugo" "$INSTALL_DIR/hugo"
    sudo -E chmod +x "$INSTALL_DIR/hugo"

    print_info "hugo updated to: $($INSTALL_DIR/hugo version 2>/dev/null | head -n1 || echo "unknown")"
}

# Install/refresh docbuilder-mcp at attach time. Runs whenever
# installMcp=true was set at build time, regardless of whether install.sh
# successfully placed the binary — so it self-heals when the build-time
# install was silently skipped (e.g. due to an unrelated env-var issue
# or an OCI layer cache hit on an older feature version).
#
# Mirrors the docbuilder/hugo refresh logic above: resolve the target
# version (from "latest" or a pinned value), compare with what's
# installed, and (re-)download the matching tarball if needed.
#
# Archive layout (upstream inful/docbuilder):
#   v0.14.1 - v0.15.1 : bundled inside the main docbuilder tarball
#   v0.15.2+          : its own docbuilder-mcp_linux_<arch>.tar.gz
update_docbuilder_mcp_if_needed() {
    if [ "$INSTALL_MCP_REQUESTED" != "true" ]; then
        return 0
    fi

    local target_version
    if [ "$DOCBUILDER_VERSION_REQUESTED" = "latest" ]; then
        target_version=$(resolve_latest_docbuilder || true)
        if [ -z "$target_version" ]; then
            print_info "Could not resolve latest docbuilder version; skipping docbuilder-mcp update."
            return 0
        fi
    else
        target_version="$DOCBUILDER_VERSION_REQUESTED"
    fi

    local current
    current=$(installed_docbuilder_mcp_version)
    if [ -n "$current" ] && [ "$current" = "$target_version" ]; then
        print_info "docbuilder-mcp is up-to-date (v$target_version)."
        return 0
    fi

    local arch
    arch=$(detect_architecture) || return 0

    print_info "Installing docbuilder-mcp: ${current:-not installed} -> v$target_version (${arch})"

    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    local mcp_url="https://github.com/inful/docbuilder/releases/download/v${target_version}/docbuilder-mcp_linux_${arch}.tar.gz"
    local main_url="https://github.com/inful/docbuilder/releases/download/v${target_version}/docbuilder_linux_${arch}.tar.gz"
    local mcp_binary=""

    # Primary path: dedicated MCP tarball (v0.15.2+).
    if download "$mcp_url" "$temp_dir/mcp.tar.gz" \
        && [ -s "$temp_dir/mcp.tar.gz" ] \
        && tar -xzf "$temp_dir/mcp.tar.gz" -C "$temp_dir" 2>/dev/null; then
        mcp_binary=$(find "$temp_dir" -maxdepth 1 -type f -name "docbuilder-mcp" || true)
    fi

    # Fallback: extract from the main tarball (v0.14.1 - v0.15.1).
    if [ -z "$mcp_binary" ]; then
        if download "$main_url" "$temp_dir/docbuilder.tar.gz" \
            && [ -s "$temp_dir/docbuilder.tar.gz" ] \
            && tar -xzf "$temp_dir/docbuilder.tar.gz" -C "$temp_dir" 2>/dev/null; then
            mcp_binary=$(find "$temp_dir" -maxdepth 1 -type f -name "docbuilder-mcp" || true)
        fi
    fi

    if [ -z "$mcp_binary" ]; then
        print_info "docbuilder-mcp binary not found in v${target_version} archives; skipping."
        return 0
    fi

    sudo -E mv "$mcp_binary" "$INSTALL_DIR/docbuilder-mcp"
    sudo -E chmod +x "$INSTALL_DIR/docbuilder-mcp"

    print_info "docbuilder-mcp ready: $($INSTALL_DIR/docbuilder-mcp --version 2>/dev/null | head -n1 || echo "unknown")"
}

main() {
    update_docbuilder_if_needed
    update_docbuilder_mcp_if_needed
    update_hugo_if_needed
}

main "$@"
