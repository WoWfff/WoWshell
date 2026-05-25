#!/usr/bin/env zsh

set -euo pipefail

echo "Installing pre-commit hooks..."

pre-commit install

echo "Pre-commit hooks installed successfully."
