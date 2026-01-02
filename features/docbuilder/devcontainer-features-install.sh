#!/bin/bash
# Wrapper script for devcontainer features
# This reads feature options and passes them to the installer

set -e

# Feature options are passed as environment variables
# devcontainers CLI converts them to OPTION_NAME format
# But we need to make sure they're available to the install script

# Pass through all environment variables to the install script
export HTTPPROXY="${HTTPPROXY:-}"
export HTTPSPROXY="${HTTPSPROXY:-}"
export DOCBUILDERVERSION="${DOCBUILDERVERSION:-}"
export HUGOVERSION="${HUGOVERSION:-}"

# Call the actual installer
exec "$(dirname "$0")/install.sh"
