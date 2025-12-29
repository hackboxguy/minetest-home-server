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

# Start the Luanti server
echo "Starting Luanti server with game: $GAME_TO_PLAY"
/luanti/luanti/bin/luantiserver \
  --config /luanti/luanti/config/luanti.conf \
  --gameid "$GAME_TO_PLAY" \
  --worldname world

# Check if the server started successfully
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start Luanti server."
  exit 1
fi
