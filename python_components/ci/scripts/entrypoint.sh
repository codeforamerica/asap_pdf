#!/bin/bash
set -e

# Install any local packages.
pip install python_components/evaluation

# Execute the main command
exec "$@"