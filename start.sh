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

# Convert string seeds to numeric (Luanti requires numeric seeds)
# If GAME_SEED is not a number, hash it to create a numeric seed
if [ -n "$GAME_SEED" ]; then
  case "$GAME_SEED" in
    ''|*[!0-9-]*)
      # Contains non-numeric characters, hash it
      ORIGINAL_SEED="$GAME_SEED"
      GAME_SEED=$(echo -n "$GAME_SEED" | md5sum | tr -d -c '0-9' | head -c 9)
      echo "Converted string seed '$ORIGINAL_SEED' to numeric seed: $GAME_SEED"
      ;;
  esac

  # Set seed in config file (this is where Luanti actually reads it from)
  CONFIG_FILE="/luanti/luanti/config/luanti.conf"
  if grep -q "^fixed_map_seed" "$CONFIG_FILE"; then
    sed -i "s/^fixed_map_seed.*/fixed_map_seed = $GAME_SEED/" "$CONFIG_FILE"
    echo "Updated fixed_map_seed in config to: $GAME_SEED"
  else
    echo "fixed_map_seed = $GAME_SEED" >> "$CONFIG_FILE"
    echo "Added fixed_map_seed to config: $GAME_SEED"
  fi
fi

# Ensure world directory exists
WORLD_DIR="/luanti/luanti/worlds/world"
mkdir -p "$WORLD_DIR"

# Ensure required mods and settings are in world.mt
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
  # mtui mod - enables online players, chat, and shell features in web admin
  if ! grep -q "load_mod_mtui" "$WORLD_MT"; then
    echo "load_mod_mtui = true" >> "$WORLD_MT"
    echo "Enabled mtui mod in existing world.mt"
  fi
  # quest_helper mod - admin commands for treasure hunts and quests
  if ! grep -q "load_mod_quest_helper" "$WORLD_MT"; then
    echo "load_mod_quest_helper = true" >> "$WORLD_MT"
    echo "Enabled quest_helper mod in existing world.mt"
  fi
  # Ensure sqlite3 backends for mtui compatibility
  # Luanti will auto-migrate from files to sqlite3 on first startup
  if grep -q "auth_backend = files" "$WORLD_MT"; then
    sed -i 's/auth_backend = files/auth_backend = sqlite3/' "$WORLD_MT"
    echo "Migrated auth_backend from files to sqlite3 for mtui compatibility"
  elif ! grep -q "auth_backend" "$WORLD_MT"; then
    echo "auth_backend = sqlite3" >> "$WORLD_MT"
    echo "Set auth_backend to sqlite3 for mtui compatibility"
  fi
  if grep -q "player_backend = files" "$WORLD_MT"; then
    sed -i 's/player_backend = files/player_backend = sqlite3/' "$WORLD_MT"
    echo "Migrated player_backend from files to sqlite3 for mtui compatibility"
  elif ! grep -q "player_backend" "$WORLD_MT"; then
    echo "player_backend = sqlite3" >> "$WORLD_MT"
    echo "Set player_backend to sqlite3 for mtui compatibility"
  fi
  # Ensure mod_storage uses sqlite3 backend for mtui compatibility
  if ! grep -q "mod_storage_backend" "$WORLD_MT"; then
    echo "mod_storage_backend = sqlite3" >> "$WORLD_MT"
    echo "Set mod_storage_backend to sqlite3 for mtui compatibility"
  fi
else
  # Create initial world.mt with required settings
  cat > "$WORLD_MT" << EOF
gameid = $GAME_TO_PLAY
backend = sqlite3
auth_backend = sqlite3
player_backend = sqlite3
mod_storage_backend = sqlite3
load_mod_no_register = true
load_mod_admin_init = true
load_mod_mtui = true
load_mod_quest_helper = true
EOF
  echo "Created world.mt with required mods and sqlite3 backends enabled"

  # Add seed if GAME_SEED environment variable is set (only for new worlds)
  if [ -n "$GAME_SEED" ]; then
    echo "seed = $GAME_SEED" >> "$WORLD_MT"
    echo "Set world seed to: $GAME_SEED"
  fi
fi

# Handle seed update for existing worlds (only if explicitly requested)
# Note: Changing seed on existing world only affects newly generated chunks
if [ -n "$GAME_SEED" ] && [ -f "$WORLD_MT" ]; then
  if grep -q "^seed = " "$WORLD_MT"; then
    CURRENT_SEED=$(grep "^seed = " "$WORLD_MT" | cut -d'=' -f2 | tr -d ' ')
    if [ "$CURRENT_SEED" != "$GAME_SEED" ]; then
      echo "WARNING: World already has seed=$CURRENT_SEED, not changing to $GAME_SEED"
      echo "To change seed, delete the world or manually edit world.mt"
    fi
  else
    echo "seed = $GAME_SEED" >> "$WORLD_MT"
    echo "Added seed to existing world: $GAME_SEED (only affects new chunks)"
  fi
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
