#!/bin/bash
# Wrapper script for devcontainer features
# This reads feature options from devcontainer-features.env and makes them available to install.sh

set -e

echo "=================================================="
echo "WRAPPER: Starting devcontainer-features-install.sh"
echo "=================================================="
echo "WRAPPER: Current directory: $(pwd)"
echo "WRAPPER: Files in current directory:"
ls -la

# Source the devcontainer-features.env file which contains the feature options
# This file is created by devcontainers CLI with the values from devcontainer.json
if [ -f "devcontainer-features.env" ]; then
    echo "WRAPPER: Found devcontainer-features.env"
    echo "WRAPPER: Contents:"
    cat devcontainer-features.env
    set +e  # Don't exit on errors while sourcing
    source ./devcontainer-features.env
    set -e  # Re-enable exit on error
    echo "WRAPPER: Successfully sourced devcontainer-features.env"
    echo "WRAPPER: HTTPPROXY after sourcing: $HTTPPROXY"
    echo "WRAPPER: HTTPSPROXY after sourcing: $HTTPSPROXY"
else
    echo "WRAPPER: ERROR - devcontainer-features.env not found!"
    echo "WRAPPER: Files available:"
    find . -name "*.env"
fi

echo "=================================================="
echo "WRAPPER: Calling install.sh"
echo "=================================================="

# Now call the actual installer with the variables available
exec "$(dirname "$0")/install.sh"
