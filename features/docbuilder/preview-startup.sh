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
        
        # Run in background
        nohup $CMD > /tmp/docbuilder-preview.log 2>&1 &
        echo "DocBuilder preview server started in $ws_dir. Logs: /tmp/docbuilder-preview.log"
        exit 0
    fi
done

echo "No workspace directory found in /workspaces" >&2
exit 1
