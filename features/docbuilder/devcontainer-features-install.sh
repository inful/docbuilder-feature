#!/bin/bash
# Wrapper script for devcontainer features
# This reads feature options from devcontainer-features.env and makes them available to install.sh

set -e

# Source the devcontainer-features.env file which contains the feature options
# This file is created by devcontainers CLI with the values from devcontainer.json
if [ -f "devcontainer-features.env" ]; then
    set +e  # Don't exit on errors while sourcing
    source ./devcontainer-features.env
    set -e  # Re-enable exit on error
fi

# Now call the actual installer with the variables available
exec "$(dirname "$0")/install.sh"
