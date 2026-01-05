#!/bin/bash
#
# Luanti Server Startup Script
# Starts all game servers and mtui with proper SQLite WAL mode
#
# Usage:
#   ./tools/start-servers.sh                    # Start with existing password
#   ADMIN_PASSWORD=secret ./tools/start-servers.sh  # Start with new password
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to enable WAL mode on a world's databases
enable_wal_mode() {
    local world_name="$1"
    local world_dir="worlds/$world_name"

    if [ ! -d "$world_dir" ]; then
        log_warn "World directory $world_dir does not exist yet"
        return 1
    fi

    log_info "Enabling WAL mode for $world_name..."

    docker run --rm -v "$(pwd)/$world_dir:/data" alpine sh -c "
        apk add --no-cache sqlite >/dev/null 2>&1
        for db in /data/*.sqlite; do
            if [ -f \"\$db\" ]; then
                sqlite3 \"\$db\" 'PRAGMA journal_mode=WAL;' >/dev/null 2>&1
                echo \"  WAL enabled: \$(basename \$db)\"
            fi
        done
    " 2>/dev/null || log_warn "Could not enable WAL for $world_name (databases may not exist yet)"
}

# Function to check if databases need WAL mode
check_wal_needed() {
    local world_name="$1"
    local world_dir="worlds/$world_name"

    if [ ! -f "$world_dir/map.sqlite" ]; then
        return 0  # No databases yet, will need WAL after creation
    fi

    # Check if WAL mode is already enabled
    local mode=$(docker run --rm -v "$(pwd)/$world_dir:/data" alpine sh -c "
        apk add --no-cache sqlite >/dev/null 2>&1
        sqlite3 /data/map.sqlite 'PRAGMA journal_mode;'
    " 2>/dev/null)

    if [ "$mode" = "wal" ]; then
        return 1  # WAL already enabled
    fi
    return 0  # WAL not enabled
}

log_info "Starting Luanti servers..."

# Check if this is a fresh start (no worlds exist)
FRESH_START=false
if [ ! -d "worlds/mineclonia" ] || [ ! -f "worlds/mineclonia/map.sqlite" ]; then
    FRESH_START=true
    log_info "Fresh start detected - worlds will be created"
fi

# Start containers
log_info "Starting Docker containers..."
if [ -n "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD="$ADMIN_PASSWORD" docker-compose -f docker-compose.offline.yml up -d
else
    docker-compose -f docker-compose.offline.yml up -d
fi

# If fresh start, wait for databases to be created, then enable WAL
if [ "$FRESH_START" = true ]; then
    log_info "Waiting for world databases to be created (30 seconds)..."
    sleep 30

    # Stop game servers to enable WAL
    log_info "Stopping game servers to enable WAL mode..."
    docker-compose -f docker-compose.offline.yml stop mineclonia voxelibre
    sleep 2

    # Enable WAL mode for both worlds
    enable_wal_mode "mineclonia"
    enable_wal_mode "voxelibre"

    # Restart everything
    log_info "Restarting all containers..."
    docker-compose -f docker-compose.offline.yml up -d
    sleep 5
else
    # Check if WAL needs to be enabled (e.g., databases exist but WAL not set)
    NEED_WAL=false

    if check_wal_needed "mineclonia"; then
        NEED_WAL=true
    fi
    if check_wal_needed "voxelibre"; then
        NEED_WAL=true
    fi

    if [ "$NEED_WAL" = true ]; then
        log_info "WAL mode not enabled - stopping servers to configure..."
        docker-compose -f docker-compose.offline.yml stop mineclonia voxelibre
        sleep 2

        enable_wal_mode "mineclonia"
        enable_wal_mode "voxelibre"

        log_info "Restarting all containers..."
        docker-compose -f docker-compose.offline.yml up -d
        sleep 5
    fi
fi

# Wait for mtui to be ready
log_info "Waiting for services to be ready..."
sleep 10

# Show status
log_info "Container status:"
docker-compose -f docker-compose.offline.yml ps

echo ""
log_info "Servers are ready!"
echo ""
echo "  Mineclonia game:  localhost:30000"
echo "  VoxeLibre game:   localhost:30001"
echo "  Mineclonia admin: http://localhost:8000"
echo "  VoxeLibre admin:  http://localhost:8001"
echo ""
