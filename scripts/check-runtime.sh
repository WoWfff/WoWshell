#!/usr/bin/env zsh

set -euo pipefail

echo "Checking runtime dependencies..."

required_commands=(
    qs
    qmllint
    qmlformat
    pre-commit
)

for command in "${required_commands[@]}"; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing dependency: $command"
        exit 1
    fi
done

echo "Runtime dependencies verified successfully."
