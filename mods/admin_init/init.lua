-- admin_init mod: Automatically creates/updates admin account from credentials file
-- Credentials file is created by start.sh from ADMIN_PASSWORD environment variable

local WORLD_PATH = minetest.get_worldpath()
local CREDS_FILE = WORLD_PATH .. "/.admin_credentials"

-- Read credentials file and setup admin account
local function setup_admin()
    local file = io.open(CREDS_FILE, "r")
    if not file then
        -- No credentials file, nothing to do
        minetest.log("action", "[admin_init] No credentials file found, skipping admin setup")
        return
    end

    -- Read username (first line) and password (second line)
    local username = file:read("*line")
    local password = file:read("*line")
    file:close()

    -- Validate credentials
    if not username or username == "" then
        minetest.log("error", "[admin_init] Invalid credentials file: missing username")
        os.remove(CREDS_FILE)
        return
    end
    if not password or password == "" then
        minetest.log("error", "[admin_init] Invalid credentials file: missing password")
        os.remove(CREDS_FILE)
        return
    end

    -- Trim whitespace
    username = username:match("^%s*(.-)%s*$")
    password = password:match("^%s*(.-)%s*$")

    minetest.log("action", "[admin_init] Setting up admin account: " .. username)

    -- Create password hash (required by the API)
    local password_hash = minetest.get_password_hash(username, password)

    -- Set password (this creates the account if it doesn't exist)
    minetest.set_player_password(username, password_hash)
    minetest.log("action", "[admin_init] Password set for: " .. username)

    -- Grant all registered privileges
    local privs = {}
    for priv_name, _ in pairs(minetest.registered_privileges) do
        privs[priv_name] = true
    end

    -- Set all privileges
    minetest.set_player_privs(username, privs)
    minetest.log("action", "[admin_init] Granted all privileges to: " .. username)

    -- Delete credentials file for security
    os.remove(CREDS_FILE)
    minetest.log("action", "[admin_init] Credentials file removed for security")
    minetest.log("action", "[admin_init] Admin setup complete!")
end

-- Run setup after all mods are loaded (so privileges are registered)
minetest.register_on_mods_loaded(function()
    -- Delay slightly to ensure everything is ready
    minetest.after(0.5, function()
        local status, err = pcall(setup_admin)
        if not status then
            minetest.log("error", "[admin_init] Error during setup: " .. tostring(err))
        end
    end)
end)

minetest.log("action", "[admin_init] Mod loaded, waiting for server startup to setup admin")
