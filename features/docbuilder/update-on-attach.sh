#!/bin/bash
set -e

# Drop inherited SSL_CERT_FILE / CURL_CA_BUNDLE so they cannot poison
# curl's TLS handling (see the long rationale in install.sh's
# ensure_ca_bundle()). We unset here at the top level (parent shell
# scope) because the unset inside ensure_ca_bundle() only affects the
# function's subshell and does not propagate to subsequent curl calls.
unset SSL_CERT_FILE CURL_CA_BUNDLE

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

# ----------------------------------------------------------------------------
# TLS / certificate fixup.
#
# Mirrors ensure_ca_bundle() in install.sh. Locates a usable trust store
# (cert directory preferred over bundle file) and configures curl accordingly.
# SSL_CERT_FILE / CURL_CA_BUNDLE env vars are explicitly dropped — see the
# long-form rationale in install.sh (briefly: the env var path can silently
# stall curl on certain curl+OpenSSL builds, and the bundle file can be
# unreadable even when bash's [ -s -r ] test passes).
# ----------------------------------------------------------------------------
ensure_ca_bundle() {
    local bundle=""
    local capath=""
    local candidate

    unset SSL_CERT_FILE CURL_CA_BUNDLE

    # Prefer a CA *directory* — openssl's hashed directory store is more
    # robust than a single concatenated bundle file, which some images
    # ship corrupt.
    for candidate in \
        /etc/ssl/certs \
        /etc/pki/tls/certs \
        /etc/pki/ca-trust/extracted/pem ; do
        if [ -d "$candidate" ] && [ -r "$candidate" ] \
            && ls "$candidate"/*.0 >/dev/null 2>&1; then
            capath="$candidate"
            break
        fi
    done

    for candidate in \
        /etc/ssl/certs/ca-certificates.crt \
        /etc/pki/tls/certs/ca-bundle.crt \
        /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
        /etc/ssl/ca-bundle.pem \
        /etc/ssl/cert.pem ; do
        if [ -s "$candidate" ] && [ -r "$candidate" ] \
            && head -c 27 "$candidate" 2>/dev/null | grep -q "BEGIN CERT"; then
            bundle="$candidate"
            break
        fi
    done

    # If we found neither, attempt to install ca-certificates.
    if [ -z "$capath" ] && [ -z "$bundle" ]; then
        print_info "No CA trust store found; attempting to install ca-certificates..."
        local pm
        if command -v apt-get >/dev/null 2>&1; then
            pm=apt-get
        elif command -v dnf >/dev/null 2>&1; then
            pm=dnf
        elif command -v microdnf >/dev/null 2>&1; then
            pm=microdnf
        elif command -v yum >/dev/null 2>&1; then
            pm=yum
        elif command -v apk >/dev/null 2>&1; then
            pm=apk
        fi

        case "$pm" in
            apt-get)
                sudo -E apt-get update -qq >/dev/null 2>&1 || true
                sudo -E apt-get install -y -qq ca-certificates >/dev/null 2>&1 || true
                ;;
            dnf|yum)
                sudo -E "$pm" install -y ca-certificates >/dev/null 2>&1 || true
                ;;
            microdnf)
                sudo -E microdnf install -y ca-certificates >/dev/null 2>&1 || true
                ;;
            apk)
                sudo -E apk add --no-cache ca-certificates >/dev/null 2>&1 || true
                ;;
        esac

        for candidate in \
            /etc/ssl/certs \
            /etc/pki/tls/certs \
            /etc/pki/ca-trust/extracted/pem ; do
            if [ -d "$candidate" ] && [ -r "$candidate" ] \
                && ls "$candidate"/*.0 >/dev/null 2>&1; then
                capath="$candidate"
                break
            fi
        done

        for candidate in \
            /etc/ssl/certs/ca-certificates.crt \
            /etc/pki/tls/certs/ca-bundle.crt \
            /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
            /etc/ssl/ca-bundle.pem \
            /etc/ssl/cert.pem ; do
            if [ -s "$candidate" ] && [ -r "$candidate" ] \
                && head -c 27 "$candidate" 2>/dev/null | grep -q "BEGIN CERT"; then
                bundle="$candidate"
                break
            fi
        done
    fi

    # After detecting capath (and optionally bundle), build a fresh CA
    # bundle in /tmp by concatenating the hashed cert files. Sidesteps
    # any tampering / corruption of the system-installed bundle file
    # (which bit us in 0.5.5 / 0.5.6 / 0.5.7).
    if [ -n "$capath" ]; then
        local fresh="/tmp/docbuilder-ca-bundle-$$.crt"
        rm -f "$fresh"
        local count=0
        while IFS= read -r cert_file; do
            if [ -r "$cert_file" ] \
                && head -c 27 "$cert_file" 2>/dev/null | grep -q "BEGIN CERT"; then
                cat "$cert_file" >> "$fresh" 2>/dev/null \
                    && count=$((count + 1))
            fi
        done < <(find -L "$capath" -maxdepth 1 -type f \( -name "*.0" -o -name "*.pem" \) 2>/dev/null)

        if [ -s "$fresh" ] \
            && head -c 27 "$fresh" 2>/dev/null | grep -q "BEGIN CERT" \
            && tail -c 27 "$fresh" 2>/dev/null | grep -q "END CERT"; then
            print_info "Built fresh CA bundle from $capath ($count certs) at $fresh"
            bundle="$fresh"
            export SSL_CERT_FILE="$fresh"
            export CURL_CA_BUNDLE="$fresh"
        else
            rm -f "$fresh"
            print_info "Could not build fresh bundle from $capath; falling back to system bundle"
        fi
    fi

    if [ -n "$capath" ]; then
        print_info "Using CA directory: $capath"
        CURL_OPTS="$CURL_OPTS --capath $capath"
    fi

    if [ -n "$bundle" ]; then
        print_info "Using CA bundle: $bundle"
        # Always pass --cacert: with the fresh bundle we just built, or
        # the validated system bundle if that's what we have.
        CURL_OPTS="$CURL_OPTS --cacert $bundle"
    fi

    if [ -z "$capath" ] && [ -z "$bundle" ]; then
        print_info "Could not provision a CA trust store; curl will rely on OpenSSL compiled-in defaults"
    fi
}

# ----------------------------------------------------------------------------
# HTTPS downloaders (Node-first, curl-fallback).
# Mirrors install.sh. Node bundles its own Mozilla CA store, immune to
# /etc/ssl/certs issues in stripped base images.
# ----------------------------------------------------------------------------
node_fetch() {
    local mode="$1"
    local url="$2"
    local dest="${3:-}"

    command -v node >/dev/null 2>&1 || return 1

    node --no-warnings -e '
        const http = require("http");
        const https = require("https");
        const { URL } = require("url");
        const fs = require("fs");
        const [mode, urlStr, dest] = process.argv.slice(1);
        // GitHub (and most REST APIs) reject requests without a User-Agent
        // header with HTTP 403. curl sends `curl/<version>` by default;
        // Node does not. Set one explicitly.
        const USER_AGENT = "docbuilder-feature-installer/0.5.7";
        const seen = new Set();
        function follow(u) {
            if (seen.has(u)) throw new Error("redirect loop at " + u);
            seen.add(u);
            const lib = u.startsWith("https") ? https : http;
            return new Promise((resolve, reject) => {
                lib.get(u, (res) => {
                    if ([301,302,303,307,308].includes(res.statusCode)) {
                        res.resume();
                        if (!res.headers.location) return reject(new Error("missing Location"));
                        follow(new URL(res.headers.location, u).toString()).then(resolve, reject);
                    } else if (res.statusCode !== 200) {
                        res.resume();
                        reject(new Error("HTTP " + res.statusCode + " from " + u));
                    } else {
                        const chunks = [];
                        res.on("data", (c) => chunks.push(c));
                        res.on("end", () => resolve(Buffer.concat(chunks)));
                        res.on("error", reject);
                    }
                }).on("error", reject);
            });
        }
        (async () => {
            try {
                const buf = await follow(urlStr);
                if (mode === "file") fs.writeFileSync(dest, buf);
                else process.stdout.write(buf);
            } catch (e) {
                console.error(e.message);
                process.exit(2);
            }
        })();
    ' "$mode" "$url" "$dest"
}

download() {
    local url="$1" dest="$2"
    if node_fetch file "$url" "$dest"; then
        return 0
    fi
    print_info "Falling back to curl for $url"
    env -u SSL_CERT_FILE -u CURL_CA_BUNDLE \
        curl $CURL_OPTS "$url" -o "$dest"
}

fetch_text() {
    local url="$1" captured
    if captured=$(node_fetch text "$url"); then
        printf '%s' "$captured"
        return 0
    fi
    print_info "Node fetch_text failed for $url; falling back to curl"
    env -u SSL_CERT_FILE -u CURL_CA_BUNDLE \
        curl $CURL_OPTS "$url"
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
    fetch_text "https://api.github.com/repos/inful/docbuilder/releases/latest" \
        | grep -oP '"tag_name":\s*"v?\K[0-9.]+'
}

resolve_latest_hugo() {
    fetch_text "https://api.github.com/repos/gohugoio/hugo/releases/latest" \
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
    # Resolve a usable CA bundle before any download. Host env vars that
    # point at nonexistent paths would otherwise break every curl call.
    ensure_ca_bundle
    update_docbuilder_if_needed
    update_docbuilder_mcp_if_needed
    update_hugo_if_needed
}

main "$@"
