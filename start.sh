#!/bin/sh

# Check if GAME_TO_PLAY environment variable is set
if [ -z "$GAME_TO_PLAY" ]; then
  echo "ERROR: GAME_TO_PLAY environment variable is not set."
  echo "Please specify the game to play (e.g., mineclonia or voxelibre)."
  exit 1
fi

# Check if the configuration file exists
if [ ! -f "/minetest/minetest/config/minetest.conf" ]; then
  echo "ERROR: Configuration file not found at /minetest/minetest/config/minetest.conf."
  exit 1
fi

# Start the Minetest server
echo "Starting Minetest server with game: $GAME_TO_PLAY"
/minetest/minetest/bin/luantiserver \
  --config /minetest/minetest/config/minetest.conf \
  --gameid "$GAME_TO_PLAY" \
  --worldname world

# Check if the server started successfully
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start Minetest server."
  exit 1
fi
