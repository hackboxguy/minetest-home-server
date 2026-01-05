# Offline-Friendly Luanti Home Server (Mineclonia/VoxeLibre)

Run a self-hosted, Minecraft-like server for your family—entirely offline—using Docker. Ships Luanti 5.14 plus Mineclone-style games and curated mods/texture packs. One small PC/NAS runs the containers; kids connect from Linux/Windows with the Luanti client over your home LAN (no Microsoft/Mojang accounts or Internet needed).

![Offline Luanti home server diagram](images/luanti-game-server.png)

Included games:
- **Mineclonia** on port `30000` (Web Admin: `http://serverip:8000`)
- **VoxeLibre** on port `30001` (Web Admin: `http://serverip:8001`)

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

Since client registration is disabled, you can create accounts via:

**Option 1: Web Admin (Recommended)**
1. Open `http://serverip:8000` (or `:8001` for VoxeLibre)
2. Log in with admin credentials
3. Navigate to account management to create new players

**Option 2: Server Console**
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

## Web Admin Interface (mtui)

Each game server includes a web-based admin panel powered by [mtui](https://github.com/minetest-go/mtui):

- **Mineclonia Admin:** `http://serverip:8000`
- **VoxeLibre Admin:** `http://serverip:8001`

### Features

- **Account Management** - Create, delete, and manage player accounts
- **Password Management** - Reset player passwords
- **Privilege Management** - Grant/revoke privileges via web UI
- **Live Chat** - Monitor and participate in server chat
- **Server Console** - Execute commands remotely
- **Player Banning** - Ban/unban players (XBan integration)
- **Skin Management** - Manage player skins
- **Mod Management** - View and configure installed mods

### Accessing the Web Admin

1. Open your browser and navigate to `http://serverip:8000` (Mineclonia) or `http://serverip:8001` (VoxeLibre)
2. Log in with your admin credentials (same as `ADMIN_USER`/`ADMIN_PASSWORD`)
3. Use the web interface to manage players, privileges, and server settings

### Custom Ports

You can customize the web admin ports using environment variables:

```bash
MTUI_PORT_MINECLONIA=9000 MTUI_PORT_VOXELIBRE=9001 docker-compose up -d
```

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
- **mtui** - Companion mod for mtui web admin (live chat, player stats)
- **quest_helper** - Admin commands for treasure hunts and quests (see below)

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

## Quest Helper Commands (For Parents/Admins)

The **quest_helper** mod provides admin commands for creating treasure hunts and fun activities for kids:

### Player Kits
| Command | Description |
|---------|-------------|
| `/starterkit <player>` | Give basic survival gear (iron tools, torches, food) |
| `/herokit <player>` | Give full diamond gear and supplies |
| `/questkit <player>` | Give exploration kit (compass, maps, tools) |

### Treasure Chests
| Command | Description |
|---------|-------------|
| `/treasure small` | Place chest with basic loot at your position |
| `/treasure medium` | Place chest with good loot (iron, gold, few diamonds) |
| `/treasure big` | Place chest with great loot (gold, diamonds, diamond tools) |
| `/treasure epic` | Place chest with amazing loot (diamond blocks, full armor) |
| `/treasure <x> <y\|~> <z> <tier>` | Place at coordinates (use `~` for auto ground level) |

### Puzzle Chests (Password Protected)
| Command | Description |
|---------|-------------|
| `/puzzlechest <tier> <question> \| <answer>` | Place puzzle chest at your position |
| `/puzzlechest <x> <y\|~> <z> <tier> <question> \| <answer>` | Place at coordinates |

**Puzzle Chest Tiers:**
| Tier | Appearance | Points | Timeout | Description |
|------|------------|--------|---------|-------------|
| `small` | Bronze/Iron | 10 | 45s | Easy puzzles, basic loot |
| `medium` | Gold | 25 | 60s | Medium puzzles, good loot |
| `big` | Blue | 50 | 90s | Hard puzzles, great loot |
| `epic` | Purple | 100 | 20s | Expert puzzles, amazing loot |

**Example:** `/puzzlechest medium What is 2+2? | four`

**Features:**
- Players must answer correctly to unlock the chest
- Case-insensitive answers with German umlaut support (ä→ae, ö→oe, ü→ue)
- Multiple valid answers supported (separated by `|` in answer)
- 3 attempts before the chest **explodes** (damages player, loot lost forever!)
- **Timeout system:** Once solved, players have limited time to collect items before chest vanishes
- Remaining items drop on ground when timeout expires
- Admins bypass the puzzle automatically
- Each player must solve independently
- Points awarded for solving (see Scoreboard below)

### Scatter Command (Mass Chest Placement)
| Command | Description |
|---------|-------------|
| `/scatter <radius> <count> [tier] [exposed]` | Scatter chests around your position |

**Examples:**
```bash
/scatter 50 5              # 5 random-tier chests within 50 blocks
/scatter 100 10 medium     # 10 medium chests within 100 blocks
/scatter 75 8 big exposed  # 8 big chests, prefer surface locations
```

**Modes:**
- Default: Prefers concealed locations (caves, overhangs)
- `exposed`: Prefers visible surface locations

### Chest Mode
| Command | Description |
|---------|-------------|
| `/chestmode [exposed\|concealed]` | Set default placement preference |

### Vanish Command
| Command | Description |
|---------|-------------|
| `/vanish [radius]` | Remove all puzzle chests within radius (default: 100) |

### Scoreboard & Leaderboard
| Command | Description |
|---------|-------------|
| `/leaderboard` | Show top players and scores |
| `/myscore` | Show your current score |
| `/hud [on\|off]` | Toggle scoreboard HUD display |
| `/resetscores` | Reset all player scores (admin only) |

Points are awarded when players solve puzzle chests (see tier table above).

### Random Questions from JSON
The mod can load questions from `tools/questions.json` for random puzzle generation:

| Command | Description |
|---------|-------------|
| `/reloadquestions` | Reload questions from JSON file |
| `/questionstats` | Show question usage statistics |
| `/resetquestions` | Reset question tracking (re-enable used questions) |

**Question file format:** See `tools/questions.json` for examples with categories (easy, medium, hard, expert) and hints.

### Beacons & Poles
| Command | Description |
|---------|-------------|
| `/beacon <color>` | Create tall glowing beacon at your position |
| `/beacon <x> <y\|~> <z> <color>` | Create beacon at coordinates |
| `/pole <color> <height>` | Create vertical pole of blocks |
| `/pole <x> <y\|~> <z> <color> <height>` | Create pole at coordinates |

**Colors:** red, blue, yellow, green, white, orange (beacons also: gold, diamond, glow for poles)

### Signs & Markers
| Command | Description |
|---------|-------------|
| `/placetext <text>` | Place sign with text at your position |
| `/placetext <x> <y> <z> <text>` | Place sign at coordinates |
| `/bigtext <text>` | Create large 3D floating text (visible from far away) |
| `/placemarker <color>` | Place colored wool (red, blue, yellow, green, orange, purple, white) |
| `/trail <color> <length> <n/s/e/w>` | Create trail of markers (e.g., `/trail red 10 n`) |

### Waypoints & Teleporting
| Command | Description |
|---------|-------------|
| `/savespot <name>` | Save current position as named waypoint |
| `/gospot <name>` | Teleport to saved waypoint |
| `/listspots` | List all saved waypoints |
| `/bringall` | Teleport all players to your position |

### Announcements
| Command | Description |
|---------|-------------|
| `/announce <message>` | Send highlighted message to all players |
| `/countdown <seconds> <message>` | Start countdown timer (e.g., `/countdown 10 GO!`) |

### Ground-Level Auto-Detection

Most placement commands support `~` for automatic ground-level detection:

```bash
# Place beacon at x=100, z=200, auto-detect Y (ground level)
/beacon 100 ~ 200 blue

# Place puzzle chest at ground level
/puzzlechest 50 ~ 25 medium What color is the sky? | blue
```

### Example: Setting Up a Treasure Hunt

```bash
# 1. Place a starting beacon at spawn (~ auto-detects ground)
/beacon 0 ~ 0 blue
/placetext 2 ~ 0 START HERE!|Follow the red|markers north!

# 2. Create a trail heading north
/trail 0 ~ -5 red 5 n

# 3. Place clue sign at end of trail
/placetext 0 ~ -25 CLUE 1|Look EAST for|the yellow beacon!

# 4. Place next beacon and puzzle chest
/beacon 50 ~ -25 yellow
/puzzlechest 52 ~ -25 epic What is Mom's favorite color? | purple

# 5. Give kids quest kits
/questkit kidname

# 6. Announce the hunt!
/announce A treasure hunt has begun! Start at the blue beacon!
```

**See also:** `tools/treasure-hunt-example.txt` for a complete batch script.

## Included Texture Packs

- **Soothing 32** - 32x texture pack
- **RPG 16** - 16x texture pack
- **Less Dirt** - Texture adjustments

## Performance Optimization

### Offline/LAN Mode (Optimized for Home Network)

For best performance when playing only on your home network, use the optimized offline configs:

```bash
# Stop current servers
docker-compose down

# Start with LAN-optimized settings
docker-compose -f docker-compose.offline.yml up -d
```

**LAN optimizations include:**
- Faster terrain loading (40 blocks/client vs 10)
- Higher network packet rates (2048 vs default)
- Faster world generation (2 threads)
- Smoother liquid physics
- Lower server tick time (50ms vs 100ms)

### Standard Mode (Internet Players)

For allowing players to join from the internet:

```bash
docker-compose up -d
```

### Client-Side Optimization Tips

These settings are configured on each player's Luanti client (not the server):

1. **Open Luanti Client → Settings → All Settings**

2. **For Better FPS:**
   - `viewing_range` = 100 (lower = better FPS)
   - `fps_max` = 60
   - `smooth_lighting` = false (better FPS)
   - `enable_particles` = false (better FPS)
   - `enable_3d_clouds` = false (better FPS)

3. **For Better Visuals:**
   - `viewing_range` = 300
   - `smooth_lighting` = true
   - `enable_particles` = true
   - `texture_min_size` = 64

4. **Recommended Balance:**
   - `viewing_range` = 150
   - `fps_max` = 60
   - `smooth_lighting` = true
   - `enable_particles` = true
   - `enable_3d_clouds` = false

## Recommended for Families

This is an all-in-one setup ideal for families with kids who prefer to keep all players within the home network boundary (offline - disconnected from the Internet).

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
