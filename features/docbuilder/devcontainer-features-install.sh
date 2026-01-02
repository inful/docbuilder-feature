#!/bin/bash
# Wrapper script for devcontainer features
# This reads feature options from devcontainer-features.env and makes them available to install.sh

set -e

# Source the devcontainer-features.env file which contains the feature options
# This file is created by devcontainers CLI with the values from devcontainer.json
if [ -f "devcontainer-features.env" ]; then
    # shellcheck source=/dev/null
    source ./devcontainer-features.env
    
    # Export all sourced variables so they're available to the called script
    export HTTPPROXY HTTPSPROXY DOCBUILDERVERSION HUGOVERSION
    
    echo "DEBUG: After sourcing devcontainer-features.env:"
    echo "DEBUG: HTTPPROXY=$HTTPPROXY"
    echo "DEBUG: HTTPSPROXY=$HTTPSPROXY"
    echo "DEBUG: DOCBUILDERVERSION=$DOCBUILDERVERSION"
    echo "DEBUG: HUGOVERSION=$HUGOVERSION"
else
    echo "DEBUG: devcontainer-features.env not found!"
fi

# Call the actual installer with the variables available
exec "$(dirname "$0")/install.sh"
