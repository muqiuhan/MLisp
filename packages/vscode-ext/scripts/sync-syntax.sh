#!/bin/bash
# Sync syntax files from shared package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shared is at ../../shared from scripts/
SHARED_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/shared"

# Ensure shared directory exists
if [ ! -d "$SHARED_DIR/syntax" ]; then
    echo "Error: Shared syntax directory not found at $SHARED_DIR/syntax"
    exit 1
fi

# Copy syntax files
echo "Syncing syntax files from shared package..."
cp "$SHARED_DIR/syntax/mlisp.tmLanguage.json" "$SCRIPT_DIR/../syntaxes/"
cp "$SHARED_DIR/syntax/language-configuration.json" "$SCRIPT_DIR/../"

echo "Syntax files synced successfully"
