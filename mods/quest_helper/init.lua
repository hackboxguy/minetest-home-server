-- Quest Helper Mod
-- Admin commands for creating treasure hunts and quests

local storage = minetest.get_mod_storage()

-- Helper function to check if player has admin privs
local function is_admin(name)
    return minetest.check_player_privs(name, {server = true})
end

-- ============================================
-- SCOREBOARD SYSTEM
-- Track player points from solving puzzle chests
-- ============================================

-- Configuration
local SCOREBOARD_HUD_ENABLED = true  -- Set to false to disable HUD globally
local SCOREBOARD_TOP_COUNT = 5       -- Number of players to show on HUD

-- Point values by tier
local TIER_POINTS = {
    small = 10,
    medium = 25,
    big = 50,
    epic = 100,
}

-- Track HUD elements per player
local player_hud_ids = {}

-- Track current leader for change detection
local current_leader = nil

-- Get all scores from storage
local function get_all_scores()
    local scores_json = storage:get_string("player_scores")
    if scores_json == "" then
        return {}
    end
    return minetest.parse_json(scores_json) or {}
end

-- Save all scores to storage
local function save_all_scores(scores)
    storage:set_string("player_scores", minetest.write_json(scores))
end

-- Get a player's score
local function get_player_score(player_name)
    local scores = get_all_scores()
    return scores[player_name] or 0
end

-- Add points to a player's score (returns new total)
local function add_player_score(player_name, points)
    local scores = get_all_scores()
    scores[player_name] = (scores[player_name] or 0) + points
    save_all_scores(scores)
    return scores[player_name]
end

-- Get sorted leaderboard (array of {name, score} tables)
local function get_leaderboard(limit)
    local scores = get_all_scores()
    local leaderboard = {}

    for name, score in pairs(scores) do
        table.insert(leaderboard, {name = name, score = score})
    end

    -- Sort by score descending
    table.sort(leaderboard, function(a, b)
        return a.score > b.score
    end)

    -- Limit results
    if limit and #leaderboard > limit then
        local limited = {}
        for i = 1, limit do
            limited[i] = leaderboard[i]
        end
        return limited
    end

    return leaderboard
end

-- Get current leader name (or nil if no scores)
local function get_leader()
    local leaderboard = get_leaderboard(1)
    if #leaderboard > 0 and leaderboard[1].score > 0 then
        return leaderboard[1].name
    end
    return nil
end

-- Check for lead change and announce if needed
local function check_lead_change(player_name)
    local new_leader = get_leader()

    if new_leader and new_leader ~= current_leader then
        -- Lead has changed!
        local scores = get_all_scores()
        local points = scores[new_leader] or 0

        if current_leader then
            -- Someone took the lead from another player
            minetest.chat_send_all(minetest.colorize("#FFD700",
                "*** " .. new_leader .. " takes the lead with " .. points .. " points! ***"))
        else
            -- First leader established
            minetest.chat_send_all(minetest.colorize("#FFD700",
                "*** " .. new_leader .. " is in the lead with " .. points .. " points! ***"))
        end

        current_leader = new_leader
    end
end

-- Format leaderboard for HUD display
local function format_hud_leaderboard()
    local leaderboard = get_leaderboard(SCOREBOARD_TOP_COUNT)

    if #leaderboard == 0 then
        return "=== LEADERBOARD ===\nNo scores yet"
    end

    local lines = {"=== LEADERBOARD ==="}
    for i, entry in ipairs(leaderboard) do
        local medal = ""
        if i == 1 then medal = " [1st]"
        elseif i == 2 then medal = " [2nd]"
        elseif i == 3 then medal = " [3rd]"
        end
        table.insert(lines, i .. ". " .. entry.name .. " - " .. entry.score .. medal)
    end

    return table.concat(lines, "\n")
end

-- Update HUD for a specific player
local function update_player_hud(player)
    if not SCOREBOARD_HUD_ENABLED then return end
    if not player then return end

    local player_name = player:get_player_name()

    -- Check if player has HUD disabled
    local player_meta = player:get_meta()
    if player_meta:get_int("hud_disabled") == 1 then
        return
    end

    local hud_text = format_hud_leaderboard()

    if player_hud_ids[player_name] then
        -- Update existing HUD
        player:hud_change(player_hud_ids[player_name], "text", hud_text)
    else
        -- Create new HUD element
        player_hud_ids[player_name] = player:hud_add({
            type = "text",
            position = {x = 1, y = 0},
            offset = {x = -10, y = 80},
            text = hud_text,
            alignment = {x = -1, y = 1},
            scale = {x = 100, y = 100},
            number = 0xFFD700,  -- Gold color
            size = {x = 1, y = 1},
        })
    end
end

-- Update HUD for all connected players
local function update_all_huds()
    for _, player in ipairs(minetest.get_connected_players()) do
        update_player_hud(player)
    end
end

-- Remove HUD for a player
local function remove_player_hud(player)
    local player_name = player:get_player_name()
    if player_hud_ids[player_name] then
        player:hud_remove(player_hud_ids[player_name])
        player_hud_ids[player_name] = nil
    end
end

-- Initialize leader on mod load
minetest.after(1, function()
    current_leader = get_leader()
end)

-- Create HUD when player joins
minetest.register_on_joinplayer(function(player)
    -- Delay HUD creation slightly to ensure player is fully loaded
    minetest.after(1, function()
        if player and player:is_player() then
            update_player_hud(player)
        end
    end)
end)

-- Clean up HUD when player leaves
minetest.register_on_leaveplayer(function(player)
    local player_name = player:get_player_name()
    player_hud_ids[player_name] = nil
end)

-- Helper function to ensure chunk is generated at coordinates
local function ensure_chunk_loaded(x, y, z)
    local node = minetest.get_node({x = x, y = y, z = z})
    if node.name == "ignore" then
        -- Force load the mapblock containing this position
        local minp = {x = x - 16, y = y - 16, z = z - 16}
        local maxp = {x = x + 16, y = y + 16, z = z + 16}
        minetest.emerge_area(minp, maxp)
        -- Use get_node_or_nil with VoxelManip as backup to force load
        minetest.get_voxel_manip():read_from_map(minp, maxp)
    end
end

-- Helper function to find ground level at x,z coordinates
-- Scans from y=100 down to y=-50 to find first solid non-air block
-- Returns the Y coordinate where items should be placed (on top of solid ground)
-- For water areas, returns the water surface level (not ocean floor)
local function find_ground_level(x, z)
    -- First ensure the chunks are loaded/generated
    ensure_chunk_loaded(x, 64, z)
    ensure_chunk_loaded(x, 0, z)

    local water_surface = nil

    for y = 100, -50, -1 do
        local node = minetest.get_node({x = x, y = y, z = z})
        local name = node.name

        -- If we hit ignore, the chunk isn't generated - try to load it
        if name == "ignore" then
            ensure_chunk_loaded(x, y, z)
            node = minetest.get_node({x = x, y = y, z = z})
            name = node.name
        end

        -- Track water surface (first water block we encounter from above)
        if name:find("water") and not water_surface then
            -- Check if block above is air (this is the water surface)
            local above = minetest.get_node({x = x, y = y + 1, z = z})
            if above.name == "air" then
                water_surface = y + 1  -- Place ON TOP of water surface
            end
        end

        -- Skip non-solid blocks (air, water, plants, etc.)
        -- Note: "tallgrass" for plants, not "grass" which would match dirt_with_grass
        if name ~= "air" and name ~= "ignore" and
           not name:find("water") and not name:find("lava") and
           not name:find("tallgrass") and not name:find("flower") and
           not name:find("fern") and not name:find("bush") and
           not name:find("plant") and not name:find("leaves") and
           not name:find("vine") and not name:find("snow_layer") then
            -- Found solid ground
            -- If we found water surface before solid ground, we're in water - use water surface
            if water_surface then
                return water_surface
            end
            -- Otherwise return solid ground position
            return y
        end
    end

    -- If we only found water (deep ocean), return water surface
    if water_surface then
        return water_surface
    end

    return 1  -- Default to y=1 if nothing found
end

-- Helper function to parse y coordinate, supporting ~ for ground level
local function parse_y_coord(y_str, x, z)
    if y_str == "~" or y_str == "g" or y_str == "ground" then
        return find_ground_level(x, z)
    else
        return tonumber(y_str)
    end
end

-- Detect game type (Mineclonia/VoxeLibre use mcl_ prefix)
local function get_item(item_type)
    local items = {
        chest = "mcl_chests:chest",
        sign = "mcl_signs:wall_sign_dark_oak",
        diamond = "mcl_core:diamond",
        gold = "mcl_core:gold_ingot",
        iron = "mcl_core:iron_ingot",
        emerald = "mcl_core:emerald",
        diamond_sword = "mcl_tools:sword_diamond",
        diamond_pick = "mcl_tools:pick_diamond",
        iron_sword = "mcl_tools:sword_iron",
        iron_pick = "mcl_tools:pick_iron",
        bread = "mcl_farming:bread",
        apple = "mcl_core:apple",
        torch = "mcl_torches:torch",
        compass = "mcl_compass:compass",
        map = "mcl_maps:empty_map",
        helmet_diamond = "mcl_armor:helmet_diamond",
        chestplate_diamond = "mcl_armor:chestplate_diamond",
        leggings_diamond = "mcl_armor:leggings_diamond",
        boots_diamond = "mcl_armor:boots_diamond",
        helmet_iron = "mcl_armor:helmet_iron",
        chestplate_iron = "mcl_armor:chestplate_iron",
        leggings_iron = "mcl_armor:leggings_iron",
        boots_iron = "mcl_armor:boots_iron",
        goldblock = "mcl_core:goldblock",
        diamondblock = "mcl_core:diamondblock",
        cobble = "mcl_core:cobble",
    }
    return items[item_type] or item_type
end

-- /starterkit <player> - Give basic survival kit
minetest.register_chatcommand("starterkit", {
    params = "<playername>",
    description = "Give a player a basic survival starter kit",
    privs = {server = true},
    func = function(name, param)
        local target = param ~= "" and param or name
        local player = minetest.get_player_by_name(target)
        if not player then
            return false, "Player " .. target .. " not found"
        end

        local inv = player:get_inventory()
        local items = {
            {get_item("iron_pick"), 1},
            {get_item("iron_sword"), 1},
            {get_item("torch"), 32},
            {get_item("bread"), 16},
            {get_item("cobble"), 64},
        }

        for _, item in ipairs(items) do
            inv:add_item("main", item[1] .. " " .. item[2])
        end

        minetest.chat_send_player(target, "*** You received a starter kit! ***")
        return true, "Gave starter kit to " .. target
    end,
})

-- /herokit <player> - Give full diamond gear
minetest.register_chatcommand("herokit", {
    params = "<playername>",
    description = "Give a player full diamond gear (hero kit)",
    privs = {server = true},
    func = function(name, param)
        local target = param ~= "" and param or name
        local player = minetest.get_player_by_name(target)
        if not player then
            return false, "Player " .. target .. " not found"
        end

        local inv = player:get_inventory()
        local items = {
            {get_item("diamond_sword"), 1},
            {get_item("diamond_pick"), 1},
            {get_item("helmet_diamond"), 1},
            {get_item("chestplate_diamond"), 1},
            {get_item("leggings_diamond"), 1},
            {get_item("boots_diamond"), 1},
            {get_item("torch"), 64},
            {get_item("bread"), 64},
            {get_item("goldblock"), 16},
        }

        for _, item in ipairs(items) do
            inv:add_item("main", item[1] .. " " .. item[2])
        end

        minetest.chat_send_player(target, "*** You received the HERO KIT! ***")
        return true, "Gave hero kit to " .. target
    end,
})

-- /questkit <player> - Give exploration kit with compass and map
minetest.register_chatcommand("questkit", {
    params = "<playername>",
    description = "Give a player a quest exploration kit",
    privs = {server = true},
    func = function(name, param)
        local target = param ~= "" and param or name
        local player = minetest.get_player_by_name(target)
        if not player then
            return false, "Player " .. target .. " not found"
        end

        local inv = player:get_inventory()
        local items = {
            {get_item("compass"), 1},
            {get_item("map"), 3},
            {get_item("torch"), 64},
            {get_item("bread"), 32},
            {get_item("iron_sword"), 1},
            {get_item("iron_pick"), 1},
        }

        for _, item in ipairs(items) do
            inv:add_item("main", item[1] .. " " .. item[2])
        end

        minetest.chat_send_player(target, "*** You received a QUEST KIT! Adventure awaits! ***")
        return true, "Gave quest kit to " .. target
    end,
})

-- /treasure - Place a treasure chest at your position or coordinates with random loot
-- y can be ~ for ground level auto-detection
minetest.register_chatcommand("treasure", {
    params = "[<x> <y|~> <z>] <small|medium|big|epic>",
    description = "Place a treasure chest. Use ~ for ground level. Example: /treasure big OR /treasure 100 ~ 200 epic",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local x, y_str, z, tier
        local pos

        -- Try to parse coordinates first (y can be number or ~)
        x, y_str, z, tier = param:match("^(-?%d+)%s+([~g%-]?%d*)%s+(-?%d+)%s+(%w+)$")

        if x and y_str and z and tier then
            -- Coordinates provided
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
        else
            -- No coordinates, use player position
            tier = param:match("^(%w*)$") or "medium"
            if tier == "" then tier = "medium" end
            pos = player:get_pos()
            pos.y = pos.y + 0.5
            pos = vector.round(pos)
        end

        -- Place chest
        minetest.set_node(pos, {name = get_item("chest")})

        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        inv:set_size("main", 27)

        local tier = param ~= "" and param or "medium"
        local loot = {}

        if tier == "small" then
            loot = {
                {get_item("iron"), math.random(3, 8)},
                {get_item("bread"), math.random(4, 10)},
                {get_item("torch"), math.random(8, 16)},
            }
            meta:set_string("infotext", "Small Treasure Chest")
        elseif tier == "medium" then
            loot = {
                {get_item("iron"), math.random(8, 16)},
                {get_item("gold"), math.random(4, 8)},
                {get_item("diamond"), math.random(1, 3)},
                {get_item("bread"), math.random(8, 16)},
                {get_item("iron_sword"), 1},
            }
            meta:set_string("infotext", "Treasure Chest")
        elseif tier == "big" then
            loot = {
                {get_item("gold"), math.random(16, 32)},
                {get_item("diamond"), math.random(4, 8)},
                {get_item("emerald"), math.random(2, 5)},
                {get_item("diamond_sword"), 1},
                {get_item("diamond_pick"), 1},
            }
            meta:set_string("infotext", "Big Treasure Chest!")
        elseif tier == "epic" then
            loot = {
                {get_item("diamondblock"), math.random(2, 5)},
                {get_item("emerald"), math.random(8, 16)},
                {get_item("diamond_sword"), 1},
                {get_item("diamond_pick"), 1},
                {get_item("helmet_diamond"), 1},
                {get_item("chestplate_diamond"), 1},
                {get_item("leggings_diamond"), 1},
                {get_item("boots_diamond"), 1},
            }
            meta:set_string("infotext", "EPIC TREASURE CHEST!!!")
        end

        for _, item in ipairs(loot) do
            inv:add_item("main", item[1] .. " " .. item[2])
        end

        return true, "Placed " .. tier .. " treasure chest at " .. minetest.pos_to_string(pos)
    end,
})

-- /savespot <name> - Save current position as a named waypoint
minetest.register_chatcommand("savespot", {
    params = "<name>",
    description = "Save your current position as a named waypoint",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Please provide a waypoint name"
        end

        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local pos = player:get_pos()
        local key = "waypoint_" .. param
        storage:set_string(key, minetest.pos_to_string(vector.round(pos)))

        return true, "Saved waypoint '" .. param .. "' at " .. minetest.pos_to_string(vector.round(pos))
    end,
})

-- /gospot <name> - Teleport to a saved waypoint
minetest.register_chatcommand("gospot", {
    params = "<name>",
    description = "Teleport to a saved waypoint",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Please provide a waypoint name"
        end

        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local key = "waypoint_" .. param
        local pos_str = storage:get_string(key)

        if pos_str == "" then
            return false, "Waypoint '" .. param .. "' not found"
        end

        local pos = minetest.string_to_pos(pos_str)
        player:set_pos(pos)

        return true, "Teleported to waypoint '" .. param .. "'"
    end,
})

-- /listspots - List all saved waypoints
minetest.register_chatcommand("listspots", {
    params = "",
    description = "List all saved waypoints",
    privs = {server = true},
    func = function(name, param)
        local spots = {}
        -- Note: mod_storage doesn't have a direct way to list keys
        -- We'll store a list of waypoint names
        local list_str = storage:get_string("waypoint_list")
        if list_str == "" then
            return true, "No waypoints saved yet"
        end
        return true, "Saved waypoints: " .. list_str
    end,
})

-- /bringall - Teleport all players to you
minetest.register_chatcommand("bringall", {
    params = "",
    description = "Teleport all online players to your position",
    privs = {server = true},
    func = function(name, param)
        local admin = minetest.get_player_by_name(name)
        if not admin then
            return false, "Error getting your position"
        end

        local pos = admin:get_pos()
        local count = 0

        for _, player in ipairs(minetest.get_connected_players()) do
            local pname = player:get_player_name()
            if pname ~= name then
                player:set_pos(pos)
                minetest.chat_send_player(pname, "*** You have been summoned by " .. name .. "! ***")
                count = count + 1
            end
        end

        return true, "Teleported " .. count .. " players to your position"
    end,
})

-- /announce <message> - Send a big announcement to all players
minetest.register_chatcommand("announce", {
    params = "<message>",
    description = "Send a highlighted announcement to all players",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Please provide a message"
        end

        local msg = "*** ANNOUNCEMENT: " .. param .. " ***"
        minetest.chat_send_all(msg)

        -- Also show as HUD message if possible
        for _, player in ipairs(minetest.get_connected_players()) do
            local pname = player:get_player_name()
            minetest.chat_send_player(pname, minetest.colorize("#FFD700", msg))
        end

        return true, "Announcement sent"
    end,
})

-- /countdown <seconds> <message> - Start a countdown
minetest.register_chatcommand("countdown", {
    params = "<seconds> <message>",
    description = "Start a countdown timer with a message at the end",
    privs = {server = true},
    func = function(name, param)
        local parts = param:split(" ")
        local seconds = tonumber(parts[1])

        if not seconds or seconds < 1 or seconds > 60 then
            return false, "Please provide seconds (1-60)"
        end

        table.remove(parts, 1)
        local message = table.concat(parts, " ")
        if message == "" then
            message = "GO!"
        end

        -- Countdown function
        local function do_countdown(remaining)
            if remaining > 0 then
                minetest.chat_send_all("*** " .. remaining .. "... ***")
                minetest.after(1, function()
                    do_countdown(remaining - 1)
                end)
            else
                minetest.chat_send_all(minetest.colorize("#00FF00", "*** " .. message .. " ***"))
            end
        end

        minetest.chat_send_all("*** COUNTDOWN STARTING ***")
        do_countdown(seconds)

        return true, "Countdown started"
    end,
})

-- Helper function to format text for signs (auto-wrap and line breaks)
local function format_sign_text(text)
    local MAX_LINE_LENGTH = 15
    local MAX_LINES = 4

    -- Replace | with newlines for easy multi-line input
    text = text:gsub("|", "\n")

    -- If text already has newlines, use them as-is (up to 4 lines)
    if text:find("\n") then
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            table.insert(lines, line)
            if #lines >= MAX_LINES then break end
        end
        return table.concat(lines, "\n")
    end

    -- Auto-wrap long text
    local lines = {}
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
        if current_line == "" then
            current_line = word
        elseif #current_line + 1 + #word <= MAX_LINE_LENGTH then
            current_line = current_line .. " " .. word
        else
            table.insert(lines, current_line)
            current_line = word
            if #lines >= MAX_LINES then
                current_line = ""
                break
            end
        end
    end

    if current_line ~= "" and #lines < MAX_LINES then
        table.insert(lines, current_line)
    end

    return table.concat(lines, "\n")
end

-- /placetext [x y z] <text> - Place a sign with text at coordinates or current position
-- y can be ~ for ground level auto-detection
minetest.register_chatcommand("placetext", {
    params = "[<x> <y|~> <z>] <text>",
    description = "Place a sign with text. Use ~ for ground level, | for line breaks. Example: /placetext 100 ~ 200 Go North!",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local x, y_str, z, text

        -- Try to parse coordinates first (y can be number or ~)
        x, y_str, z, text = param:match("^(-?%d+)%s+([~g%-]?%d*)%s+(-?%d+)%s+(.+)$")

        local pos
        if x and y_str and z and text then
            -- Coordinates provided
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
        else
            -- No coordinates, use player position
            text = param
            if text == "" then
                return false, "Please provide text for the sign"
            end
            pos = vector.round(player:get_pos())
        end

        -- Format text with auto-wrap and line breaks
        local formatted_text = format_sign_text(text)

        -- Get player facing direction for sign rotation
        local dir = player:get_look_horizontal()
        local param2 = minetest.dir_to_wallmounted(minetest.yaw_to_dir(dir))

        -- Place standing sign with rotation
        minetest.set_node(pos, {name = "mcl_signs:standing_sign_oak", param2 = 0})

        -- Set the text using Mineclonia's expected format
        local meta = minetest.get_meta(pos)
        meta:set_string("text", formatted_text)
        meta:set_string("infotext", formatted_text)

        -- Try to update sign entity if mcl_signs API exists
        if mcl_signs and mcl_signs.update_sign then
            mcl_signs.update_sign(pos)
        end

        -- Mineclonia uses a text entity - try to spawn it
        minetest.after(0.1, function()
            -- Find and update any existing sign entity or create one
            local objs = minetest.get_objects_inside_radius(pos, 0.5)
            for _, obj in ipairs(objs) do
                local ent = obj:get_luaentity()
                if ent and ent.name == "mcl_signs:text" then
                    -- Update existing entity
                    obj:set_properties({infotext = formatted_text})
                    return
                end
            end

            -- If mcl_signs has an update function, call it
            if mcl_signs and mcl_signs.update_sign then
                mcl_signs.update_sign(pos)
            end
        end)

        return true, "Placed sign at " .. minetest.pos_to_string(pos) .. " with text: " .. formatted_text:gsub("\n", " | ")
    end,
})

-- Helper function to split text into sign-sized chunks (4 lines x ~15 chars each = ~60 chars per sign)
local function split_text_for_signs(text)
    local MAX_LINE_LENGTH = 15
    local MAX_LINES = 4
    local CHARS_PER_SIGN = MAX_LINE_LENGTH * MAX_LINES

    -- Replace | with spaces (bigtext handles its own wrapping)
    text = text:gsub("|", " ")

    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local signs = {}
    local current_sign_lines = {}
    local current_line = ""

    for _, word in ipairs(words) do
        if current_line == "" then
            current_line = word
        elseif #current_line + 1 + #word <= MAX_LINE_LENGTH then
            current_line = current_line .. " " .. word
        else
            -- Line is full, add to current sign
            table.insert(current_sign_lines, current_line)
            current_line = word

            -- Check if sign is full (4 lines)
            if #current_sign_lines >= MAX_LINES then
                table.insert(signs, table.concat(current_sign_lines, "\n"))
                current_sign_lines = {}
            end
        end
    end

    -- Add remaining line to current sign
    if current_line ~= "" then
        table.insert(current_sign_lines, current_line)
    end

    -- Add remaining sign
    if #current_sign_lines > 0 then
        table.insert(signs, table.concat(current_sign_lines, "\n"))
    end

    return signs
end

-- /bigtext <text> - Place multiple signs for long messages
minetest.register_chatcommand("bigtext", {
    params = "<text>",
    description = "Place multiple signs side-by-side for long messages. Example: /bigtext This is a really long message that needs multiple signs",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        if param == "" then
            return false, "Please provide text for the signs"
        end

        local sign_texts = split_text_for_signs(param)

        if #sign_texts == 0 then
            return false, "No text to display"
        end

        -- Limit to 5 signs max
        if #sign_texts > 5 then
            sign_texts = {unpack(sign_texts, 1, 5)}
        end

        local pos = vector.round(player:get_pos())

        -- Get player facing direction to place signs in a row perpendicular to view
        local yaw = player:get_look_horizontal()
        -- Calculate perpendicular direction (to the right of player)
        local right_x = math.cos(yaw - math.pi/2)
        local right_z = math.sin(yaw - math.pi/2)

        -- Place signs in a row (left to right when facing them)
        for i, sign_text in ipairs(sign_texts) do
            -- Reverse offset so first sign is on reader's left when facing the signs
            local offset = math.floor(#sign_texts / 2) - (i - 1)
            local sign_pos = {
                x = pos.x + math.floor(right_x * offset + 0.5),
                y = pos.y,
                z = pos.z + math.floor(right_z * offset + 0.5)
            }

            -- Place standing sign
            minetest.set_node(sign_pos, {name = "mcl_signs:standing_sign_oak", param2 = 0})

            -- Set the text
            local meta = minetest.get_meta(sign_pos)
            meta:set_string("text", sign_text)
            meta:set_string("infotext", sign_text)

            -- Try to update sign entity
            if mcl_signs and mcl_signs.update_sign then
                mcl_signs.update_sign(sign_pos)
            end
        end

        return true, "Placed " .. #sign_texts .. " signs with your message"
    end,
})

-- /placemarker [x y z] <color> - Place a colored wool marker
-- y can be ~ for ground level auto-detection
minetest.register_chatcommand("placemarker", {
    params = "[<x> <y|~> <z>] <color>",
    description = "Place a colored wool marker. Use ~ for ground level. Example: /placemarker red OR /placemarker 100 ~ 200 red",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local colors = {
            red = "mcl_wool:red",
            blue = "mcl_wool:blue",
            yellow = "mcl_wool:yellow",
            green = "mcl_wool:green",
            lime = "mcl_wool:lime",
            orange = "mcl_wool:orange",
            purple = "mcl_wool:purple",
            magenta = "mcl_wool:magenta",
            white = "mcl_wool:white",
            black = "mcl_wool:black",
            pink = "mcl_wool:pink",
            cyan = "mcl_wool:cyan",
        }

        local x, y_str, z, color

        -- Try to parse coordinates first (y can be number or ~)
        x, y_str, z, color = param:match("^(-?%d+)%s+([~g%-]?%d*)%s+(-?%d+)%s+(%w+)$")

        local pos
        if x and y_str and z and color then
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
        else
            color = param:match("^(%w+)$")
            if not color then
                return false, "Please provide a color: red, blue, yellow, green, orange, purple, white"
            end
            pos = vector.round(player:get_pos())
        end

        local node_name = colors[color:lower()]
        if not node_name then
            return false, "Unknown color. Use: red, blue, yellow, green, lime, orange, purple, magenta, white, black, pink, cyan"
        end

        minetest.set_node(pos, {name = node_name})

        return true, "Placed " .. color .. " marker at " .. minetest.pos_to_string(pos)
    end,
})

-- /trail [x y z] <color> <length> <direction> - Create a trail of markers
-- y can be ~ for ground level auto-detection
minetest.register_chatcommand("trail", {
    params = "[<x> <y|~> <z>] <color> <length> <n|s|e|w>",
    description = "Create a trail of markers. Use ~ for ground level. Example: /trail red 10 n OR /trail 100 ~ 200 red 10 n",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local x, y_str, z, color, length, direction
        local pos

        -- Try to parse with coordinates first (y can be number or ~)
        x, y_str, z, color, length, direction = param:match("^(-?%d+)%s+([~g%-]?%d*)%s+(-?%d+)%s+(%w+)%s+(%d+)%s+([nsewNSEW])$")

        if x and y_str and z and color and length and direction then
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
            length = tonumber(length)
        else
            -- No coordinates, use player position
            color, length, direction = param:match("^(%w+)%s+(%d+)%s+([nsewNSEW])$")
            if not color or not length or not direction then
                return false, "Usage: /trail <color> <length> <n|s|e|w> OR /trail <x> <y|~> <z> <color> <length> <dir>"
            end
            length = tonumber(length)
            pos = vector.round(player:get_pos())
        end

        if length > 50 then
            length = 50  -- Limit to prevent accidents
        end

        local colors = {
            red = "mcl_wool:red",
            blue = "mcl_wool:blue",
            yellow = "mcl_wool:yellow",
            green = "mcl_wool:green",
            orange = "mcl_wool:orange",
            white = "mcl_wool:white",
        }

        local node_name = colors[color:lower()]
        if not node_name then
            return false, "Unknown color. Use: red, blue, yellow, green, orange, white"
        end

        local dir = direction:lower()
        local dx, dz = 0, 0

        if dir == "n" then dz = -1
        elseif dir == "s" then dz = 1
        elseif dir == "e" then dx = 1
        elseif dir == "w" then dx = -1
        end

        -- Place markers every 5 blocks, each at its own ground level
        for i = 0, length - 1 do
            local marker_x = pos.x + (dx * i * 5)
            local marker_z = pos.z + (dz * i * 5)
            -- Find ground level for THIS marker position
            local marker_y = find_ground_level(marker_x, marker_z)
            local marker_pos = {x = marker_x, y = marker_y, z = marker_z}
            minetest.set_node(marker_pos, {name = node_name})
        end

        return true, "Created " .. color .. " trail with " .. length .. " markers heading " .. direction .. " (ground-following)"
    end,
})

-- /pole [x y z] <color> <height> - Create a vertical pole of markers
-- y can be ~ for ground level auto-detection
minetest.register_chatcommand("pole", {
    params = "[<x> <y|~> <z>] <color> <height>",
    description = "Create a vertical pole. Use ~ for ground level. Example: /pole blue 10 OR /pole 100 ~ 200 blue 10",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local x, y_str, z, color, height
        local pos

        -- Try to parse with coordinates first (y can be number or ~)
        x, y_str, z, color, height = param:match("^(-?%d+)%s+([~g%-]?%d*)%s+(-?%d+)%s+(%w+)%s+(%d+)$")

        if x and y_str and z and color and height then
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
            height = tonumber(height)
        else
            -- No coordinates, use player position
            color, height = param:match("^(%w+)%s+(%d+)$")
            if not color or not height then
                return false, "Usage: /pole <color> <height> OR /pole <x> <y|~> <z> <color> <height>"
            end
            height = tonumber(height)
            pos = vector.round(player:get_pos())
        end

        if height > 50 then
            height = 50  -- Limit to prevent accidents
        end

        local colors = {
            red = "mcl_wool:red",
            blue = "mcl_wool:blue",
            yellow = "mcl_wool:yellow",
            green = "mcl_wool:green",
            lime = "mcl_wool:lime",
            orange = "mcl_wool:orange",
            purple = "mcl_wool:purple",
            magenta = "mcl_wool:magenta",
            white = "mcl_wool:white",
            black = "mcl_wool:black",
            pink = "mcl_wool:pink",
            cyan = "mcl_wool:cyan",
            gold = "mcl_core:goldblock",
            diamond = "mcl_core:diamondblock",
            glow = "mcl_nether:glowstone",
        }

        local node_name = colors[color:lower()]
        if not node_name then
            return false, "Unknown color. Use: red, blue, yellow, green, orange, white, gold, diamond, glow"
        end

        -- Place blocks vertically
        for i = 0, height - 1 do
            local pole_pos = {
                x = pos.x,
                y = pos.y + i,
                z = pos.z
            }
            minetest.set_node(pole_pos, {name = node_name})
        end

        return true, "Created " .. color .. " pole with " .. height .. " blocks at " .. minetest.pos_to_string(pos)
    end,
})

-- /beacon [x y z] <color> - Create a tall glowing beacon (pole with light on top)
-- y can be ~ or g for ground level auto-detection
minetest.register_chatcommand("beacon", {
    params = "[<x> <y|~> <z>] <color>",
    description = "Create a tall beacon. Use ~ for ground level. Example: /beacon red OR /beacon 100 ~ 200 red",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local x, y_str, z, color
        local pos

        -- Try to parse with coordinates first (y can be number or ~)
        x, y_str, z, color = param:match("^(-?%d+)%s+([~g%-]?%d*)%s+(-?%d+)%s+(%w+)$")

        if x and y_str and z and color then
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
        else
            -- No coordinates, use player position
            color = param:match("^(%w+)$")
            if not color then
                return false, "Usage: /beacon <color> OR /beacon <x> <y|~> <z> <color>"
            end
            pos = vector.round(player:get_pos())
        end

        local colors = {
            red = "mcl_wool:red",
            blue = "mcl_wool:blue",
            yellow = "mcl_wool:yellow",
            green = "mcl_wool:green",
            white = "mcl_wool:white",
            orange = "mcl_wool:orange",
        }

        local node_name = colors[color:lower()]
        if not node_name then
            return false, "Unknown color. Use: red, blue, yellow, green, white, orange"
        end

        -- Create a 15-block tall pole with glowstone on top
        for i = 0, 14 do
            local pole_pos = {x = pos.x, y = pos.y + i, z = pos.z}
            minetest.set_node(pole_pos, {name = node_name})
        end

        -- Add glowstone on top for visibility
        minetest.set_node({x = pos.x, y = pos.y + 15, z = pos.z}, {name = "mcl_nether:glowstone"})
        minetest.set_node({x = pos.x, y = pos.y + 16, z = pos.z}, {name = "mcl_nether:glowstone"})

        return true, "Created " .. color .. " beacon at " .. minetest.pos_to_string(pos)
    end,
})

-- ============================================
-- PUZZLE CHEST FEATURE
-- Password-protected chest with explosion on failed attempts
-- ============================================

-- Track failed attempts per player per chest
local puzzle_attempts = {}

-- Helper to get attempt key for player+position
local function get_attempt_key(player_name, pos)
    return player_name .. ":" .. minetest.pos_to_string(pos)
end

-- Get formspec for puzzle chest
local function get_puzzle_formspec(pos, question)
    local pos_str = minetest.pos_to_string(pos)
    return "formspec_version[4]" ..
           "size[10,5]" ..
           "label[0.5,0.7;PUZZLE CHEST]" ..
           "label[0.5,1.4;" .. minetest.formspec_escape(question) .. "]" ..
           "field[0.5,2.2;7,0.8;answer;Your Answer:;]" ..
           "button[7.8,2.2;1.7,0.8;submit;Submit]" ..
           "field_close_on_enter[answer;false]" ..
           "button_exit[0.5,3.5;3,0.8;cancel;Cancel]"
end

-- Explode and damage player (not the world)
local function puzzle_explode(pos, player)
    if not player then return end

    -- Play explosion sound
    minetest.sound_play("tnt_explode", {pos = pos, gain = 1.0, max_hear_distance = 32}, true)

    -- Add visual explosion particles
    minetest.add_particlespawner({
        amount = 64,
        time = 0.5,
        minpos = vector.subtract(pos, 2),
        maxpos = vector.add(pos, 2),
        minvel = {x = -5, y = -5, z = -5},
        maxvel = {x = 5, y = 10, z = 5},
        minacc = {x = 0, y = -10, z = 0},
        maxacc = {x = 0, y = -10, z = 0},
        minexptime = 0.5,
        maxexptime = 1.5,
        minsize = 3,
        maxsize = 6,
        texture = "mcl_particles_smoke.png",
    })

    -- Damage only the player who failed (heavy damage but survivable with armor)
    local hp = player:get_hp()
    player:set_hp(math.max(0, hp - 16))  -- 8 hearts of damage

    -- Notify the player
    local player_name = player:get_player_name()
    minetest.chat_send_player(player_name, minetest.colorize("#FF0000", "*** BOOM! The puzzle chest exploded! ***"))

    -- Remove the chest and its contents (lost forever)
    minetest.remove_node(pos)
end

-- Puzzle chest tier configurations with distinct colors
-- small -> brown/wooden, medium -> silver/iron, big -> gold, epic -> diamond/purple
local PUZZLE_CHEST_TIERS = {
    small = {
        description = "Wooden Puzzle Chest",
        infotext = "Wooden Puzzle Chest (Locked)",
        -- Brown/wooden color scheme - clearly distinct from gold
        base_texture = "default_gold_block.png^[colorize:#8B4513:220",  -- Saddle brown
        side_texture = "default_gold_block.png^[colorize:#654321:230",  -- Dark brown
        front_texture = "default_gold_block.png^[colorize:#5D3A1A:220", -- Coffee brown
        particle_color = "#8B4513",
    },
    medium = {
        description = "Iron Puzzle Chest",
        infotext = "Iron Puzzle Chest (Locked)",
        -- Silver/iron color scheme
        base_texture = "default_gold_block.png^[colorize:#A8A8A8:210",  -- Light gray
        side_texture = "default_gold_block.png^[colorize:#696969:200",  -- Dim gray sides
        front_texture = "default_gold_block.png^[colorize:#808080:200", -- Gray front
        particle_color = "#A8A8A8",
    },
    big = {
        description = "Gold Puzzle Chest",
        infotext = "Gold Puzzle Chest (Locked)",
        -- Bright gold color scheme - distinctly yellow
        base_texture = "default_gold_block.png^[colorize:#FFD700:80",   -- Bright gold
        side_texture = "default_gold_block.png^[colorize:#DAA520:100",  -- Goldenrod sides
        front_texture = "default_gold_block.png^[colorize:#FFC000:80",  -- Amber front
        particle_color = "#FFD700",
    },
    epic = {
        description = "Diamond Puzzle Chest",
        infotext = "Diamond Puzzle Chest (Locked)",
        -- Purple/magenta color scheme - magical and rare
        base_texture = "default_gold_block.png^[colorize:#9932CC:180",  -- Dark orchid
        side_texture = "default_gold_block.png^[colorize:#8B008B:180",  -- Dark magenta sides
        front_texture = "default_gold_block.png^[colorize:#BA55D3:170", -- Medium orchid front
        particle_color = "#9932CC",
    },
}

-- Helper to check if a node is any puzzle chest variant
local function is_puzzle_chest(node_name)
    return node_name:match("^quest_helper:puzzle_chest_")
end

-- Get tier from node name
local function get_tier_from_node(node_name)
    return node_name:match("^quest_helper:puzzle_chest_(%w+)$")
end

-- Function to register a puzzle chest variant for a specific tier
local function register_puzzle_chest(tier, config)
    local node_name = "quest_helper:puzzle_chest_" .. tier

    minetest.register_node(node_name, {
        description = config.description,
        tiles = {
            config.base_texture,   -- top
            config.base_texture,   -- bottom
            config.side_texture,   -- right
            config.side_texture,   -- left
            config.side_texture,   -- back
            config.front_texture,  -- front
        },
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = "facedir",
        node_box = {
            type = "fixed",
            fixed = {
                -- Main chest body (bottom part)
                {-0.4375, -0.5, -0.375, 0.4375, 0.125, 0.375},
                -- Chest lid (top part, slightly smaller)
                {-0.4375, 0.125, -0.375, 0.4375, 0.375, 0.375},
                -- Lock/latch on front
                {-0.0625, 0.0, 0.375, 0.0625, 0.25, 0.4375},
            },
        },
        selection_box = {
            type = "fixed",
            fixed = {-0.4375, -0.5, -0.375, 0.4375, 0.375, 0.4375},
        },
        groups = {choppy = 2, oddly_breakable_by_hand = 2, handy = 1, axey = 1},
        _mcl_hardness = 2.5,
        _mcl_blast_resistance = 2.5,

        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            inv:set_size("main", 27)
            meta:set_string("question", "What is the answer?")
            meta:set_string("answer", "secret")
            meta:set_int("max_attempts", 3)
            meta:set_string("tier", tier)
            meta:set_string("infotext", config.infotext)
        end,

        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            if not clicker then return end
            local player_name = clicker:get_player_name()
            local meta = minetest.get_meta(pos)

            -- Admin bypass: players with server privilege skip the puzzle
            if is_admin(player_name) then
                minetest.chat_send_player(player_name, minetest.colorize("#00FF00", "[Admin] Bypassing puzzle - showing chest contents"))
                -- Show regular chest formspec
                local inv_formspec = "formspec_version[4]" ..
                                    "size[9,8.75]" ..
                                    "label[0.5,0.5;" .. config.description .. " (Admin Access)]" ..
                                    "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";main;0.5,1;9,3;]" ..
                                    "list[current_player;main;0.5,4.75;9,3;9]" ..
                                    "list[current_player;main;0.5,7.75;9,1;]" ..
                                    "listring[]"
                minetest.show_formspec(player_name, "quest_helper:puzzle_chest_admin", inv_formspec)
                return
            end

            -- Check if chest was already solved globally
            local solved_by = meta:get_string("solved_by")
            local unlocked_key = "unlocked_" .. player_name
            local player_unlocked = meta:get_int(unlocked_key) == 1

            if meta:get_int("solved") == 1 then
                if solved_by == player_name or player_unlocked then
                    -- This player solved it - show inventory so they can take items
                    local inv_formspec = "formspec_version[4]" ..
                                        "size[9,8.75]" ..
                                        "label[0.5,0.5;" .. config.description .. " (Unlocked)]" ..
                                        "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";main;0.5,1;9,3;]" ..
                                        "list[current_player;main;0.5,4.75;9,3;9]" ..
                                        "list[current_player;main;0.5,7.75;9,1;]" ..
                                        "listring[]"
                    minetest.show_formspec(player_name, "quest_helper:puzzle_chest_unlocked", inv_formspec)
                else
                    -- Another player already solved this chest
                    minetest.chat_send_player(player_name,
                        minetest.colorize("#FFAA00", "*** This puzzle chest was already solved by " .. solved_by .. "! ***"))
                end
                return
            end

            -- Legacy: check if player had unlocked before the global solved flag existed
            if player_unlocked then
                local inv_formspec = "formspec_version[4]" ..
                                    "size[9,8.75]" ..
                                    "label[0.5,0.5;" .. config.description .. " (Unlocked)]" ..
                                    "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";main;0.5,1;9,3;]" ..
                                    "list[current_player;main;0.5,4.75;9,3;9]" ..
                                    "list[current_player;main;0.5,7.75;9,1;]" ..
                                    "listring[]"
                minetest.show_formspec(player_name, "quest_helper:puzzle_chest_unlocked", inv_formspec)
                return
            end

            -- Show puzzle formspec
            local question = meta:get_string("question")
            local attempt_key = get_attempt_key(player_name, pos)
            local attempts = puzzle_attempts[attempt_key] or 0
            local max_attempts = meta:get_int("max_attempts")

            -- Add attempt warning to question
            local full_question = question
            if attempts > 0 then
                full_question = question .. " (Attempts: " .. attempts .. "/" .. max_attempts .. ")"
            end

            -- Store position in player metadata for formspec handler
            local player_meta = clicker:get_meta()
            player_meta:set_string("puzzle_chest_pos", minetest.pos_to_string(pos))

            minetest.show_formspec(player_name, "quest_helper:puzzle_chest", get_puzzle_formspec(pos, full_question))
        end,

        -- Prevent breaking by non-admins (optional security)
        can_dig = function(pos, player)
            if not player then return false end
            return is_admin(player:get_player_name())
        end,

        -- Auto-vanish when chest is emptied after being unlocked
        on_metadata_inventory_take = function(pos, listname, index, stack, player)
            if not player then return end
            local player_name = player:get_player_name()
            local meta = minetest.get_meta(pos)

            -- Check if chest is now empty
            local inv = meta:get_inventory()

            -- Count remaining items
            local remaining_count = 0
            local remaining_items = {}
            for i = 1, inv:get_size("main") do
                local item = inv:get_stack("main", i)
                if not item:is_empty() then
                    remaining_count = remaining_count + 1
                    table.insert(remaining_items, {slot = i, stack = item})
                end
            end

            if remaining_count > 0 then
                minetest.log("action", "[quest_helper] Puzzle chest at " .. minetest.pos_to_string(pos) ..
                    " still has " .. remaining_count .. " items remaining")

                -- EPIC CHEST SPECIAL: Drop remaining items after timeout
                if tier == "epic" then
                    local loot_started = meta:get_int("loot_started")
                    if loot_started == 0 then
                        -- First take - start the loot timer
                        meta:set_int("loot_started", os.time())
                        minetest.chat_send_player(player_name,
                            minetest.colorize("#FF00FF", "*** EPIC CHEST: You have 20 seconds to collect items! ***"))

                        -- Schedule auto-drop after 20 seconds
                        local pos_copy = vector.copy(pos)
                        minetest.after(20, function()
                            -- Check if chest still exists
                            local node = minetest.get_node(pos_copy)
                            if node.name ~= "quest_helper:puzzle_chest_epic" then
                                return  -- Chest already gone
                            end

                            local chest_meta = minetest.get_meta(pos_copy)
                            local chest_inv = chest_meta:get_inventory()

                            -- Drop all remaining items
                            local dropped_count = 0
                            for i = 1, chest_inv:get_size("main") do
                                local item_stack = chest_inv:get_stack("main", i)
                                if not item_stack:is_empty() then
                                    -- Drop item above chest position
                                    local drop_pos = vector.add(pos_copy, {x = math.random() - 0.5, y = 0.5, z = math.random() - 0.5})
                                    minetest.add_item(drop_pos, item_stack)
                                    dropped_count = dropped_count + 1
                                end
                            end

                            if dropped_count > 0 then
                                minetest.log("action", "[quest_helper] Epic chest at " .. minetest.pos_to_string(pos_copy) ..
                                    " timed out - dropped " .. dropped_count .. " items")

                                -- Notify nearby players
                                for _, p in ipairs(minetest.get_connected_players()) do
                                    if vector.distance(p:get_pos(), pos_copy) < 32 then
                                        minetest.chat_send_player(p:get_player_name(),
                                            minetest.colorize("#FF00FF", "*** The EPIC chest releases its remaining treasures! ***"))
                                    end
                                end
                            end

                            -- Vanish effect
                            minetest.sound_play("mcl_potions_brewing_finished", {
                                pos = pos_copy, gain = 1.0, max_hear_distance = 24
                            }, true)

                            minetest.add_particlespawner({
                                amount = 64,
                                time = 0.5,
                                minpos = vector.subtract(pos_copy, 0.5),
                                maxpos = vector.add(pos_copy, 0.5),
                                minvel = {x = -2, y = 2, z = -2},
                                maxvel = {x = 2, y = 5, z = 2},
                                minacc = {x = 0, y = -3, z = 0},
                                maxacc = {x = 0, y = -3, z = 0},
                                minexptime = 1,
                                maxexptime = 2,
                                minsize = 2,
                                maxsize = 4,
                                texture = "mcl_particles_crit.png^[colorize:#9932CC:200",
                                glow = 14,
                            })

                            minetest.remove_node(pos_copy)
                        end)
                    else
                        -- Show countdown hint
                        local elapsed = os.time() - loot_started
                        local remaining_time = math.max(0, 20 - elapsed)
                        if remaining_time > 0 then
                            minetest.chat_send_player(player_name,
                                minetest.colorize("#FFAA00", "(" .. remaining_count .. " item(s) remaining - " .. remaining_time .. "s until auto-drop)"))
                        end
                    end
                else
                    -- Non-epic chests: just notify about remaining items
                    if remaining_count <= 3 then
                        minetest.chat_send_player(player_name,
                            minetest.colorize("#FFAA00", "(" .. remaining_count .. " item(s) remaining in chest - is your inventory full?)"))
                    end
                end
            end

            if inv:is_empty("main") then
                -- Chest is empty - make it vanish with effect
                minetest.log("action", "[quest_helper] Puzzle chest at " .. minetest.pos_to_string(pos) ..
                    " emptied by " .. player_name .. " - removing")

                -- Play a magical vanish sound
                minetest.sound_play("mcl_potions_brewing_finished", {
                    pos = pos, gain = 0.8, max_hear_distance = 16
                }, true)

                -- Add sparkle particles with tier-specific color
                minetest.add_particlespawner({
                    amount = 32,
                    time = 0.5,
                    minpos = vector.subtract(pos, 0.5),
                    maxpos = vector.add(pos, 0.5),
                    minvel = {x = -1, y = 1, z = -1},
                    maxvel = {x = 1, y = 3, z = 1},
                    minacc = {x = 0, y = -2, z = 0},
                    maxacc = {x = 0, y = -2, z = 0},
                    minexptime = 0.5,
                    maxexptime = 1.5,
                    minsize = 1,
                    maxsize = 2,
                    texture = "mcl_particles_crit.png^[colorize:" .. config.particle_color .. ":200",
                    glow = 14,
                })

                -- Remove the chest
                minetest.remove_node(pos)

                -- Notify the player
                minetest.chat_send_player(player_name,
                    minetest.colorize(config.particle_color, "*** The " .. tier .. " puzzle chest vanishes in a puff of sparkles! ***"))
            end
        end,
    })
end

-- Register all puzzle chest variants
for tier, config in pairs(PUZZLE_CHEST_TIERS) do
    register_puzzle_chest(tier, config)
end

-- Handle formspec submission
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "quest_helper:puzzle_chest" then return end
    if not player then return end

    local player_name = player:get_player_name()

    -- Cancel button
    if fields.cancel or fields.quit then
        return true
    end

    -- Submit button or enter key
    if fields.submit or fields.key_enter_field then
        local player_meta = player:get_meta()
        local pos_str = player_meta:get_string("puzzle_chest_pos")
        if pos_str == "" then return true end

        local pos = minetest.string_to_pos(pos_str)
        if not pos then return true end

        -- Verify node still exists (check for any puzzle chest variant)
        local node = minetest.get_node(pos)
        if not is_puzzle_chest(node.name) then
            minetest.chat_send_player(player_name, "The puzzle chest is no longer there!")
            return true
        end

        local meta = minetest.get_meta(pos)
        local max_attempts = meta:get_int("max_attempts")
        local attempt_key = get_attempt_key(player_name, pos)

        -- Normalize answer: lowercase, trim spaces, collapse multiple spaces
        -- Also handles German umlauts and common accents for kid-friendly input
        local function normalize(str)
            str = str:lower()
            -- German umlaut normalization (kids might not have German keyboard)
            str = str:gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue"):gsub("ß", "ss")
            -- Handle uppercase umlauts too (before lowercase conversion might miss them)
            str = str:gsub("Ä", "ae"):gsub("Ö", "oe"):gsub("Ü", "ue")
            -- Common accent normalization
            str = str:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
            str = str:gsub("á", "a"):gsub("à", "a"):gsub("â", "a"):gsub("ã", "a")
            str = str:gsub("í", "i"):gsub("ì", "i"):gsub("î", "i"):gsub("ï", "i")
            str = str:gsub("ó", "o"):gsub("ò", "o"):gsub("ô", "o"):gsub("õ", "o")
            str = str:gsub("ú", "u"):gsub("ù", "u"):gsub("û", "u")
            str = str:gsub("ñ", "n"):gsub("ç", "c")
            -- Trim and collapse spaces
            str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
            return str
        end

        -- Normalize for strict comparison (also removes hyphens and spaces)
        local function normalize_strict(str)
            str = normalize(str)
            -- Remove hyphens and spaces for lenient matching
            str = str:gsub("%-", ""):gsub("%s", "")
            return str
        end

        -- Check if player answer matches any valid answer
        -- Supports multiple answers separated by | (e.g., "paris|paris france")
        -- Handles German umlauts, accents, spaces, and hyphens
        local function check_answer(player_ans, correct_ans)
            local player_normalized = normalize(player_ans)
            local player_strict = normalize_strict(player_ans)

            -- Check each valid answer (separated by |)
            for valid in correct_ans:gmatch("[^|]+") do
                local valid_normalized = normalize(valid)
                local valid_strict = normalize_strict(valid)

                -- Exact match after normalization
                if player_normalized == valid_normalized then return true end
                -- Strict match (ignoring spaces and hyphens)
                if player_strict == valid_strict then return true end
            end
            return false
        end

        local correct_answer = meta:get_string("answer")
        local player_answer = fields.answer or ""

        -- Check answer (case insensitive, space tolerant, multi-answer support)
        if check_answer(player_answer, correct_answer) then
            -- Correct! Mark chest as globally solved (prevents other players from re-solving)
            meta:set_int("solved", 1)
            meta:set_string("solved_by", player_name)
            meta:set_int("unlocked_" .. player_name, 1)
            puzzle_attempts[attempt_key] = nil  -- Reset attempts

            -- Award points (skip admins)
            if not is_admin(player_name) then
                local tier = meta:get_string("tier")
                local points = TIER_POINTS[tier] or TIER_POINTS["medium"]  -- Default to medium if tier not set

                local new_total = add_player_score(player_name, points)

                minetest.chat_send_player(player_name, minetest.colorize("#00FF00",
                    "*** Correct! The puzzle chest is now unlocked! +" .. points .. " points (Total: " .. new_total .. ") ***"))

                -- Check for lead change and update HUDs
                check_lead_change(player_name)
                update_all_huds()
            else
                minetest.chat_send_player(player_name, minetest.colorize("#00FF00", "*** Correct! The puzzle chest is now unlocked! ***"))
            end

            minetest.sound_play("mcl_chests_enderchest_open", {pos = pos, gain = 0.5, max_hear_distance = 16}, true)

            -- Close formspec and let them right-click again to access
            minetest.close_formspec(player_name, "quest_helper:puzzle_chest")
        else
            -- Wrong answer
            local attempts = (puzzle_attempts[attempt_key] or 0) + 1
            puzzle_attempts[attempt_key] = attempts

            if attempts >= max_attempts then
                -- BOOM!
                minetest.close_formspec(player_name, "quest_helper:puzzle_chest")
                minetest.after(0.2, function()
                    puzzle_explode(pos, player)
                end)
            else
                -- Wrong but more attempts remain
                local remaining = max_attempts - attempts
                minetest.chat_send_player(player_name,
                    minetest.colorize("#FF6600", "*** Wrong answer! " .. remaining .. " attempt(s) remaining. ***"))

                -- Update formspec with new attempt count
                local question = meta:get_string("question") .. " (Attempts: " .. attempts .. "/" .. max_attempts .. ")"
                minetest.show_formspec(player_name, "quest_helper:puzzle_chest", get_puzzle_formspec(pos, question))
            end
        end

        return true
    end

    return true
end)

-- /puzzlechest command - Place a puzzle chest with question and answer
-- y can be ~ for ground level auto-detection
-- Works remotely via CLI when coordinates are provided
minetest.register_chatcommand("puzzlechest", {
    params = "[<x> <y|~> <z>] <tier> <question> | <answer>",
    description = "Place a puzzle chest. Use ~ for ground level, | to separate question and answer. Example: /puzzlechest 100 ~ 200 medium What is 2+2? | four",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)

        local x, y_str, z, rest
        local pos, tier, qa_text

        -- Try to parse coordinates first (y can be number or ~, supports decimals)
        x, y_str, z, rest = param:match("^(-?%d+%.?%d*)%s+([~g%-]?%d*%.?%d*)%s+(-?%d+%.?%d*)%s+(.+)$")

        if x and y_str and z and rest then
            local y = parse_y_coord(y_str, tonumber(x), tonumber(z))
            pos = {x = tonumber(x), y = y, z = tonumber(z)}
            -- Parse tier and question|answer from rest
            tier, qa_text = rest:match("^(%w+)%s+(.+)$")
        else
            -- No coordinates, need player position
            if not player then
                return false, "Coordinates required when not in-game. Usage: /puzzlechest <x> <y|~> <z> <tier> <question> | <answer>"
            end
            tier, qa_text = param:match("^(%w+)%s+(.+)$")
            if not tier then
                return false, "Usage: /puzzlechest <tier> <question> | <answer> OR /puzzlechest <x> <y|~> <z> <tier> <question> | <answer>"
            end
            pos = vector.round(player:get_pos())
        end

        if not qa_text then
            return false, "Please provide question and answer separated by |"
        end

        -- Parse question and answer (separated by |)
        local question, answer = qa_text:match("^(.-)%s*|%s*(.+)$")
        if not question or not answer then
            return false, "Please separate question and answer with |. Example: What is the capital? | Paris"
        end

        question = question:gsub("^%s+", ""):gsub("%s+$", "")
        answer = answer:gsub("^%s+", ""):gsub("%s+$", "")

        if question == "" or answer == "" then
            return false, "Both question and answer are required"
        end

        -- Validate and normalize tier
        local tier_lower = tier:lower()
        if not PUZZLE_CHEST_TIERS[tier_lower] then
            return false, "Invalid tier. Use: small, medium, big, or epic"
        end

        -- Get the node name for this tier
        local node_name = "quest_helper:puzzle_chest_" .. tier_lower
        local tier_config = PUZZLE_CHEST_TIERS[tier_lower]

        -- Ensure the chunk is loaded before placing (critical for remote CLI commands)
        ensure_chunk_loaded(pos.x, pos.y, pos.z)

        -- Small delay to let chunk load, then place with callback
        minetest.after(0.5, function()
            -- Re-ensure chunk is loaded
            ensure_chunk_loaded(pos.x, pos.y, pos.z)

            -- Check what's at the position before placing
            local old_node = minetest.get_node(pos)
            minetest.log("action", "[quest_helper] Placing " .. tier_lower .. " puzzle chest at " .. minetest.pos_to_string(pos) ..
                " (replacing: " .. old_node.name .. ")")

            -- Place the tier-specific puzzle chest
            minetest.set_node(pos, {name = node_name})

            -- Verify placement
            local new_node = minetest.get_node(pos)
            if new_node.name ~= node_name then
                minetest.log("error", "[quest_helper] Failed to place puzzle chest! Got: " .. new_node.name)
            else
                minetest.log("action", "[quest_helper] " .. tier_config.description .. " successfully placed")
            end
        end)

        -- Set up metadata immediately (will be ready when minetest.after fires)
        minetest.after(0.6, function()
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            inv:set_size("main", 27)

            -- Set puzzle data
            meta:set_string("question", question)
            meta:set_string("answer", answer)
            meta:set_int("max_attempts", 3)
            meta:set_string("tier", tier_lower)  -- Store tier for point calculation
            meta:set_string("infotext", tier_config.infotext)

            -- Add loot based on tier
            local loot = {}

            if tier_lower == "small" then
                loot = {
                    {get_item("iron"), math.random(3, 8)},
                    {get_item("bread"), math.random(4, 10)},
                    {get_item("torch"), math.random(8, 16)},
                }
            elseif tier_lower == "medium" then
                loot = {
                    {get_item("iron"), math.random(8, 16)},
                    {get_item("gold"), math.random(4, 8)},
                    {get_item("diamond"), math.random(1, 3)},
                    {get_item("bread"), math.random(8, 16)},
                    {get_item("iron_sword"), 1},
                }
            elseif tier_lower == "big" then
                loot = {
                    {get_item("gold"), math.random(16, 32)},
                    {get_item("diamond"), math.random(4, 8)},
                    {get_item("emerald"), math.random(2, 5)},
                    {get_item("diamond_sword"), 1},
                    {get_item("diamond_pick"), 1},
                }
            elseif tier_lower == "epic" then
                loot = {
                    {get_item("diamondblock"), math.random(2, 5)},
                    {get_item("emerald"), math.random(8, 16)},
                    {get_item("diamond_sword"), 1},
                    {get_item("diamond_pick"), 1},
                    {get_item("helmet_diamond"), 1},
                    {get_item("chestplate_diamond"), 1},
                    {get_item("leggings_diamond"), 1},
                    {get_item("boots_diamond"), 1},
                }
            else
                -- Default to medium if tier not recognized
                loot = {
                    {get_item("iron"), math.random(8, 16)},
                    {get_item("gold"), math.random(4, 8)},
                    {get_item("diamond"), math.random(1, 3)},
                    {get_item("bread"), math.random(8, 16)},
                    {get_item("iron_sword"), 1},
                }
            end

            -- Add items to chest
            for _, item in ipairs(loot) do
                if item[1] and item[2] then
                    inv:add_item("main", item[1] .. " " .. item[2])
                end
            end

            minetest.log("action", "[quest_helper] Puzzle chest loot added at " .. minetest.pos_to_string(pos))
        end)

        -- Build warning message if Y seems underground
        local warning = ""
        if pos.y < 40 then
            warning = " WARNING: Y=" .. pos.y .. " may be underground! Surface is typically Y=60+. Consider using ~ for auto ground level."
        end

        return true, "Placed " .. tier_config.description .. " at (" .. pos.x .. "," .. pos.y .. "," .. pos.z ..
            ") (Question: " .. question .. ")" .. warning
    end,
})

-- ============================================
-- VANISH FEATURE
-- Make admin invisible to other players
-- ============================================

-- Track vanished players
local vanished_players = {}

-- Store original player properties for restoration
local original_properties = {}

-- /vanish - Toggle invisibility for admin
minetest.register_chatcommand("vanish", {
    params = "",
    description = "Toggle invisibility - become invisible to other players while placing chests",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        if vanished_players[name] then
            -- Unvanish - restore visibility
            vanished_players[name] = nil

            -- Restore original properties
            if original_properties[name] then
                player:set_properties(original_properties[name])
                original_properties[name] = nil
            else
                -- Fallback: reset to default player appearance
                player:set_properties({
                    visual_size = {x = 1, y = 1, z = 1},
                    makes_footstep_sound = true,
                    collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.77, 0.3},
                    selectionbox = {-0.3, 0.0, -0.3, 0.3, 1.77, 0.3},
                    pointable = true,
                })
            end

            -- Restore nametag
            player:set_nametag_attributes({
                color = {a = 255, r = 255, g = 255, b = 255},
                bgcolor = false,  -- Use default background
                text = name,
            })

            -- Restore nametag and visibility in properties too
            player:set_properties({
                nametag = name,
                nametag_color = {a = 255, r = 255, g = 255, b = 255},
                show_on_minimap = true,
                is_visible = true,
            })

            -- Restore visibility of any child objects
            for _, child in pairs(player:get_children()) do
                if child and child:get_luaentity() then
                    child:set_properties({is_visible = true})
                end
            end

            minetest.chat_send_player(name, minetest.colorize("#00FF00", "*** You are now VISIBLE to other players ***"))
            return true, "Vanish mode OFF - you are now visible"
        else
            -- Vanish - become invisible
            vanished_players[name] = true

            -- Store original properties
            original_properties[name] = player:get_properties()

            -- Function to apply all vanish properties
            local function apply_vanish(p, pname)
                if not p or not p:is_player() then return end
                if not vanished_players[pname] then return end  -- Unvanished before delay

                -- Make player invisible - comprehensive property set
                p:set_properties({
                    visual_size = {x = 0, y = 0, z = 0},  -- Shrink to invisible
                    makes_footstep_sound = false,  -- Silent footsteps
                    pointable = false,  -- Can't be targeted/selected by others
                    show_on_minimap = false,  -- Hide from minimap
                    is_visible = false,  -- Explicitly set invisible
                    nametag = " ",  -- Space instead of empty (some engines handle empty differently)
                    nametag_color = {a = 0, r = 0, g = 0, b = 0},
                    nametag_bgcolor = {a = 0, r = 0, g = 0, b = 0},
                    infotext = "",  -- Clear any hover text
                })

                -- Hide nametag completely using nametag attributes API
                p:set_nametag_attributes({
                    color = {a = 0, r = 0, g = 0, b = 0},  -- Fully transparent text
                    bgcolor = {a = 0, r = 0, g = 0, b = 0},  -- Fully transparent background
                    text = " ",  -- Single space
                })

                -- Try to hide any attached child objects (some games use these for names)
                for _, child in pairs(p:get_children()) do
                    if child and child:get_luaentity() then
                        child:set_properties({is_visible = false})
                    end
                end
            end

            -- Apply immediately
            apply_vanish(player, name)

            -- Re-apply after delays to override any game systems that reset properties
            minetest.after(0.1, function() apply_vanish(minetest.get_player_by_name(name), name) end)
            minetest.after(0.5, function() apply_vanish(minetest.get_player_by_name(name), name) end)
            minetest.after(1.0, function() apply_vanish(minetest.get_player_by_name(name), name) end)
            minetest.after(2.0, function() apply_vanish(minetest.get_player_by_name(name), name) end)

            minetest.chat_send_player(name, minetest.colorize("#FFD700", "*** You are now INVISIBLE to other players ***"))
            minetest.chat_send_player(name, minetest.colorize("#AAAAAA", "Use /vanish again to become visible"))
            return true, "Vanish mode ON - you are now invisible"
        end
    end,
})

-- Clean up when player leaves
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    vanished_players[name] = nil
    original_properties[name] = nil
end)

-- ============================================
-- SCOREBOARD COMMANDS
-- ============================================

-- /leaderboard - Show top players
minetest.register_chatcommand("leaderboard", {
    params = "",
    description = "Show the puzzle chest leaderboard",
    privs = {},
    func = function(name, param)
        local leaderboard = get_leaderboard(10)

        if #leaderboard == 0 then
            return true, "No scores yet! Solve puzzle chests to earn points."
        end

        local lines = {"=== PUZZLE CHEST LEADERBOARD ==="}
        for i, entry in ipairs(leaderboard) do
            local medal = ""
            if i == 1 then medal = " [1st]"
            elseif i == 2 then medal = " [2nd]"
            elseif i == 3 then medal = " [3rd]"
            end
            table.insert(lines, i .. ". " .. entry.name .. " - " .. entry.score .. " points" .. medal)
        end

        return true, table.concat(lines, "\n")
    end,
})

-- /myscore - Show your own score
minetest.register_chatcommand("myscore", {
    params = "",
    description = "Show your puzzle chest score and rank",
    privs = {},
    func = function(name, param)
        local score = get_player_score(name)
        local leaderboard = get_leaderboard()

        -- Find player's rank
        local rank = 0
        for i, entry in ipairs(leaderboard) do
            if entry.name == name then
                rank = i
                break
            end
        end

        if score == 0 then
            return true, "You have 0 points. Solve puzzle chests to earn points!"
        end

        local rank_str = ""
        if rank > 0 then
            rank_str = " (Rank #" .. rank .. " of " .. #leaderboard .. ")"
        end

        return true, "Your score: " .. score .. " points" .. rank_str
    end,
})

-- /hud - Toggle leaderboard HUD visibility
minetest.register_chatcommand("hud", {
    params = "",
    description = "Toggle the leaderboard HUD display on/off",
    privs = {},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local player_meta = player:get_meta()
        local hud_disabled = player_meta:get_int("hud_disabled")

        if hud_disabled == 1 then
            -- Enable HUD
            player_meta:set_int("hud_disabled", 0)
            update_player_hud(player)
            return true, "Leaderboard HUD enabled"
        else
            -- Disable HUD
            player_meta:set_int("hud_disabled", 1)
            remove_player_hud(player)
            return true, "Leaderboard HUD disabled"
        end
    end,
})

-- /resetscores - Admin command to reset all scores
minetest.register_chatcommand("resetscores", {
    params = "",
    description = "Reset all puzzle chest scores (admin only)",
    privs = {server = true},
    func = function(name, param)
        -- Clear all scores
        save_all_scores({})
        current_leader = nil

        -- Update all HUDs
        update_all_huds()

        minetest.chat_send_all(minetest.colorize("#FF6600", "*** All puzzle chest scores have been reset! ***"))
        minetest.log("action", "[quest_helper] Scores reset by " .. name)

        return true, "All scores have been reset"
    end,
})

-- ============================================
-- QUESTION POOL & CHESTMODE SYSTEM
-- Load questions from JSON, admin GUI placement mode
-- ============================================

-- Question pool storage
local question_pool = {
    easy = {},
    medium = {},
    hard = {},
    expert = {},
}

-- Track used question IDs persistently (survives restarts)
-- Load from mod storage
local function get_used_questions()
    local json = storage:get_string("used_questions")
    if json == "" then
        return {}
    end
    return minetest.parse_json(json) or {}
end

-- Save to mod storage
local function save_used_questions(used)
    storage:set_string("used_questions", minetest.write_json(used))
end

-- Mark a question as used
local function mark_question_used(question_id)
    local used = get_used_questions()
    used[question_id] = true
    save_used_questions(used)
end

-- Check if a question is used
local function is_question_used(question_id)
    local used = get_used_questions()
    return used[question_id] == true
end

-- Clear all used questions
local function clear_used_questions()
    storage:set_string("used_questions", "")
    minetest.log("action", "[quest_helper] Used questions cleared")
end

-- Get count of used questions
local function get_used_questions_count()
    local used = get_used_questions()
    local count = 0
    for _ in pairs(used) do
        count = count + 1
    end
    return count
end

-- Track players in placement mode
local placement_mode = {}

-- Simple JSON parser for our specific format (Minetest's parse_json works for this)
local function load_questions_from_file()
    local modpath = minetest.get_modpath("quest_helper")
    local filepath = modpath .. "/questions.json"

    -- Try to read the file
    local file = io.open(filepath, "r")
    if not file then
        minetest.log("warning", "[quest_helper] Could not open questions.json at " .. filepath)
        return false
    end

    local content = file:read("*all")
    file:close()

    if not content or content == "" then
        minetest.log("warning", "[quest_helper] questions.json is empty")
        return false
    end

    -- Parse JSON
    local data = minetest.parse_json(content)
    if not data then
        minetest.log("error", "[quest_helper] Failed to parse questions.json")
        return false
    end

    -- Clear existing pools
    question_pool = {
        easy = {},
        medium = {},
        hard = {},
        expert = {},
    }

    -- Load questions into pools
    local count = 0
    for difficulty, questions in pairs(data) do
        if difficulty ~= "metadata" and type(questions) == "table" then
            question_pool[difficulty] = questions
            count = count + #questions
            minetest.log("action", "[quest_helper] Loaded " .. #questions .. " " .. difficulty .. " questions")
        end
    end

    minetest.log("action", "[quest_helper] Total questions loaded: " .. count)
    return true, count
end

-- Load questions on mod init
minetest.after(0, function()
    load_questions_from_file()
end)

-- Get a random question from pool, optionally filtered by category
-- Returns {question, answer, hint, category, difficulty} or nil
local function get_random_question(difficulty, category)
    local pool = question_pool[difficulty]
    if not pool or #pool == 0 then
        -- Fallback to medium if requested difficulty is empty
        pool = question_pool["medium"]
        difficulty = "medium"
    end

    if not pool or #pool == 0 then
        return nil
    end

    -- Filter by category if specified, exclude used questions
    local filtered = {}
    if category and category ~= "any" and category ~= "" then
        for _, q in ipairs(pool) do
            if q.category == category then
                -- Check if not already used (persistent check)
                if not is_question_used(q.id) then
                    table.insert(filtered, q)
                end
            end
        end
    else
        -- No category filter, just exclude used questions
        for _, q in ipairs(pool) do
            if not is_question_used(q.id) then
                table.insert(filtered, q)
            end
        end
    end

    -- If all questions used, reset and try again
    if #filtered == 0 then
        minetest.log("action", "[quest_helper] All questions used for " .. difficulty .. "/" .. (category or "any") .. ", resetting pool")
        clear_used_questions()
        -- Retry without used filter
        if category and category ~= "any" and category ~= "" then
            for _, q in ipairs(pool) do
                if q.category == category then
                    table.insert(filtered, q)
                end
            end
        else
            filtered = pool
        end
    end

    if #filtered == 0 then
        return nil
    end

    -- Pick random question
    local idx = math.random(1, #filtered)
    local q = filtered[idx]

    -- Mark as used (persistent)
    mark_question_used(q.id)

    return {
        question = q.q,
        answer = q.a,
        hint = q.hint,
        category = q.category,
        difficulty = difficulty,
        id = q.id,
    }
end

-- Map difficulty selection to chest tiers
local DIFFICULTY_TO_TIER = {
    easy = "small",
    medium = "medium",
    hard = "big",
    expert = "epic",
}

-- Get chestmode configuration formspec
local function get_chestmode_formspec(player_name)
    local mode = placement_mode[player_name] or {}
    local current_tier = mode.tier or "random"
    local current_difficulty = mode.difficulty or "random"
    local current_category = mode.category or "any"

    -- Build tier dropdown (1-indexed for formspec) - includes "random" option
    local tiers = {"random", "small", "medium", "big", "epic"}
    local tier_idx = 1
    for i, t in ipairs(tiers) do
        if t == current_tier then tier_idx = i break end
    end

    -- Build difficulty dropdown - includes "random" option
    local difficulties = {"random", "easy", "medium", "hard", "expert"}
    local diff_idx = 1
    for i, d in ipairs(difficulties) do
        if d == current_difficulty then diff_idx = i break end
    end

    -- Build category dropdown
    local categories = {"any", "math", "science", "geography", "nature", "history", "general"}
    local cat_idx = 1
    for i, c in ipairs(categories) do
        if c == current_category then cat_idx = i break end
    end

    local enabled_text = mode.enabled and "ENABLED (punch to place)" or "DISABLED"
    local toggle_label = mode.enabled and "Disable" or "Enable"
    local status_color = mode.enabled and "#00FF00" or "#FF6666"

    return "formspec_version[4]" ..
           "size[8,7]" ..
           "label[0.5,0.5;PUZZLE CHEST PLACEMENT MODE]" ..
           "label[0.5,1.0;" .. minetest.colorize(status_color, "Status: " .. enabled_text) .. "]" ..
           "label[0.5,1.8;Chest Tier (reward level):]" ..
           "dropdown[0.5,2.1;3,0.6;tier;random,small,medium,big,epic;" .. tier_idx .. ";true]" ..
           "label[4,1.8;Question Difficulty:]" ..
           "dropdown[4,2.1;3.5,0.6;difficulty;random,easy,medium,hard,expert;" .. diff_idx .. ";true]" ..
           "label[0.5,3.2;Question Category:]" ..
           "dropdown[0.5,3.5;3,0.6;category;any,math,science,geography,nature,history,general;" .. cat_idx .. ";true]" ..
           "label[4,3.2;Hint:]" ..
           "label[4,3.6;Punch any block to place]" ..
           "label[4,4.0;chest at that location]" ..
           "button[0.5,5;3,0.8;toggle;" .. toggle_label .. " Mode]" ..
           "button_exit[4,5;3.5,0.8;close;Close]" ..
           "label[0.5,6.2;" .. minetest.colorize("#888888", "Tip: Use /chestmode to open this menu") .. "]"
end

-- Lookup tables for dropdown index -> value conversion
local TIER_VALUES = {"random", "small", "medium", "big", "epic"}
local DIFFICULTY_VALUES = {"random", "easy", "medium", "hard", "expert"}
local CATEGORY_VALUES = {"any", "math", "science", "geography", "nature", "history", "general"}

-- Actual values for random selection (excludes "random" itself)
local ACTUAL_TIERS = {"small", "medium", "big", "epic"}
local ACTUAL_DIFFICULTIES = {"easy", "medium", "hard", "expert"}

-- Handle chestmode formspec
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "quest_helper:chestmode" then return end
    if not player then return end

    local player_name = player:get_player_name()
    if not is_admin(player_name) then return true end

    -- Initialize mode if needed
    if not placement_mode[player_name] then
        placement_mode[player_name] = {
            enabled = false,
            tier = "random",
            difficulty = "random",
            category = "any",
        }
    end

    local mode = placement_mode[player_name]

    -- Handle dropdown changes (dropdown with index_event returns index as string)
    if fields.tier then
        local idx = tonumber(fields.tier)
        if idx and TIER_VALUES[idx] then
            mode.tier = TIER_VALUES[idx]
        end
    end
    if fields.difficulty then
        local idx = tonumber(fields.difficulty)
        if idx and DIFFICULTY_VALUES[idx] then
            mode.difficulty = DIFFICULTY_VALUES[idx]
        end
    end
    if fields.category then
        local idx = tonumber(fields.category)
        if idx and CATEGORY_VALUES[idx] then
            mode.category = CATEGORY_VALUES[idx]
        end
    end

    -- Handle toggle button
    if fields.toggle then
        mode.enabled = not mode.enabled

        -- Safety: ensure tier is a valid string (not an index)
        local tier_display = mode.tier
        if tier_display and tonumber(tier_display) then
            -- It's still an index number, convert it
            local idx = tonumber(tier_display)
            if idx and TIER_VALUES[idx] then
                mode.tier = TIER_VALUES[idx]
                tier_display = mode.tier
            else
                tier_display = "random"
                mode.tier = "random"
            end
        end

        local tier_text = tier_display == "random" and "random tier" or tier_display
        if mode.enabled then
            minetest.chat_send_player(player_name, minetest.colorize("#00FF00",
                "*** Chest placement mode ENABLED! Punch blocks to place " .. tier_text .. " chests ***"))
        else
            minetest.chat_send_player(player_name, minetest.colorize("#FF6666",
                "*** Chest placement mode DISABLED ***"))
        end

        -- Refresh formspec
        minetest.show_formspec(player_name, "quest_helper:chestmode", get_chestmode_formspec(player_name))
        return true
    end

    -- Close just closes
    if fields.close or fields.quit then
        return true
    end

    return true
end)

-- /chestmode command - Open placement mode GUI
minetest.register_chatcommand("chestmode", {
    params = "[on|off]",
    description = "Open puzzle chest placement mode GUI, or toggle with on/off",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        -- Initialize mode if needed
        if not placement_mode[name] then
            placement_mode[name] = {
                enabled = false,
                tier = "random",
                difficulty = "random",
                category = "any",
            }
        end

        -- Handle quick on/off
        if param == "on" then
            placement_mode[name].enabled = true
            return true, "Chest placement mode ENABLED (random tier/difficulty). Punch blocks to place chests. Use /chestmode off to disable."
        elseif param == "off" then
            placement_mode[name].enabled = false
            return true, "Chest placement mode DISABLED."
        end

        -- Show GUI
        minetest.show_formspec(name, "quest_helper:chestmode", get_chestmode_formspec(name))
        return true, "Opening chest placement mode settings..."
    end,
})

-- Handle punch to place chest when in placement mode
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if not puncher then return end
    local player_name = puncher:get_player_name()

    -- Check if player is in placement mode
    local mode = placement_mode[player_name]
    if not mode or not mode.enabled then return end

    -- Must be admin
    if not is_admin(player_name) then return end

    -- Don't place on puzzle chests (allow punching to check them)
    if is_puzzle_chest(node.name) then return end

    -- Get position above the punched node (place on top)
    local place_pos = {x = pos.x, y = pos.y + 1, z = pos.z}

    -- Check if position is air or replaceable
    local target_node = minetest.get_node(place_pos)
    if target_node.name ~= "air" and not minetest.registered_nodes[target_node.name].buildable_to then
        minetest.chat_send_player(player_name, minetest.colorize("#FF6666", "Cannot place chest there - position is occupied"))
        return
    end

    -- Resolve random selections
    local actual_difficulty = mode.difficulty
    if actual_difficulty == "random" then
        actual_difficulty = ACTUAL_DIFFICULTIES[math.random(1, #ACTUAL_DIFFICULTIES)]
    end

    local actual_tier = mode.tier
    if actual_tier == "random" then
        actual_tier = ACTUAL_TIERS[math.random(1, #ACTUAL_TIERS)]
    end

    -- Get a random question
    local q = get_random_question(actual_difficulty, mode.category)
    if not q then
        minetest.chat_send_player(player_name, minetest.colorize("#FF6666",
            "No questions available for " .. actual_difficulty .. "/" .. mode.category .. "!"))
        return
    end

    -- Place the chest
    local tier = actual_tier
    local node_name = "quest_helper:puzzle_chest_" .. tier
    local tier_config = PUZZLE_CHEST_TIERS[tier]

    minetest.set_node(place_pos, {name = node_name})

    -- Set up metadata
    local meta = minetest.get_meta(place_pos)
    local inv = meta:get_inventory()
    inv:set_size("main", 27)

    meta:set_string("question", q.question)
    meta:set_string("answer", q.answer)
    meta:set_int("max_attempts", 3)
    meta:set_string("tier", tier)
    meta:set_string("infotext", tier_config.infotext)

    -- Add loot based on tier
    local loot = {}
    if tier == "small" then
        loot = {
            {get_item("iron"), math.random(3, 8)},
            {get_item("bread"), math.random(4, 10)},
            {get_item("torch"), math.random(8, 16)},
        }
    elseif tier == "medium" then
        loot = {
            {get_item("iron"), math.random(8, 16)},
            {get_item("gold"), math.random(4, 8)},
            {get_item("diamond"), math.random(1, 3)},
            {get_item("bread"), math.random(8, 16)},
            {get_item("iron_sword"), 1},
        }
    elseif tier == "big" then
        loot = {
            {get_item("gold"), math.random(16, 32)},
            {get_item("diamond"), math.random(4, 8)},
            {get_item("emerald"), math.random(2, 5)},
            {get_item("diamond_sword"), 1},
            {get_item("diamond_pick"), 1},
        }
    elseif tier == "epic" then
        loot = {
            {get_item("diamondblock"), math.random(2, 5)},
            {get_item("emerald"), math.random(8, 16)},
            {get_item("diamond_sword"), 1},
            {get_item("diamond_pick"), 1},
            {get_item("helmet_diamond"), 1},
            {get_item("chestplate_diamond"), 1},
            {get_item("leggings_diamond"), 1},
            {get_item("boots_diamond"), 1},
        }
    end

    for _, item in ipairs(loot) do
        if item[1] and item[2] then
            inv:add_item("main", item[1] .. " " .. item[2])
        end
    end

    -- Play placement sound
    minetest.sound_play("default_place_node", {pos = place_pos, gain = 0.5}, true)

    -- Notify admin
    minetest.chat_send_player(player_name, minetest.colorize("#00FF00",
        "Placed " .. tier_config.description .. " at " .. minetest.pos_to_string(place_pos)))
    minetest.chat_send_player(player_name, minetest.colorize("#AAAAAA",
        "Q: " .. q.question .. " | Category: " .. q.category))

    minetest.log("action", "[quest_helper] " .. player_name .. " placed puzzle chest via chestmode at " ..
        minetest.pos_to_string(place_pos) .. " (Question ID: " .. q.id .. ")")
end)

-- /reloadquestions - Hot reload questions from file
minetest.register_chatcommand("reloadquestions", {
    params = "",
    description = "Reload questions from questions.json without restarting server",
    privs = {server = true},
    func = function(name, param)
        local success, count = load_questions_from_file()
        if success then
            -- Reset used questions on reload
            used_questions = {}
            return true, "Reloaded " .. count .. " questions from questions.json"
        else
            return false, "Failed to reload questions - check server log for details"
        end
    end,
})

-- /questionstats - Show question pool statistics
minetest.register_chatcommand("questionstats", {
    params = "",
    description = "Show statistics about the question pool",
    privs = {server = true},
    func = function(name, param)
        local stats = {}
        local total = 0

        for difficulty, pool in pairs(question_pool) do
            local count = #pool
            total = total + count
            stats[difficulty] = count
        end

        local used_count = get_used_questions_count()

        local lines = {"=== QUESTION POOL STATS ==="}
        table.insert(lines, "Easy: " .. (stats.easy or 0) .. " questions")
        table.insert(lines, "Medium: " .. (stats.medium or 0) .. " questions")
        table.insert(lines, "Hard: " .. (stats.hard or 0) .. " questions")
        table.insert(lines, "Expert: " .. (stats.expert or 0) .. " questions")
        table.insert(lines, "Total: " .. total .. " questions")
        table.insert(lines, "Used (persistent): " .. used_count .. "/" .. total)
        table.insert(lines, "Remaining: " .. (total - used_count))

        return true, table.concat(lines, "\n")
    end,
})

-- /resetquestions - Clear used questions to make all available again
minetest.register_chatcommand("resetquestions", {
    params = "",
    description = "Reset used questions - makes all questions available again",
    privs = {server = true},
    func = function(name, param)
        local old_count = get_used_questions_count()
        clear_used_questions()
        minetest.log("action", "[quest_helper] " .. name .. " reset " .. old_count .. " used questions")
        return true, "Cleared " .. old_count .. " used questions. All questions are now available again."
    end,
})

-- ============================================
-- SCATTER COMMAND
-- Automatically distribute puzzle chests in an area
-- ============================================

-- Configuration
local SCATTER_MIN_SPACING = 8       -- Minimum blocks between chests
local SCATTER_MIN_HEIGHT = 0        -- Minimum Y level (avoid deep underground)
local SCATTER_MAX_COUNT = 100       -- Maximum chests per scatter
local SCATTER_CONCEALMENT_THRESHOLD = 3  -- Minimum score to place
local SCATTER_MAX_RETRIES = 10      -- Retries per chest for finding good spot

-- Calculate concealment score for a position
-- Higher score = better hiding spot
local function calculate_concealment_score(pos)
    local score = 0
    local x, y, z = pos.x, pos.y, pos.z

    -- Check for overhead cover (leaves, blocks above within 8 blocks)
    local has_leaves = false
    local has_cover = false
    for check_y = y + 1, y + 8 do
        local node = minetest.get_node({x = x, y = check_y, z = z})
        local name = node.name
        if name ~= "air" and name ~= "ignore" then
            has_cover = true
            if name:find("leaves") or name:find("leaf") then
                has_leaves = true
                break
            end
        end
    end

    if has_leaves then
        score = score + 3  -- Under tree canopy
    elseif has_cover then
        score = score + 1  -- Some overhead cover
    end

    -- Check for nearby walls (solid blocks at chest level in 4 directions)
    local wall_count = 0
    local directions = {
        {x = 1, z = 0}, {x = -1, z = 0},
        {x = 0, z = 1}, {x = 0, z = -1},
    }

    for _, dir in ipairs(directions) do
        local check_pos = {x = x + dir.x, y = y, z = z + dir.z}
        local node = minetest.get_node(check_pos)
        local name = node.name
        -- Check if it's a solid block (not air, not plants, not water)
        if name ~= "air" and name ~= "ignore" and
           not name:find("water") and not name:find("lava") and
           not name:find("flower") and not name:find("tallgrass") and
           not name:find("fern") and not name:find("bush") then
            -- Check if it's actually a wall (block above is also solid or this is tall)
            local above = minetest.get_node({x = check_pos.x, y = check_pos.y + 1, z = check_pos.z})
            if above.name ~= "air" or name:find("stone") or name:find("dirt") or name:find("sand") then
                wall_count = wall_count + 1
            end
        end
    end

    score = score + (wall_count * 2)  -- +2 per wall

    -- Bonus for corner (2+ walls)
    if wall_count >= 2 then
        score = score + 2
    end

    -- Check for depression (chest is lower than neighbors)
    local lower_count = 0
    for _, dir in ipairs(directions) do
        local neighbor_y = find_ground_level(x + dir.x * 2, z + dir.z * 2)
        if neighbor_y > y then
            lower_count = lower_count + 1
        end
    end
    if lower_count >= 2 then
        score = score + 2  -- In a depression
    end

    -- Penalty for completely open flat area
    if wall_count == 0 and not has_cover and lower_count == 0 then
        score = score - 5
    end

    return score
end

-- Check if position is valid for chest placement
local function is_valid_scatter_position(pos)
    local x, y, z = pos.x, pos.y, pos.z

    -- Check minimum height
    if y < SCATTER_MIN_HEIGHT then
        return false, "too deep"
    end

    -- Check the block at position (should be air or replaceable)
    local node = minetest.get_node(pos)
    if node.name ~= "air" then
        local def = minetest.registered_nodes[node.name]
        if not def or not def.buildable_to then
            return false, "blocked"
        end
    end

    -- Check block below (should be solid ground)
    local below = minetest.get_node({x = x, y = y - 1, z = z})
    local below_name = below.name
    if below_name == "air" or below_name == "ignore" then
        return false, "no ground"
    end

    -- Skip water and lava
    if below_name:find("water") or below_name:find("lava") then
        return false, "water/lava"
    end

    return true
end

-- Check minimum spacing from existing placed chests
local function check_spacing(pos, placed_positions)
    for _, placed_pos in ipairs(placed_positions) do
        local dist = vector.distance(pos, placed_pos)
        if dist < SCATTER_MIN_SPACING then
            return false
        end
    end
    return true
end

-- Helper to place a single chest at position (reuses chestmode logic)
local function place_scatter_chest(pos, mode, player_name)
    -- Resolve random selections
    local actual_difficulty = mode.difficulty
    if actual_difficulty == "random" then
        actual_difficulty = ACTUAL_DIFFICULTIES[math.random(1, #ACTUAL_DIFFICULTIES)]
    end

    local actual_tier = mode.tier
    if actual_tier == "random" then
        actual_tier = ACTUAL_TIERS[math.random(1, #ACTUAL_TIERS)]
    end

    -- Get a random question
    local q = get_random_question(actual_difficulty, mode.category)
    if not q then
        return false, "no questions"
    end

    -- Place the chest
    local tier = actual_tier
    local node_name = "quest_helper:puzzle_chest_" .. tier
    local tier_config = PUZZLE_CHEST_TIERS[tier]

    minetest.set_node(pos, {name = node_name})

    -- Set up metadata
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    inv:set_size("main", 27)

    meta:set_string("question", q.question)
    meta:set_string("answer", q.answer)
    meta:set_int("max_attempts", 3)
    meta:set_string("tier", tier)
    meta:set_string("infotext", tier_config.infotext)

    -- Add loot based on tier
    local loot = {}
    if tier == "small" then
        loot = {
            {get_item("iron"), math.random(3, 8)},
            {get_item("bread"), math.random(4, 10)},
            {get_item("torch"), math.random(8, 16)},
        }
    elseif tier == "medium" then
        loot = {
            {get_item("iron"), math.random(8, 16)},
            {get_item("gold"), math.random(4, 8)},
            {get_item("diamond"), math.random(1, 3)},
            {get_item("bread"), math.random(8, 16)},
            {get_item("iron_sword"), 1},
        }
    elseif tier == "big" then
        loot = {
            {get_item("gold"), math.random(16, 32)},
            {get_item("diamond"), math.random(4, 8)},
            {get_item("emerald"), math.random(2, 5)},
            {get_item("diamond_sword"), 1},
            {get_item("diamond_pick"), 1},
        }
    elseif tier == "epic" then
        loot = {
            {get_item("diamondblock"), math.random(2, 5)},
            {get_item("emerald"), math.random(8, 16)},
            {get_item("diamond_sword"), 1},
            {get_item("diamond_pick"), 1},
            {get_item("helmet_diamond"), 1},
            {get_item("chestplate_diamond"), 1},
            {get_item("leggings_diamond"), 1},
            {get_item("boots_diamond"), 1},
        }
    end

    for _, item in ipairs(loot) do
        if item[1] and item[2] then
            inv:add_item("main", item[1] .. " " .. item[2])
        end
    end

    return true, tier
end

-- Try to find ground level quickly, returns nil if chunk not loaded
local function find_ground_level_fast(x, z)
    -- Quick check if area is loaded
    local test_node = minetest.get_node({x = x, y = 64, z = z})
    if test_node.name == "ignore" then
        return nil  -- Chunk not loaded
    end

    -- Scan from y=100 down
    for y = 100, -20, -1 do
        local node = minetest.get_node({x = x, y = y, z = z})
        local name = node.name

        if name == "ignore" then
            return nil  -- Hit unloaded area
        end

        -- Skip non-solid blocks
        if name ~= "air" and
           not name:find("water") and not name:find("lava") and
           not name:find("tallgrass") and not name:find("flower") and
           not name:find("fern") and not name:find("bush") and
           not name:find("snow") and not name:find("leaves") then
            return y  -- Found solid ground
        end
    end

    return nil  -- No ground found
end

-- /scatter command - Distribute chests randomly in an area
minetest.register_chatcommand("scatter", {
    params = "<radius> <count>",
    description = "Scatter puzzle chests randomly in a radius (max 200). Uses current /chestmode settings. Example: /scatter 50 20",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        -- Parse parameters
        local radius, count = param:match("^(%d+)%s+(%d+)$")
        radius = tonumber(radius)
        count = tonumber(count)

        if not radius or not count then
            return false, "Usage: /scatter <radius> <count>  Example: /scatter 50 20"
        end

        if radius < 10 then
            return false, "Radius must be at least 10 blocks"
        end

        if radius > 200 then
            return false, "Radius cannot exceed 200 blocks (chunks may not be loaded)"
        end

        if count < 1 then
            return false, "Count must be at least 1"
        end

        if count > SCATTER_MAX_COUNT then
            return false, "Count cannot exceed " .. SCATTER_MAX_COUNT
        end

        -- Get placement mode settings, with proper defaults
        -- Don't rely on placement_mode which may have index values
        local mode = {
            tier = "random",
            difficulty = "random",
            category = "any",
        }

        -- Copy valid string values from placement_mode if they exist
        local pm = placement_mode[name]
        if pm then
            -- Validate tier is a valid string, not an index
            if pm.tier and (pm.tier == "random" or pm.tier == "small" or pm.tier == "medium" or pm.tier == "big" or pm.tier == "epic") then
                mode.tier = pm.tier
            end
            -- Validate difficulty
            if pm.difficulty and (pm.difficulty == "random" or pm.difficulty == "easy" or pm.difficulty == "medium" or pm.difficulty == "hard" or pm.difficulty == "expert") then
                mode.difficulty = pm.difficulty
            end
            -- Validate category
            if pm.category and (pm.category == "any" or pm.category == "math" or pm.category == "science" or pm.category == "geography" or pm.category == "nature" or pm.category == "history" or pm.category == "general") then
                mode.category = pm.category
            end
        end

        -- Get center position (player position)
        local center = vector.round(player:get_pos())

        -- Start scatter process
        minetest.chat_send_player(name, minetest.colorize("#FFD700",
            "Starting scatter: " .. count .. " chests within " .. radius .. " blocks..."))
        minetest.chat_send_player(name, minetest.colorize("#AAAAAA",
            "Settings: tier=" .. mode.tier .. ", difficulty=" .. mode.difficulty .. ", category=" .. mode.category))

        local placed_positions = {}
        local placed_count = 0
        local failed_count = 0
        local exposed_count = 0
        local current_chest = 0
        local total_retries = 0
        local max_total_retries = count * 50  -- Safety limit

        -- Process chests one at a time with delays
        local function process_next_chest()
            current_chest = current_chest + 1
            total_retries = total_retries + 1

            -- Safety check to prevent infinite loops
            if total_retries > max_total_retries then
                minetest.chat_send_player(name, minetest.colorize("#FF6666",
                    "Scatter aborted: too many retries. Placed " .. placed_count .. "/" .. count))
                return
            end

            if current_chest > count then
                -- Done! Send summary
                local msg = "Scatter complete: " .. placed_count .. "/" .. count .. " chests placed"
                if failed_count > 0 then
                    msg = msg .. " (" .. failed_count .. " failed)"
                end
                if exposed_count > 0 then
                    msg = msg .. " (" .. exposed_count .. " exposed)"
                end
                minetest.chat_send_player(name, minetest.colorize("#00FF00", msg))
                minetest.log("action", "[quest_helper] " .. name .. " scattered " .. placed_count .. " chests, radius=" .. radius)
                return
            end

            -- Progress update every 5 chests
            if (current_chest - 1) % 5 == 0 then
                minetest.chat_send_player(name, minetest.colorize("#AAAAAA",
                    "Placing chests... " .. placed_count .. "/" .. count))
            end

            -- Try to find a good position
            local best_pos = nil
            local best_score = -999
            local retry_this_chest = 0

            for retry = 1, SCATTER_MAX_RETRIES do
                retry_this_chest = retry

                -- Generate random position in circle
                local angle = math.random() * 2 * math.pi
                local dist = math.sqrt(math.random()) * radius
                local try_x = center.x + math.floor(dist * math.cos(angle))
                local try_z = center.z + math.floor(dist * math.sin(angle))

                -- Find ground level (fast version that returns nil if not loaded)
                local ground_y = find_ground_level_fast(try_x, try_z)

                if ground_y then
                    local try_pos = {x = try_x, y = ground_y + 1, z = try_z}

                    -- Check validity
                    local valid, reason = is_valid_scatter_position(try_pos)
                    if valid and check_spacing(try_pos, placed_positions) then
                        local score = calculate_concealment_score(try_pos)

                        if score > best_score then
                            best_score = score
                            best_pos = try_pos
                        end

                        -- If score meets threshold, use it immediately
                        if score >= SCATTER_CONCEALMENT_THRESHOLD then
                            break
                        end
                    end
                end
            end

            -- Place chest at best position found
            if best_pos then
                local success, result = place_scatter_chest(best_pos, mode, name)
                if success then
                    table.insert(placed_positions, best_pos)
                    placed_count = placed_count + 1

                    if best_score < SCATTER_CONCEALMENT_THRESHOLD then
                        exposed_count = exposed_count + 1
                    end
                else
                    failed_count = failed_count + 1
                end
            else
                failed_count = failed_count + 1
            end

            -- Process next chest after a short delay
            minetest.after(0.05, process_next_chest)
        end

        -- Start processing
        minetest.after(0.1, process_next_chest)

        return true, "Scatter started..."
    end,
})

-- Clean up placement mode when player leaves
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    placement_mode[name] = nil
end)

-- Print loaded message
minetest.log("action", "[quest_helper] Quest Helper mod loaded! Commands: /starterkit, /herokit, /questkit, /treasure, /puzzlechest, /savespot, /gospot, /bringall, /announce, /countdown, /placetext, /bigtext, /placemarker, /trail, /pole, /beacon, /vanish, /leaderboard, /myscore, /hud, /resetscores, /chestmode, /reloadquestions, /questionstats, /resetquestions, /scatter")
