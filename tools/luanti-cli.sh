#!/bin/bash
#
# Luanti CLI - Execute commands on Luanti server via mtui API
#
# Usage:
#   ./luanti-cli.sh --url=http://localhost:8000 --user=admin --password=secret --command="/beacon red"
#   ./luanti-cli.sh --url=http://localhost:8000 --user=admin --password=secret --batch=commands.txt
#
# Batch file format (one command per line, # for comments):
#   # Place treasure hunt markers
#   /placemarker 100 65 200 red
#   /placetext 100 66 200 Start Here!
#   /beacon blue
#

set -e

# Default values
MTUI_URL="${MTUI_URL:-http://localhost:8000}"
MTUI_USER="${MTUI_USER:-admin}"
MTUI_PASSWORD="${MTUI_PASSWORD:-}"
COOKIE_FILE="/tmp/luanti-cli-cookies-$$.txt"
COMMAND=""
BATCH_FILE=""
VERBOSE=0
DELAY=0.5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Luanti CLI - Execute commands on Luanti server via mtui API"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --url=URL          mtui URL (default: \$MTUI_URL or http://localhost:8000)"
    echo "  --user=USER        Admin username (default: \$MTUI_USER or admin)"
    echo "  --password=PASS    Admin password (default: \$MTUI_PASSWORD)"
    echo "  --command=CMD      Single command to execute (e.g., '/beacon red')"
    echo "  --batch=FILE       Batch file with commands (one per line)"
    echo "  --delay=SECONDS    Delay between batch commands (default: 0.5)"
    echo "  --verbose          Show detailed output"
    echo "  --help             Show this help"
    echo ""
    echo "Environment variables:"
    echo "  MTUI_URL           Default mtui URL"
    echo "  MTUI_USER          Default username"
    echo "  MTUI_PASSWORD      Default password"
    echo ""
    echo "Examples:"
    echo "  # Single command"
    echo "  $0 --url=http://192.168.1.100:8000 --user=admin --password=secret --command='/beacon red'"
    echo ""
    echo "  # Batch file"
    echo "  $0 --password=secret --batch=treasure-hunt.txt"
    echo ""
    echo "Batch file format:"
    echo "  # Comments start with #"
    echo "  /placemarker 100 65 200 red"
    echo "  /placetext Start Here!"
    echo "  /beacon blue"
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1"
    fi
}

cleanup() {
    rm -f "$COOKIE_FILE"
}

trap cleanup EXIT

# Parse arguments
for arg in "$@"; do
    case $arg in
        --url=*)
            MTUI_URL="${arg#*=}"
            ;;
        --user=*)
            MTUI_USER="${arg#*=}"
            ;;
        --password=*)
            MTUI_PASSWORD="${arg#*=}"
            ;;
        --command=*)
            COMMAND="${arg#*=}"
            ;;
        --batch=*)
            BATCH_FILE="${arg#*=}"
            ;;
        --delay=*)
            DELAY="${arg#*=}"
            ;;
        --verbose)
            VERBOSE=1
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $arg"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$MTUI_PASSWORD" ]; then
    log_error "Password is required. Use --password=... or set MTUI_PASSWORD"
    exit 1
fi

if [ -z "$COMMAND" ] && [ -z "$BATCH_FILE" ]; then
    log_error "Either --command or --batch is required"
    usage
fi

if [ -n "$BATCH_FILE" ] && [ ! -f "$BATCH_FILE" ]; then
    log_error "Batch file not found: $BATCH_FILE"
    exit 1
fi

# Login to mtui
login() {
    log_info "Logging in to $MTUI_URL as $MTUI_USER..."

    local response
    response=$(curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$MTUI_USER\",\"password\":\"$MTUI_PASSWORD\"}" \
        "$MTUI_URL/api/login" 2>&1)

    log_verbose "Login response: $response"

    # Check if login was successful (response contains username)
    if echo "$response" | grep -q "\"username\""; then
        log_info "Login successful"
        return 0
    else
        log_error "Login failed: $response"
        return 1
    fi
}

# Execute a single command
execute_command() {
    local cmd="$1"

    # Remove leading slash if present (mtui adds it)
    cmd="${cmd#/}"

    log_verbose "Executing: /$cmd"

    local response
    response=$(curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"command\":\"$cmd\"}" \
        "$MTUI_URL/api/bridge/execute_chatcommand" 2>&1)

    log_verbose "Response: $response"

    # Parse response
    local success
    local message
    success=$(echo "$response" | grep -o '"success":[^,}]*' | cut -d':' -f2)
    message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)

    if [ "$success" = "true" ]; then
        log_info "/$cmd -> $message"
        return 0
    else
        log_error "/$cmd -> FAILED: $message"
        return 1
    fi
}

# Execute commands from batch file
execute_batch() {
    local file="$1"
    local line_num=0
    local success_count=0
    local fail_count=0

    log_info "Processing batch file: $file"

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # Skip empty lines and comments
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            continue
        fi

        # Execute command
        if execute_command "$line"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi

        # Delay between commands
        sleep "$DELAY"
    done < "$file"

    echo ""
    log_info "Batch complete: $success_count succeeded, $fail_count failed"
}

# Main
login || exit 1

if [ -n "$COMMAND" ]; then
    execute_command "$COMMAND"
elif [ -n "$BATCH_FILE" ]; then
    execute_batch "$BATCH_FILE"
fi
