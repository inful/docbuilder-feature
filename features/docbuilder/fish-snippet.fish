# Auto-start docbuilder preview
# This snippet is added to /etc/fish/conf.d/ when autoPreview is enabled

if not set -q DOCBUILDER_PREVIEW_STARTED
    set -gx DOCBUILDER_PREVIEW_STARTED 1
    
    # Check if docbuilder is available and workspace exists
    if command -v docbuilder > /dev/null 2>&1; and test -d "/workspaces"
        # Check if docbuilder is already running
        if not pgrep -f 'docbuilder preview' > /dev/null 2>&1
            # Call the shared startup script
            /usr/local/share/docbuilder-preview.sh
        else
            echo "DocBuilder preview server is already running"
        end
    end
end
