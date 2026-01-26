#!/bin/bash
set -e

DOCBUILDER_VERSION_REQUESTED="__DOCBUILDER_VERSION_REQUESTED__"
HUGO_VERSION_REQUESTED="__HUGO_VERSION_REQUESTED__"
INSTALL_DIR="/usr/local/bin"
CURL_OPTS="-fSsL --connect-timeout 30 --max-time 120 --retry 2"

# Respect proxy environment variables if present.
# curl will automatically use http_proxy/https_proxy/no_proxy.

print_info() {
    echo "[docbuilder-feature] $*" >&2
}

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
    # shellcheck disable=SC2086
    curl $CURL_OPTS "https://api.github.com/repos/inful/docbuilder/releases/latest" \
        | grep -oP '"tag_name":\s*"v?\K[0-9.]+'
}

resolve_latest_hugo() {
    # shellcheck disable=SC2086
    curl $CURL_OPTS "https://api.github.com/repos/gohugoio/hugo/releases/latest" \
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
    # shellcheck disable=SC2086
    curl $CURL_OPTS "$url" -o "$temp_dir/docbuilder.tar.gz"
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
    # shellcheck disable=SC2086
    curl $CURL_OPTS "$url" -o "$temp_dir/hugo.tar.gz"
    tar -xzf "$temp_dir/hugo.tar.gz" -C "$temp_dir"

    if [ ! -f "$temp_dir/hugo" ]; then
        print_info "hugo binary not found in archive; skipping update."
        return 0
    fi

    sudo -E mv "$temp_dir/hugo" "$INSTALL_DIR/hugo"
    sudo -E chmod +x "$INSTALL_DIR/hugo"

    print_info "hugo updated to: $($INSTALL_DIR/hugo version 2>/dev/null | head -n1 || echo "unknown")"
}

main() {
    update_docbuilder_if_needed
    update_hugo_if_needed
}

main "$@"
