#!/usr/bin/env zsh

set -euo pipefail

echo "Formatting QML files..."

find . \
    -path "./DankMaterialShell" -prune -o \
    -path "./noctalia-shell" -prune -o \
    -name "*.qml" -print0 | while IFS= read -r -d '' file; do
        qmlformat -i "$file"
done

echo "Formatting completed successfully."
