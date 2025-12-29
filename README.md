# A Self-Sufficient/Self-Hosted Luanti Home Server

This repository contains the necessary files to run a Docker container for **Luanti server** (formerly Minetest) that includes popular games, mods, and textures. The container runs Luanti 5.14 with the following games:

- **Mineclonia** on port `30000`
- **VoxeLibre** on port `30001`

## Quick Start (Pre-built Image)

```bash
# Clone the repository
git clone https://github.com/hackboxguy/minetest-home-server.git
cd minetest-home-server

# Start the server (pulls pre-built image from Docker Hub)
docker-compose up -d
```

## Build Locally (For Developers)

If you want to build the Docker image yourself:

```bash
docker-compose -f docker-compose.build.yml up -d --build
```

## Connecting to the Server

Players can connect using the Luanti client:
- `serverip:30000` for **Mineclonia**
- `serverip:30001` for **VoxeLibre**

Replace `serverip` with the actual IP address or domain name of your server.

## Server Administration

### Admin User Setup

1. After starting the server, connect with the Luanti client
2. Register the first user as **`admin`** and set a password
3. The admin user has full privileges including: fly, teleport, kick, ban, weather control, etc.

### Server Console Access

You can access the server console for administration:

```bash
# Attach to Mineclonia server console
docker attach luanti_mineclonia

# Attach to VoxeLibre server console
docker attach luanti_voxelibre
```

Type commands without `/` prefix (e.g., `status`, `grant player fly`).

Detach with `Ctrl+P` then `Ctrl+Q`.

### Useful Admin Commands

| Command | Description |
|---------|-------------|
| `status` | Show server status and online players |
| `grant <player> <privilege>` | Grant privilege to player |
| `revoke <player> <privilege>` | Revoke privilege from player |
| `privs <player>` | Show player's privileges |
| `teleport <player1> <player2>` | Teleport player1 to player2 |
| `weather clear/rain/thunder` | Change weather |
| `kick <player>` | Kick player from server |
| `ban <player>` | Ban player from server |

## Security

### Disable New Registrations

New user registration is disabled by default (`disallow_empty_password = true`). To allow new registrations, edit the config files and set it to `false`:

- `config/mineclonia.conf`
- `config/voxelibre.conf`

Then restart the server:
```bash
docker-compose restart
```

## Included Mods

- **spectator_mode** - Spectate other players
- **animalia** - Wildlife/fauna
- **i3** - Inventory system
- **3d_armor** - Armor system

## Included Texture Packs

- **Soothing 32** - 32x texture pack
- **RPG 16** - 16x texture pack
- **Less Dirt** - Texture adjustments

## Recommended for Families

This is an all-in-one setup ideal for families with kids who prefer to keep all players within the home network boundary(offline - disconnected from the Internet).

## Stopping the Server

```bash
docker-compose down
```

## Upgrading

To pull the latest version:

```bash
docker-compose pull
docker-compose up -d
```

Enjoy your Luanti gaming experience!
