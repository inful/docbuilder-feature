#!/bin/bash
# Auto-start docbuilder preview server
# This script is installed to /usr/local/share/docbuilder-preview.sh

# Configuration from feature options
DOCS_DIR="__DOCS_DIR__"
PREVIEW_PORT="__PREVIEW_PORT__"
LIVERELOAD_PORT="__LIVERELOAD_PORT__"
VERBOSE="__VERBOSE__"
VSCODE_LINKS="__VSCODE_LINKS__"

# Ensure Go is in PATH
export PATH=$PATH:/usr/local/go/bin

# Preserve VS Code IPC socket for edit links
if [ -n "$VSCODE_IPC_HOOK_CLI" ]; then
    export VSCODE_IPC_HOOK_CLI
fi

# Find the workspace directory (typically /workspaces/*)
for ws_dir in /workspaces/*; do
    if [ -d "$ws_dir" ]; then
        cd "$ws_dir" || continue
        
        # Create docs directory if it doesn't exist
        [ ! -d "$DOCS_DIR" ] && mkdir -p "$DOCS_DIR"
        
        # Check if docbuilder is available
        if ! command -v docbuilder > /dev/null 2>&1; then
            echo "docbuilder not found in PATH" >&2
            exit 1
        fi
        
        # Build command with options
        CMD="docbuilder preview --docs-dir $DOCS_DIR --port $PREVIEW_PORT"
        [ "$LIVERELOAD_PORT" != "0" ] && CMD="$CMD --livereload-port $LIVERELOAD_PORT"
        [ "$VERBOSE" = "true" ] && CMD="$CMD --verbose"
        [ "$VSCODE_LINKS" = "true" ] && CMD="$CMD --vscode"
        
        # Check if already running
        if pgrep -f 'docbuilder preview' > /dev/null 2>&1; then
            echo "DocBuilder preview server is already running"
            exit 0
        fi
        
        # Run in background, properly daemonized with setsid
        # This ensures the process survives when the parent shell exits
        setsid bash -c "
            export PATH=\$PATH:/usr/local/go/bin
            export VSCODE_IPC_HOOK_CLI='$VSCODE_IPC_HOOK_CLI'
            cd '$ws_dir'
            exec $CMD > /tmp/docbuilder-preview.log 2>&1
        " </dev/null >/dev/null 2>&1 &
        
        # Give it a moment to start
        sleep 1
        
        # Verify it started
        if pgrep -f 'docbuilder preview' > /dev/null 2>&1; then
            echo "DocBuilder preview server started in $ws_dir. Logs: /tmp/docbuilder-preview.log"
        else
            echo "Failed to start DocBuilder preview server. Check logs: /tmp/docbuilder-preview.log" >&2
            exit 1
        fi
        exit 0
    fi
done

echo "No workspace directory found in /workspaces" >&2
exit 1
