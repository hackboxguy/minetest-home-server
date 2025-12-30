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

# Ensure no_register mod is enabled in world.mt
# This runs on every startup to ensure the mod is always enabled
WORLD_MT="$WORLD_DIR/world.mt"
if [ -f "$WORLD_MT" ]; then
  # world.mt exists, check if mod is already enabled
  if ! grep -q "load_mod_no_register" "$WORLD_MT"; then
    echo "load_mod_no_register = true" >> "$WORLD_MT"
    echo "Enabled no_register mod in existing world.mt"
  fi
else
  # Create initial world.mt with required settings
  cat > "$WORLD_MT" << EOF
gameid = $GAME_TO_PLAY
load_mod_no_register = true
EOF
  echo "Created world.mt with no_register mod enabled"
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
