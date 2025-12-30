# Offline-Friendly Luanti Home Server (Mineclonia/VoxeLibre)

Run a self-hosted, Minecraft-like server for your family—entirely offline—using Docker. Ships Luanti 5.14 plus Mineclone-style games and curated mods/texture packs. One small PC/NAS runs the containers; kids connect from Linux/Windows with the Luanti client over your home LAN (no Microsoft/Mojang accounts or Internet needed).

![Offline Luanti home server diagram](images/luanti-game-server.png)

Included games:
- **Mineclonia** on port `30000`
- **VoxeLibre** on port `30001`

## Quick Start (Pre-built Image)

```bash
# Clone the repository
git clone https://github.com/hackboxguy/minetest-home-server.git
cd minetest-home-server

# Start the server with admin account setup (first-time deployment)
ADMIN_PASSWORD=yourpassword docker-compose up -d

# Or start without admin setup (if admin already exists)
docker-compose up -d
```

**Note:** The `ADMIN_PASSWORD` environment variable creates an admin account with all privileges. You can also specify a custom admin username with `ADMIN_USER=customname` (defaults to "admin").

## Build Locally (For Developers)

If you want to build the Docker image yourself:

```bash
# First-time deployment with admin setup
ADMIN_PASSWORD=yourpassword docker-compose -f docker-compose.build.yml up -d --build

# Or without admin setup
docker-compose -f docker-compose.build.yml up -d --build
```

After building locally, you can also run with the standard compose file by tagging:
```bash
docker tag luanti-home-server:latest hackboxguy/luanti-home-server:latest
docker-compose up -d
```

## Connecting to the Server

Players can connect using the Luanti client:
- `serverip:30000` for **Mineclonia**
- `serverip:30001` for **VoxeLibre**

Replace `serverip` with the actual IP address or domain name of your server.

## Server Administration

### Admin User Setup

The admin account is created automatically using environment variables:

```bash
# Create admin with default username "admin"
ADMIN_PASSWORD=yourpassword docker-compose up -d

# Create admin with custom username
ADMIN_USER=myadmin ADMIN_PASSWORD=yourpassword docker-compose up -d
```

The admin account is granted **all privileges** automatically, including: fly, noclip, teleport, kick, ban, creative, weather control, server management, and more.

**Re-running with `ADMIN_PASSWORD`** will update the admin password (useful if you forget it).

> **Note:** New user registration from the Luanti client is disabled by default. Only the admin can create new player accounts via the server console.

### Server Console Access

You can access the server console for administration:

```bash
# Attach to Mineclonia server console
docker attach luanti_mineclonia

# Attach to VoxeLibre server console
docker attach luanti_voxelibre
```

Type commands with `/` prefix (e.g., `/status`, `/grant player fly`).

Detach with `Ctrl+P` then `Ctrl+Q`.

### Creating New Player Accounts

Since client registration is disabled, use the server console to create accounts:

```bash
docker attach luanti_mineclonia
/setpassword playername playerpassword
```

Then grant basic privileges:
```
/grant playername interact
/grant playername shout
```

Or grant creative mode to specific players:
```
/grant playername creative
```

### Useful Admin Commands

| Command | Description |
|---------|-------------|
| `/status` | Show server status and online players |
| `/setpassword <player> <pass>` | Create account or change password |
| `/grant <player> <privilege>` | Grant privilege to player |
| `/revoke <player> <privilege>` | Revoke privilege from player |
| `/privs <player>` | Show player's privileges |
| `/teleport <player1> <player2>` | Teleport player1 to player2 |
| `/weather clear/rain/thunder` | Change weather |
| `/kick <player>` | Kick player from server |
| `/ban <player>` | Ban player from server |

## Security

### Registration Disabled by Default

New user registration from the Luanti client is **blocked by default** using the `no_register` mod. This prevents unauthorized players from creating accounts on your server.

**To create new player accounts**, use the server console:
```bash
docker attach luanti_mineclonia
/setpassword newplayer theirpassword
```

### Password Security

Empty passwords are not allowed (`disallow_empty_password = true` in config). All accounts must have a password set.

## Included Mods

### Server Management Mods
- **no_register** - Blocks new user registration from client (security)
- **admin_init** - Auto-creates admin account from environment variables

### Gameplay Mods
- **spectator_mode** - Spectate other players
- **animalia** - Wildlife/fauna
- **i3** - Inventory system
- **3d_armor** - Armor system
- **skinsdb** - Player skins
- **awards** - Achievement popups/goals
- **protector** - Plot protection
- **worldedit** - Admin building tools
- **travelnet** - Simple portals for hubs/bases
- **lootchests** - Surprise treasure drops
- **ambience** - Ambient sounds

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
