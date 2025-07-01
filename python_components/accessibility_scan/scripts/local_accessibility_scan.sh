#!/bin/bash

# Store the directory this script is in.
# This allows us to run the script consistently from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add an inference to our test document.
"$SCRIPT_DIR"/../../../bin/rake "documents:add_document_inference[302,exception:is_archival,True,Fee fi fo fum.]" >/dev/null

# Name of the image locally.
LOCAL_ACCESSIBILITY_SCAN_IMAGE="asap:accessibility_scan"

# Build the image if not cached.
docker build -t $LOCAL_ACCESSIBILITY_SCAN_IMAGE $SCRIPT_DIR/../.

# Run the scan and dump output to stdout.
docker run --rm --add-host host.docker.internal:host-gateway -v $SCRIPT_DIR/../:/workspace $LOCAL_ACCESSIBILITY_SCAN_IMAGE python main.py
