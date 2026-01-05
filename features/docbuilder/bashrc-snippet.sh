#!/bin/bash
# Auto-start docbuilder preview
# This snippet is added to /etc/bash.bashrc when autoPreview is enabled

if [ -z "$DOCBUILDER_PREVIEW_STARTED" ]; then
    export DOCBUILDER_PREVIEW_STARTED=1
    
    # Check if docbuilder is available and workspace exists
    if command -v docbuilder > /dev/null 2>&1 && [ -d "/workspaces" ]; then
        # Check if docbuilder is already running
        if pgrep -f 'docbuilder preview' > /dev/null 2>&1; then
            echo "DocBuilder preview server is already running"
        else
            # Call the shared startup script
            /usr/local/share/docbuilder-preview.sh
        fi
    fi
fi
