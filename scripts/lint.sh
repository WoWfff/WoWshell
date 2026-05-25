#!/usr/bin/env zsh

set -euo pipefail

echo "Running qmllint..."

find . \
    -path "./DankMaterialShell" -prune -o \
    -path "./noctalia-shell" -prune -o \
    -name "*.qml" -print0 | xargs -0 qmllint

echo "qmllint completed successfully."
