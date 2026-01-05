#!/bin/bash
#
# Luanti Server Stop Script
# Gracefully stops all game servers and mtui
#
# Usage:
#   ./tools/stop-servers.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "[INFO] Stopping Luanti servers..."
docker-compose -f docker-compose.offline.yml down

echo "[INFO] All servers stopped."
