#!/bin/bash
set -e

# Install any local packages.
pip install python_components/evaluation
pip install python_components/document_inference

# Execute the main command
exec "$@"