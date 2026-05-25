#!/usr/bin/env zsh

set -euo pipefail

echo "Running WoWshell validation pipeline..."

./scripts/lint.sh
./scripts/format.sh

echo "Validation completed successfully."
