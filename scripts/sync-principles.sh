#!/bin/sh
# Copy the core principles from an open-conduit checkout into the review playbook.
set -eu
src="${1:-../open-conduit}/site/src/content/docs/architecture/principles.md"
cp "$src" "$(dirname "$0")/../plugin/skills/review-pr/principles.md"
echo "copied $src"
