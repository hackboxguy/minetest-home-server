-- Quest Helper Mod
-- Admin commands for creating treasure hunts and quests

local storage = minetest.get_mod_storage()

-- Helper function to check if player has admin privs
local function is_admin(name)
    return minetest.check_player_privs(name, {server = true})
end

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
        bread = "mcl_food:bread",
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

-- Print loaded message
minetest.log("action", "[quest_helper] Quest Helper mod loaded! Commands: /starterkit, /herokit, /questkit, /treasure, /savespot, /gospot, /bringall, /announce, /countdown, /placetext, /bigtext, /placemarker, /trail, /pole, /beacon")
