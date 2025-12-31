-- Quest Helper Mod
-- Admin commands for creating treasure hunts and quests

local storage = minetest.get_mod_storage()

-- Helper function to check if player has admin privs
local function is_admin(name)
    return minetest.check_player_privs(name, {server = true})
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

-- /treasure - Place a treasure chest at your position with random loot
minetest.register_chatcommand("treasure", {
    params = "[small|medium|big|epic]",
    description = "Place a treasure chest with loot at your position",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local pos = player:get_pos()
        pos.y = pos.y + 0.5
        pos = vector.round(pos)

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

-- Print loaded message
minetest.log("action", "[quest_helper] Quest Helper mod loaded! Commands: /starterkit, /herokit, /questkit, /treasure, /savespot, /gospot, /bringall, /announce, /countdown")
