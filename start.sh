#!/bin/sh

# Luanti Server Start Script

# Check if GAME_TO_PLAY environment variable is set
if [ -z "$GAME_TO_PLAY" ]; then
  echo "ERROR: GAME_TO_PLAY environment variable is not set."
  echo "Please specify the game to play (e.g., mineclonia or voxelibre)."
  exit 1
fi

# Check if the configuration file exists
if [ ! -f "/luanti/luanti/config/luanti.conf" ]; then
  echo "ERROR: Configuration file not found at /luanti/luanti/config/luanti.conf."
  exit 1
fi

# Ensure world directory exists
WORLD_DIR="/luanti/luanti/worlds/world"
mkdir -p "$WORLD_DIR"

# Ensure required mods are enabled in world.mt
WORLD_MT="$WORLD_DIR/world.mt"
if [ -f "$WORLD_MT" ]; then
  # world.mt exists, add mods if not already enabled
  if ! grep -q "load_mod_no_register" "$WORLD_MT"; then
    echo "load_mod_no_register = true" >> "$WORLD_MT"
    echo "Enabled no_register mod in existing world.mt"
  fi
  if ! grep -q "load_mod_admin_init" "$WORLD_MT"; then
    echo "load_mod_admin_init = true" >> "$WORLD_MT"
    echo "Enabled admin_init mod in existing world.mt"
  fi
else
  # Create initial world.mt with required settings
  cat > "$WORLD_MT" << EOF
gameid = $GAME_TO_PLAY
load_mod_no_register = true
load_mod_admin_init = true
EOF
  echo "Created world.mt with required mods enabled"
fi

# Handle admin credentials from environment variables
# ADMIN_PASSWORD - required for admin setup (optional on restart)
# ADMIN_USER - optional, defaults to "admin"
ADMIN_CREDS_FILE="$WORLD_DIR/.admin_credentials"
if [ -n "$ADMIN_PASSWORD" ]; then
  ADMIN_USER="${ADMIN_USER:-admin}"
  echo "Setting up admin account: $ADMIN_USER"
  cat > "$ADMIN_CREDS_FILE" << EOF
$ADMIN_USER
$ADMIN_PASSWORD
EOF
  chmod 600 "$ADMIN_CREDS_FILE"
fi

# Start the Luanti server with terminal mode for interactive console
echo "Starting Luanti server with game: $GAME_TO_PLAY"
/luanti/luanti/bin/luantiserver \
  --config /luanti/luanti/config/luanti.conf \
  --gameid "$GAME_TO_PLAY" \
  --worldname world \
  --terminal

# Check if the server started successfully
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start Luanti server."
  exit 1
fi
