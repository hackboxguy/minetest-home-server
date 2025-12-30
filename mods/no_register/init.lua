-- no_register mod: Blocks new player registration
-- Players must be created via server console: /setpassword username password

local KICK_MESSAGE = "Registration is disabled on this server.\nPlease contact the server admin to create an account."

-- Use prejoinplayer to check if player exists in auth database
minetest.register_on_prejoinplayer(function(name, ip)
    local auth_handler = minetest.get_auth_handler()
    if auth_handler then
        local auth_data = auth_handler.get_auth(name)
        if not auth_data then
            -- Player doesn't exist in auth database = new registration attempt
            minetest.log("action", "[no_register] Blocked registration attempt from: " .. name .. " (" .. ip .. ")")
            return KICK_MESSAGE
        end
    end
    -- Player exists, allow them to proceed with login
    return nil
end)

minetest.log("action", "[no_register] Mod loaded - new player registration is disabled")
