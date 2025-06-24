#!/bin/bash

LOCAL_ACCESSIBILITY_SCAN_IMAGE='asap:accessibility_scan'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker build -t $LOCAL_ACCESSIBILITY_SCAN_IMAGE $SCRIPT_DIR/../.

docker run --rm --add-host host.docker.internal:host-gateway -v $SCRIPT_DIR/../:/workspace $LOCAL_ACCESSIBILITY_SCAN_IMAGE python main.py
