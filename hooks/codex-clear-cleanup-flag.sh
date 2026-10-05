#!/bin/sh

PROJECT_DIR=$(pwd -P) || exit 0
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')
rm -f "${TMPDIR:-/tmp}/instruction-health-codex-cleanup-${PROJECT_KEY}.flag"
exit 0
