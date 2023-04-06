require "tprint"
require "var"
require "serialize"
require "gmcphelper"
require "wait"
require "wrapped_captures"
require "string"
dofile(GetPluginInfo(GetPluginID(), 20) .. "adb_id.lua")

local adb_state = {
    adb_off_for_current_zone = false,
    auto_adb_off_for_zones = {},
    ignore_db_updates_for_items = {},
    ignore_aucto_actions_for_items = {}
}

local adb_external_loot_filters = {}

local adb_options = {}

local adb_options_description = {
    format = {
        level = "Show item level",
        wearable = "Show wearable location",
        weapon_material = "Show material for Weapons",
        score = "Show score field",
        stats_total = "Show total number of item Stats bonuses",
        stats = "Show individual item Stats such as int, wis etc.",
        vitals = "Show vitals such as hp, mana, moves.",
        resists = "Show item bonuses to resists",
        weight = "Show item weight",
        worth = "Show item worth value",
        enchants_sir = "Show [SRI] based on item enchants",
        flags = "Show item flags field",
        foundat = "Show item foundat field",
        enchants_total = "Show summary of item enchants",
        enchants_details = "Show detailed enchants information",
        location = "Show item location from DB",
        bloot_diffs = "Show difference between base and bloot items",
        sections_name_newline = "Add newlines after report sections",
        dbid = "Show item DB rowid value",
        id = "Show item in-game id",
        skill_mods = "Show item Skill Mods",
        comments = "Show item comments field",
        keywords = "Show item keywords",
        type = "Show item type",
        spells = "Show item spells.",
        disechant_hyperlinks = "Show hyperlinks to disenchant removable enchants on item"
    }
}

function adbGetDefaultOptions()
    local default_options = {
        version = "1.005",
        auto_actions = {
            on_bloot_looted_cmd = "gtell just looted;aid %item gtell;aid %item",
            on_bloot_looted_lua = "if %bloot>5 then SendNoEcho(\"say Looted good bloot %bloot %colorName\") end",
            on_normal_looted_cmd = "echo could have done \"put %item bag\" here",
            on_normal_looted_lua = "if %gpp<200 and (\"%type\"==\"Armor\" or \"%type\"==\"Weapon\" or \"%type\"==\"Trash\" or \"%type\"==\"Treasure\") then " ..
                "Send(\"echo drop %item\") elseif \"%type\"~=\"Key\" then Send(\"put %item 2785187925\") end"
        },
        cockpit = {
            update_db_on_loot = true,
            show_db_updates = true,
            show_db_cache_hits = true,
            show_bloot_level = true,
            enable_auto_actions = false,
            identify_command = "id",
            identify_format = "format.full",
            identify_channel_format = "format.brief",
            aide_format = "format.enchanter",
            cache_added_format = "format.full",
            db_find_format = "format.db",
            max_cache_size = 500,
            ignore_db_updates_for_items = [[^\(Aarchaeology\)
^AardWords \(TM\)
^\|(2|3|4|5|6|7|8|9|10|M|D|E|A)\[(Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|Mephit|Demon|Elemental|Ace) of (Fire|Water|Air|Earth)\]\1\|
]],
            ignore_aucto_actions_for_items = [[^\(Aarchaeology\)
^AardWords \(TM\)
^\|(2|3|4|5|6|7|8|9|10|M|D|E|A)\[(Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|Mephit|Demon|Elemental|Ace) of (Fire|Water|Air|Earth)\]\1\|
scarred:a miner's pick
scarred:head of a dragonsnake
knossos:a jeweled bracelet
deathtrap:::\[=== Sword of War ===-
dsr:a leather helmet
dsr:a steel shield
drageran:leg of venison
drageran:a wicked looking riding crop
temple:the Chakram of Light
temple:the Chakram of Darkness
temple:a socketed bracer
temple:a socketed earring
temple:a blood-red ruby
temple:a sparkling diamond
temple:a topaz of worth
temple:a magical bonding agent
]],
            auto_adb_off_for_zones = [[icefall
oradrin
winds
inferno
transcend
geniewish
terra
titan
]]
        },
        colors = {
            default = "@D",
            value = "@W",
            score = "@Y",
            good = "@G",
            bad = "@R",
            flags = "@C",
            weapon = "@M",
            level = "@C",
            section = "@M",
            enchants = "@C"
        },
        ["format.full"] = {
            level = true,
            wearable = true,
            weapon_material = true,
            score = true,
            stats_total = true,
            stats = true,
            vitals = true,
            resists = true,
            weight = true,
            worth = true,
            enchants_sir = true,
            flags = true,
            foundat = true,
            enchants_total = true,
            enchants_details = true,
            location = true,
            bloot_diffs = true,
            sections_name_newline = true,
            dbid = true,
            id = true,
            skill_mods = true,
            comments = true,
            keywords = true,
            type = true,
            spells = true,
            disechant_hyperlinks = true
        },
        ["format.brief"] = {
            level = true,
            wearable = true,
            weapon_material = true,
            score = true,
            stats_total = true,
            stats = true,
            vitals = false,
            resists = true,
            weight = false,
            worth = false,
            enchants_sir = true,
            flags = false,
            foundat = false,
            enchants_total = false,
            enchants_details = false,
            location = false,
            bloot_diffs = false,
            sections_name_newline = false,
            dbid = false,
            id = false,
            skill_mods = true,
            comments = false,
            keywords = false,
            type = false,
            spells = true,
            disechant_hyperlinks = false
        },
        ["format.db"] = {
            level = true,
            wearable = true,
            weapon_material = true,
            score = true,
            stats_total = true,
            stats = true,
            vitals = false,
            resists = true,
            weight = false,
            worth = false,
            enchants_sir = true,
            flags = false,
            foundat = false,
            enchants_total = false,
            enchants_details = false,
            location = false,
            bloot_diffs = false,
            sections_name_newline = false,
            dbid = true,
            id = false,
            skill_mods = true,
            comments = false,
            keywords = false,
            type = false,
            spells = true,
            disechant_hyperlinks = false
        },
        ["format.enchanter"] = {
            level = true,
            wearable = true,
            weapon_material = false,
            score = false,
            stats_total = true,
            stats = true,
            vitals = false,
            resists = false,
            weight = false,
            worth = false,
            enchants_sir = true,
            flags = false,
            foundat = false,
            enchants_total = false,
            enchants_details = true,
            location = false,
            bloot_diffs = false,
            sections_name_newline = false,
            dbid = true,
            id = true,
            skill_mods = false,
            comments = false,
            keywords = false,
            type = false,
            spells = false,
            disechant_hyperlinks = true
        }
    }
    return default_options
end

function adbCheckOptions()
    if adb_options.version == 1 then
        adb_options.version = 1.001
        adb_options["format.full"].sections_name_newline = true
        adb_options["format.brief"].sections_name_newline = false
    end

    if adb_options.version == 1.001 then
        adb_options.version = "1.002"
        adb_options.cockpit.max_cache_size = adbGetDefaultOptions().cockpit.max_cache_size
    end

    if adb_options.version == "1.002" then
        adb_options.version = "1.003"
        adb_options["format.db"] = copytable.deep(adbGetDefaultOptions()["format.db"])
        adb_options.cockpit.db_find_format = adbGetDefaultOptions().cockpit.db_find_format
        local added = {"dbid", "id", "skill_mods", "comments", "keywords"}
        for k, v in pairs(adb_options) do
            if k:find("^format%.") then
                local copy_from = adbGetDefaultOptions()[k] and adbGetDefaultOptions()[k] or
                                      adbGetDefaultOptions()["format.full"]
                for _, v1 in ipairs(added) do
                    adb_options[k][v1] = copy_from[v1]
                end
            end
        end
    end

    if adb_options.version == "1.003" then
        adb_options.version = "1.004"
        local added = {"type", "spells", "disechant_hyperlinks"}
        for k, v in pairs(adb_options) do
            if k:find("^format%.") then
                local copy_from = adbGetDefaultOptions()[k] and adbGetDefaultOptions()[k] or
                                      adbGetDefaultOptions()["format.full"]
                for _, v1 in ipairs(added) do
                    adb_options[k][v1] = copy_from[v1]
                end
            end
        end
        adb_options["format.enchanter"] = copytable.deep(adbGetDefaultOptions()["format.enchanter"])
        adb_options.cockpit.aide_format = "format.enchanter"
    end

    if adb_options.version == "1.004" then
        adb_options.version = "1.005"
        adb_options.cockpit.ignore_db_updates_for_items = adbGetDefaultOptions().cockpit.ignore_db_updates_for_items
        adb_options.cockpit.ignore_aucto_actions_for_items =
            adbGetDefaultOptions().cockpit.ignore_aucto_actions_for_items
        adb_options.cockpit.auto_adb_off_for_zones = adbGetDefaultOptions().cockpit.auto_adb_off_for_zones
    end

    if adb_options.version ~= adbGetDefaultOptions().version then
        adbInfo("ADB options stored are too old, resetting to defaults!")
        adb_options = copytable.deep(adbGetDefaultOptions())
    end

    if adb_options.cockpit.max_cache_size <= 0 then
        adb_options.cockpit.max_cache_size = adbGetDefaultOptions().cockpit.max_cache_size
    end

    adb_state.auto_adb_off_for_zones = {}
    for line in adb_options.cockpit.auto_adb_off_for_zones:gmatch("[^\r\n]+") do
        adb_state.auto_adb_off_for_zones[line] = true
    end

    adb_state.ignore_aucto_actions_for_items = {}
    adbZonePatternStringLinesToTable(adb_options.cockpit.ignore_aucto_actions_for_items,
        adb_state.ignore_aucto_actions_for_items)

    adb_state.ignore_db_updates_for_items = {}
    adbZonePatternStringLinesToTable(adb_options.cockpit.ignore_db_updates_for_items,
        adb_state.ignore_db_updates_for_items)

    EnableTrigger("adbBlootNameTrigger", adb_options.cockpit.show_bloot_level)
    EnableTriggerGroup("adbLootTriggerGroup",
        adb_options.cockpit.update_db_on_loot or adb_options.cockpit.enable_auto_actions)
end

function adbZonePatternStringLinesToTable(str, tbl)
    for line in str:gmatch("[^\r\n]+") do
        local zone, pattern
        _, _, zone, pattern = line:find("^(%a+):(.*)$")
        if zone == nil then
            zone = "all"
            pattern = line
        end

        if tbl[zone] == nil then
            tbl[zone] = {}
        end

        local ok, re
        ok, re = pcall(rex.new, pattern)
        if ok then
            adbDebug("Added " .. zone .. ":" .. pattern .. " " .. tostring(re), 2)
            table.insert(tbl[zone], re)
        else
            adbInfo("Failed to compile regex {" .. pattern .. "} for zone [" .. zone .. "] with error: " .. re)
        end
    end
end

function adbOnOptionsResetCommand()
    adb_options = copytable.deep(adbGetDefaultOptions())
    adbInfo("ADB options reset to defaults!")
    adbCheckOptions()
    adbSaveOptions()
end

function adbLoadOptions()
    adb_options = loadstring(string.format("return %s", var.config or serialize.save_simple(adbGetDefaultOptions())))()
    adbCheckOptions()
    adbSaveOptions()
end

function adbSaveOptions()
    var.config = serialize.save_simple(adb_options)
end

function adbOnOptionsEditCommand(name, line, wildcards)
    local keys = {}
    for k, v in pairs(adb_options) do
        -- Skip version
        if (type(v) == "table") then
            keys[k] = k
        end
    end
    local key1 = utils.choose("Select option group to edit", "ADB", keys, "cockpit")
    if key1 == nil then
        return
    end
    key1 = keys[key1]
    assert(adb_options[key1])

    if key1:find("^format%.") then
        Execute("adb format edit " .. key1)
        return
    end

    keys = {}
    for k, _ in pairs(adb_options[key1]) do
        table.insert(keys, k)
    end
    local key2 = utils.choose("Select option to edit", "ADB", keys, 1)
    if key2 == nil then
        return
    end
    key2 = keys[key2]

    assert(adb_options[key1][key2] ~= nil)
    if type(adb_options[key1][key2]) == "string" then
        if key1 == "cockpit" and
            (key2 == "identify_format" or key2 == "identify_channel_format" or key2 == "cache_added_format" or key2 ==
                "aide_format") then
            local format = adbPickFormat("Choose " .. key2, adb_options[key1][key2])
            if format == nil then
                return
            end
            adb_options[key1][key2] = format
        elseif key1 == "auto_actions" then
            local cmd = utils.editbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2])
            if cmd == nil then
                return
            end
            adb_options[key1][key2] = cmd
        elseif key1 == "cockpit" and
            (key2 == "ignore_db_updates_for_items" or key2 == "ignore_aucto_actions_for_items" or key2 ==
                "auto_adb_off_for_zones") then
            local list =
                utils.editbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2]:gsub("\n", "\r\n"))
            if list == nil then
                return
            end
            list = list:gsub("\r\n", "\n")
            adb_options[key1][key2] = list
        else
            local value = utils.inputbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2])
            if value == nil then
                return
            end
            adb_options[key1][key2] = value
        end
    elseif type(adb_options[key1][key2]) == "boolean" then
        local value = utils.msgbox(key1 .. "." .. key2, "ADB", "yesnocancel", "?", adb_options[key1][key2] and 1 or 2)
        if value == "cancel" then
            return
        end
        adb_options[key1][key2] = value == "yes"
    elseif type(adb_options[key1][key2]) == "number" then
        local value = utils.inputbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2])
        if value == nil then
            return
        end
        if not tonumber(value) then
            adbInfo("Value " .. value .. " is not a number")
            return
        else
            adb_options[key1][key2] = tonumber(value)
        end
    else
        adbErr("adbOnOptionsEditCommand: Not implemented type " .. type(adb_options[key1][key2]))
        return
    end

    adbCheckOptions()
    adbSaveOptions()
end

function adbOnOptionsCommand(name, line, wildcards)
    adbInfo("Options:")
    if wildcards.key1 == "" then
        tprint(adb_options)
        return
    end

    if adb_options[wildcards.key1] == nil then
        adbInfo("Warn: unknown option group " .. wildcards.key1)
        return
    end
    if adb_options[wildcards.key1][wildcards.key2] == nil then
        Note("Warn: unknown option " .. wildcards.key2)
        return
    end

    local type = type(adb_options[wildcards.key1][wildcards.key2])

    local value = nil
    if type == "boolean" then
        value = wildcards.value == "true" and true or nil
        if wildcards.value == "false" then
            value = false
        end
    elseif type == "number" then
        value = tonumber(wildcards.value)
    elseif type == "string" then
        value = wildcards.value
    else
        adbInfo("Warn: unexpected value type " .. type)
    end

    if value ~= nil then
        adb_options[wildcards.key1][wildcards.key2] = value
        adbCheckOptions()
        adbSaveOptions()
        adbInfo("Set " .. wildcards.key1 .. " " .. wildcards.key2 .. " to " ..
                    tostring(adb_options[wildcards.key1][wildcards.key2]))
    else
        adbInfo(wildcards.value .. " is not a valid " .. type)
    end
end

function adbPickFormat(msg, default)
    if default == nil then
        default = "format.full"
    end

    local formats = {}
    for k, _ in pairs(adb_options) do
        if k:find("^format%.") then
            formats[k] = k
        end
    end
    local ikey = utils.choose(msg, "ADB", formats, default)
    return ikey ~= nil and formats[ikey] or ikey
end

function adbOnFormatAdd(name, line, wildcards)
    local format = wildcards.format

    if adb_options[wildcards.newname] ~= nil then
        adbInfo("Format " .. wildcards.newname .. " already exists.")
        return
    end

    if adb_options[format] == nil then
        if format ~= "" then
            adbInfo("Format " .. format .. " not found.")
            return
        else
            format = adbPickFormat("Choose format to copy setting from")
            if format == nil then
                return
            end
            assert(adb_options[format])
        end
    end

    adb_options[wildcards.newname] = copytable.deep(adb_options[format])
    adbCheckOptions()
    adbSaveOptions()
    adbInfo("Added format " .. wildcards.newname)
end

function adbOnFormatRemove(name, line, wildcards)
    local format = wildcards.format

    if adb_options[format] == nil then
        if format ~= "" then
            adbInfo("Format " .. format .. " not found.")
            return
        else
            format = adbPickFormat("Choose format to remove")
            if format == nil then
                return
            end
            assert(adb_options[format])
        end
    end

    if adbGetDefaultOptions()[format] ~= nil then
        adbInfo("Can't remove default format " .. format)
        return
    end

    adb_options[format] = nil
    adbCheckOptions()
    adbSaveOptions()
    adbInfo("Removed format " .. format)
end

function adbOnFormatEdit(name, line, wildcards)
    local format = wildcards.format

    if adb_options[format] == nil then
        if format ~= "" then
            adbInfo("Format " .. format .. " not found.")
            return
        else
            format = adbPickFormat("Choose format to edit")
            if format == nil then
                return
            end
            assert(adb_options[format])
        end
    end

    local choices = {}
    local defaults = {}
    for k, v in pairs(adb_options[format]) do
        choices[k] = adb_options_description.format[k]
        defaults[k] = v
    end
    local selection = utils.multilistbox("Select " .. format .. " options (use ctrl to select multiple items)", "ADB",
        choices, defaults)
    if selection == nil then
        return
    end

    for k, _ in pairs(adb_options[format]) do
        adb_options[format][k] = selection[k] ~= nil and selection[k] or false
    end
    adbCheckOptions()
    adbSaveOptions()
end

------ recent cache ------
local adb_latest_cache_version = "1.03"
local adb_recent_cache = {
    meta = {
        version = adb_latest_cache_version,
        count = 0
    }
}

function adbOnAdbDebugCacheClear()
    adbCacheShrink(true)
end

function adbCacheShrink(force_full_clear)
    adbDebug("adbCacheShrink", 2)
    if not force_full_clear and (adb_recent_cache.meta.count <= adb_options.cockpit.max_cache_size) then
        return
    end

    local keys = {}
    table.foreach(adb_recent_cache, function(k, v)
        if k ~= "meta" then
            assert(k ~= nil)
            table.insert(keys, k)
        end
    end)

    assert(adb_recent_cache.meta.count == #keys)

    table.sort(keys, function(key1, key2)
        return adb_recent_cache[key1].cache.timestamp > adb_recent_cache[key2].cache.timestamp
    end)

    for i = #keys, force_full_clear and 1 or (adb_options.cockpit.max_cache_size + 1), -1 do
        local item = adb_recent_cache[keys[i]]
        if item.cache.new then
            adbDbAddItem(item)
        elseif item.cache.dirty then
            adbDbUpdateItem(item)
        end
        adbDebug(
            "Evicted from cache [" .. item.cache.rowid .. "] [" .. item.colorName .. "] [" .. item.location.zone .. "]",
            2)
        adb_recent_cache[keys[i]] = nil
        adb_recent_cache.meta.count = adb_recent_cache.meta.count - 1
    end
end

function adbCacheSave()
    adbCacheShrink()
    var.recent_cache = serialize.save_simple(adb_recent_cache)
end

function adbCacheLoad()
    if var.recent_cache == nil then
        return
    end

    adb_recent_cache = loadstring("return " .. var.recent_cache)()

    if adb_recent_cache.meta == nil then
        adbInfo("Updating cache to version 1.01")
        assert(adb_recent_cache.version == 1.0)
        adb_recent_cache.version = nil
        adb_recent_cache.meta = {
            version = 1.01,
            count = 0
        }
        local count = 0
        for k, v in pairs(adb_recent_cache) do
            if k ~= "meta" then
                count = count + 1
                v.cache = {
                    new = true,
                    dirty = false,
                    timestamp = os.time()
                }
            end
        end
        adb_recent_cache.meta.count = count
        adbInfo("Finished")
    end

    if adb_recent_cache.meta.version == 1.01 then
        adbInfo("Updating cache to version 1.02")
        adb_recent_cache.meta.version = "1.02"
    end

    if adb_recent_cache.meta.version == "1.02" then
        adbInfo("Updating cache to version 1.03")
        for k, v in pairs(adb_recent_cache) do
            if k ~= "meta" then
                v.skillMods = {}
                v.identifyVersion = 1
            end
        end
        adb_recent_cache.meta.version = "1.03"
    end

    if adb_recent_cache.meta.version ~= adb_latest_cache_version then
        adbInfo("Cache version " .. adb_recent_cache.version .. " is too old, clearing cache")
        adb_recent_cache = {
            meta = {
                version = adb_latest_cache_version,
                count = 0
            }
        }
    end

    adbDebug("Cache version " .. adb_recent_cache.meta.version .. " contains " .. adb_recent_cache.meta.count ..
                 " item(s).", 1)
end

function adbCacheGetKey(name, zone)
    return zone .. "->" .. name
end

function adbCacheGetItem(color_name, zone)
    adbDebug("adbCacheGetItem [" .. color_name .. "] [" .. zone .. "]", 3)
    local result = adb_recent_cache[adbCacheGetKey(color_name, zone)]

    if result == nil then
        result = adbDbGetItem(color_name, zone)
        if result then
            adbCacheAdd(result, true)
        end
    end

    if result ~= nil then
        result.cache.timestamp = os.time()
    else
        adbDebug("not found in cache: [" .. color_name .. "] [" .. zone .. "]", 1)
    end

    return result
end

function adbCacheGetItemByNameAndFoundAt(color_name, found_at)
    local result = nil
    for k, v in pairs(adb_recent_cache) do
        if k == "meta" then
            -- skip meta field
        elseif v.colorName == color_name and v.stats.foundat == found_at then
            result = v
            break
        end
    end

    if result == nil then
        result = adbDbGetItemByNameAndFoundAt(color_name, found_at)
        if result then
            adbCacheAdd(result, true)
        end
    end

    if result ~= nil then
        result.cache.timestamp = os.time()
    end
    return result
end

function adbCacheGetItemsByName(color_name)
    local result = {}

    -- there might be multiple items with same name in DB
    local db_result = adbDbGetItemsByName(color_name)
    for k, v in pairs(db_result) do
        adbCacheAdd(v)
    end

    for k, v in pairs(adb_recent_cache) do
        if k == "meta" then
            -- skip meta field
        elseif v.colorName == color_name then
            table.insert(result, v)
            break
        end
    end

    return result
end

function adbCacheItemUpdateIdentify(cache_item, item)
    assert(cache_item.colorName == item.colorName)
    cache_item.cache.dirty = true

    local ignore_keys = {
        cache = true,
        location = true
    }
    for k, _ in pairs(item) do
        if not ignore_keys[k] then
            cache_item[k] = item[k]
        end
    end

    if adb_options.cockpit.show_db_updates then
        AnsiNote(ColoursToANSI("@CADB updated identify version:\n" ..
                                   adbIdReportGetItemString(cache_item,
                adb_options[adb_options.cockpit.cache_added_format])))
    end
end

function adbCacheItemAddMobs(cache_item, mobs)
    local old_location = adbIdReportAddLocationInfo("", cache_item.location)
    for k, v in pairs(mobs) do
        adbItemLocationAddMob(cache_item, v)
    end
    local new_location = adbIdReportAddLocationInfo("", cache_item.location)

    if old_location ~= new_location then
        cache_item.cache.dirty = true
        if adb_options.cockpit.show_db_updates then
            AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo(
                "@CADB updated cache item @w[" .. cache_item.colorName .. "@w] @C:", cache_item.location)))
        end
    elseif adb_options.cockpit.show_db_cache_hits then
        AnsiNote(ColoursToANSI("@CADB item already in cache: @w[" .. cache_item.colorName .. "@w]"))
    end
end

function adbCacheAdd(item, skip_cache_search)
    if (item.stats.foundat == nil) then
        AnsiNote(ColoursToANSI("@CADB no identify wish, skipping " .. item.colorName))
        return
    end

    local key = adbCacheGetKey(item.colorName, item.location.zone)
    local cache_item = nil
    if not skip_cache_search then
        cache_item = adbCacheGetItem(item.colorName, item.location.zone)
    else
        assert(adb_recent_cache[key] == nil)
    end
    if cache_item == nil then
        if item.cache == nil then
            item.cache = {
                new = true,
                dirty = false,
                timestamp = os.time()
            }
        end
        if not adb_recent_cache[key] then
            adb_recent_cache.meta.count = adb_recent_cache.meta.count + 1
        else
            adbErr("adbCacheGetItem failed but there's an item with key [" .. key .. "] in cache...")
            item.cache.new = adb_recent_cache[key].cache.new
            item.cache.dirty = true
        end
        adb_recent_cache[key] = item
        adbDebug("Added to cache:", 3)
        adbDebugTprint(item, 3)
        if adb_options.cockpit.show_db_updates then
            if not skip_cache_search then
                AnsiNote(ColoursToANSI("@CADB added to cache:\n" ..
                                           adbIdReportGetItemString(item,
                        adb_options[adb_options.cockpit.cache_added_format])))
            else
                adbDebug(function()
                    AnsiNote(ColoursToANSI("@CADB loaded to cache from db:\n" ..
                                               adbIdReportGetItemString(item, adb_options[adb_options.cockpit
                            .cache_added_format])))
                end, 1)
            end
        end
        adbCacheShrink()
    else
        adbDebug(item.colorName .. " already in cache, updated timestamp", 3)
        cache_item.cache.timestamp = os.time()
    end
end
------ invitem and looted items stacks ------
local adb_invitem_stack = {}
local adb_looted_stack = {}

function adbMakeLuaString(s)
    return s:gsub("[\"\\]", "\\%1")
end

function adbReplacePatterns(cmd, id, bloot, name, colorName, base_item, lua)
    adbDebug("adbReplacePatterns:" .. cmd, 4)
    for k, v in pairs(base_item.stats) do
        -- we might be getting stats from chached item, so don't use it's id
        if k ~= "id" and k ~= "name" then
            local value = v
            if lua and type(value) == "string" then
                value = adbMakeLuaString(value)
            end
            cmd = cmd:gsub("%%%f[%a]" .. k .. "%f[%A]", value)
        end
    end
    cmd = cmd:gsub("%%%f[%a]" .. "item" .. "%f[%A]", id)
    cmd = cmd:gsub("%%%f[%a]" .. "bloot" .. "%f[%A]", bloot)
    cmd = cmd:gsub("%%%f[%a]" .. "name" .. "%f[%A]", lua and adbMakeLuaString(name) or name)
    local cname = adb_options.cockpit.show_bloot_level and adbAddBlootLevel(colorName) or colorName
    cmd = cmd:gsub("%%%f[%a]" .. "colorName" .. "%f[%A]", lua and adbMakeLuaString(cname) or cname)
    cmd = cmd:gsub("%%%f[%a]" .. "zone" .. "%f[%A]",
        lua and adbMakeLuaString(base_item.location.zone) or base_item.location.zone)

    local gpp = base_item.stats.weight == 0 and 99999999 or (base_item.stats.worth / base_item.stats.weight)
    cmd = cmd:gsub("%%%f[%a]" .. "gpp" .. "%f[%A]", gpp)

    adbDebug("replaced cmd:" .. cmd, 4)
    return cmd
end

-- Called for all looted items when processing is finished.
-- <item> is either fresh identify results or a cached version,
-- so id and item.stats.id could be different!
function adbOnItemLooted(id, item)
    adbDebug("adbOnItemLooted " .. id .. " " .. item.stats.name, 2)
    -- TODO check options here etc
    if item == nil or item.stats == nil then
        adbDebug("got nil item in adbOnItemLooted", 2)
        return
    end

    local bloot = adbGetBlootLevel(item.stats.name)
    if bloot > 0 then
        adbDebug("Not touching bloot " .. tostring(bloot) .. " item.", 1)
        return
    end

    for _, v in pairs(adb_external_loot_filters) do
        local ok, result
        ok, result = pcall(v.func, id, bloot, item)
        if ok then
            if result then
                CallPlugin(v.plugin, v.callback, id, bloot, serialize.save_simple(item))
                return
            end
        else
            adbInfo("External plugin " .. v.plugin .. " loot filter failed with: " .. result)
        end
    end

    if not adb_options.cockpit.enable_auto_actions or adb_state.adb_off_for_current_zone or
        adbIsItemIgnored(item.stats.name, item.location.zone, adb_state.ignore_aucto_actions_for_items) then
        return
    end

    local cmd
    cmd = adb_options.auto_actions.on_normal_looted_lua
    if cmd ~= "" then
        cmd = adbReplacePatterns(cmd, id, bloot, item.stats.name, item.colorName, item, true)
        local lua, err, ok
        lua, err = loadstring(cmd)
        if lua ~= nil then
            adbDebug("Executing lua " .. cmd, 3)
            ok, err = pcall(lua)
            if not ok then
                adbInfo("Failed executing on_normal_looted_lua: " .. err)
            end
        else
            adbInfo("Failed to compile lua " .. cmd .. "\n with error: " .. err)
        end
    end
    cmd = adb_options.auto_actions.on_normal_looted_cmd
    if cmd ~= "" then
        cmd = adbReplacePatterns(cmd, id, bloot, item.stats.name, item.colorName, item)
        adbDebug("Executing cmd " .. cmd, 3)
        Execute(cmd)
    end
end

function adbIsItemIgnored(name, zone, tbl)
    adbDebug("adbIsItemIgnored [" .. name .. "] [" .. zone .. "]", 2)

    if tbl[zone] ~= nil then
        for _, v in ipairs(tbl[zone]) do
            if v:match(name) then
                adbDebug("Skipping ignored item " .. name .. " [" .. zone .. "]", 2)
                return true
            end
        end
    end

    if tbl["all"] ~= nil then
        for _, v in ipairs(tbl["all"]) do
            if v:match(name) then
                adbDebug("Skipping ignored item " .. name, 2)
                return true
            end
        end
    end

    adbDebug("not ignored", 2)
    return false
end

function adbOnBlootItemLooted(id, drain_loot_item)
    adbDebug("adbOnBlootItemLooted " .. id .. " " .. drain_loot_item.name, 2)

    if not adb_options.cockpit.enable_auto_actions or adb_state.adb_off_for_current_zone or
        adbIsItemIgnored(drain_loot_item.name, drain_loot_item.zone, adb_state.ignore_aucto_actions_for_items) or
        (adb_options.auto_actions.on_bloot_looted_cmd == "" and adb_options.auto_actions.on_bloot_looted_lua == "") then
        return
    end

    local bloot = adbGetBlootLevel(drain_loot_item.name)
    local base_name = adbGetBaseColorName(drain_loot_item.colorName)
    local base_item = adbCacheGetItem(base_name, drain_loot_item.zone)
    -- TODO add option to actually identify bloot items too?
    if base_item == nil then
        adbDebug("base item not found, ignoring bloot scripts", 1)
        return
    end
    local cmd
    cmd = adb_options.auto_actions.on_bloot_looted_lua
    if cmd ~= "" then
        cmd = adbReplacePatterns(cmd, id, bloot, drain_loot_item.name, drain_loot_item.colorName, base_item, true)
        local lua, err, ok
        lua, err = loadstring(cmd)
        if lua ~= nil then
            adbDebug("Executing lua " .. cmd, 3)
            ok, err = pcall(lua)
            if not ok then
                adbInfo("Failed executing on_bloot_looted_lua: " .. err)
            end
        else
            adbInfo("Failed to compile lua " .. cmd .. "\n with error: " .. err)
        end
    end
    cmd = adb_options.auto_actions.on_bloot_looted_cmd
    if cmd ~= "" then
        cmd = adbReplacePatterns(cmd, id, bloot, drain_loot_item.name, drain_loot_item.colorName, base_item)
        adbDebug("Executing cmd " .. cmd, 3)
        Execute(cmd)
    end
end

local adb_draining = false
function adbDrainStacks()
    -- this is very ugly and unsafe, let's see if this will work or not
    if adb_draining then
        adbDebug("Already draining stacks, ignored another call", 1)
        return
    end

    adb_draining = true
    adbDrainOne()
end

function adbDrainOne()
    if #adb_invitem_stack == 0 and #adb_looted_stack > 0 then
        adbErr("adbDrainOne -> invitem stack is empty while looted stack is not!?")
        adbOnAdbDebugDump()
        return
    elseif #adb_looted_stack == 0 then
        adb_draining = false
        return
    end

    local adb_drain_inv_item = table.remove(adb_invitem_stack, 1)
    local adb_drain_loot_item = table.remove(adb_looted_stack, 1)

    if adb_drain_inv_item.name ~= adb_drain_loot_item.name then
        adbErr("adbDrainOne -> inv.name " .. adb_drain_inv_item.name .. " != " .. adb_drain_loot_item.name)
        adb_draining = false
        return
    end

    if adbGetBlootLevel(adb_drain_loot_item.name) > 0 then
        adbOnBlootItemLooted(adb_drain_inv_item.id, adb_drain_loot_item)
        adbDrainOne()
        return
    end

    local cache_item = adbCacheGetItem(adb_drain_loot_item.colorName, adb_drain_loot_item.zone)
    if cache_item ~= nil then
        adbDebug(adb_drain_loot_item.colorName .. " found in cache", 4)
        if adb_options.cockpit.update_db_on_loot and
            not adbIsItemIgnored(adb_drain_loot_item.name, adb_drain_loot_item.zone,
                adb_state.ignore_db_updates_for_items) then
            adbCacheItemAddMobs(cache_item, {adbCreateMobFromLootItem(adb_drain_loot_item)})

            -- we have old item in cache/db, inentify again
            if cache_item.identifyVersion ~= adb_id_version then
                adbDebug("Updating old identify version for " .. adb_drain_loot_item.colorName, 1)
                local ctx = {
                    drain_inv_item = adb_drain_inv_item,
                    drain_loot_item = adb_drain_loot_item,
                    cache_item = cache_item
                }
                adbIdentifyItem("id " .. tostring(adb_drain_inv_item.id), adbDrainIdResultsReadyCB, ctx)
                return
            end
        end

        adbOnItemLooted(adb_drain_inv_item.id, cache_item)
        adbDrainOne()
        return
    end

    if (adb_options.cockpit.update_db_on_loot and
        not adbIsItemIgnored(adb_drain_loot_item.name, adb_drain_loot_item.zone, adb_state.ignore_db_updates_for_items)) or
        (adb_options.cockpit.enable_auto_actions and
            not adbIsItemIgnored(adb_drain_loot_item.name, adb_drain_loot_item.zone,
                adb_state.ignore_aucto_actions_for_items)) then
        local ctx = {
            drain_inv_item = adb_drain_inv_item,
            drain_loot_item = adb_drain_loot_item
        }
        adbIdentifyItem("id " .. tostring(adb_drain_inv_item.id), adbDrainIdResultsReadyCB, ctx)
    else
        adbDrainOne()
    end
end

function adbMergeMobRooms(mob1, mob2)
    local result = mob1.rooms

    for room2 in mob2.rooms:gmatch("%d+") do
        local found = false
        for room1 in mob1.rooms:gmatch("%d+") do
            if room1 == room2 then
                found = true
                break
            end
        end
        if not found then
            result = result .. ", " .. room2
        end
    end

    return result
end

function adbItemLocationAddMob(item, mob)
    -- Only add mob if the mob's zone matches item foundAt
    if item.stats.foundat ~= nil and adbAreaNameXref[item.stats.foundat] ~= mob.zone then
        if mob.zone == "sohtwo" and adbAreaNameXref[item.stats.foundat] == "soh" then
            -- intentionally left blank
            -- soh and sohtwo items have the same FoundAt field, so stick to the mob location for now
        else
            AnsiNote(ColoursToANSI("@CIgnoring @w" .. mob.colorName .. "@w in zone " .. mob.zone .. " for item @w[" ..
                                       item.colorName .. "@w]"))
            return
        end
    end

    local key = mob.zone .. "->" .. mob.colorName
    local existing_mob = item.location.mobs[key]
    local modified = existing_mob == nil

    if existing_mob ~= nil then
        local new_rooms = adbMergeMobRooms(existing_mob, mob)
        modified = new_rooms ~= existing_mob.rooms
        existing_mob.rooms = new_rooms
    else
        item.location.mobs[key] = mob
    end

    if mob.colorName == "@Yshopkeeper" then
        modified = modified or not item.location.shop
        item.location["shop"] = 1
    end

    if modified and item.cache then
        item.cache.dirty = true
    end
end

function adbCreateMobFromLootItem(item)
    return {
        name = item.mob,
        colorName = item.colorMob,
        rooms = item.room,
        zone = item.zone
    }
end

function adbDrainIdResultsReadyCB(item, ctx)
    -- TODO: check if identify failed...

    if ctx.drain_inv_item.id ~= item.stats.id then
        adbInfo("adbDrainIdResultsReadyCB -> something is off! Expected id " .. tostring(ctx.drain_inv_item.id) ..
                    " but got " .. tostring(item.stats.id) .. ". Did you throw away [" .. ctx.drain_loot_item.name ..
                    "] already?")
        adbDrainOne()
        return
    end

    -- TODO: not sure if "same" items could be carried by mobs in different zones
    -- for now going to have location.zone which is set to first mob's zone
    if adb_options.cockpit.update_db_on_loot and
        not adbIsItemIgnored(ctx.drain_loot_item.name, ctx.drain_loot_item.zone, adb_state.ignore_db_updates_for_items) then
        if ctx.cache_item == nil then
            -- It could be that we looted item from another zone which was given to or picked up by mob in different place
            local item_zone = ctx.drain_loot_item.zone
            if item.stats.foundat ~= nil then
                if adbAreaNameXref[item.stats.foundat] ~= nil then
                    if item_zone == "sohtwo" and adbAreaNameXref[item.stats.foundat] == "soh" then
                        -- intentionally left blank
                        -- soh and sohtwo items have the same FoundAt field, so stick to the mob location for now
                    else
                        item_zone = adbAreaNameXref[item.stats.foundat]
                    end
                else
                    adbErr("Don't know short zone name for " .. item.stats.foundat)
                end
                item.location = {
                    zone = item_zone,
                    mobs = {}
                }
                adbItemLocationAddMob(item, adbCreateMobFromLootItem(ctx.drain_loot_item))
                adbCacheAdd(item)
            else
                adbInfo("It seems you don't have the identify wish... You better just disable update_db_on_loot")
            end
        else
            -- if identify had to queue this call, cache_item was copied and no longer
            -- references actual table in recent cache.
            local cache_item = adb_recent_cache[adbCacheGetKey(ctx.cache_item.colorName, ctx.cache_item.location.zone)]
            assert(cache_item)
            adbCacheItemUpdateIdentify(cache_item, item)
        end
    end

    adbOnItemLooted(item.stats.id, item)
    adbDrainOne()
end

function adbLootedStackRemoveLast(name)
    adbDebug("adbLootedStackRemoveLast " .. name, 5)

    if #adb_looted_stack == 0 then
        adbDebug("adbLootedStackRemoveLast unexpected? #adb_looted_stack == 0", 1)
        return
    end

    if adb_looted_stack[#adb_looted_stack].name == name then
        table.remove(adb_looted_stack)
    else
        adbErr("Looted stack last [" .. adb_looted_stack[#adb_looted_stack].name .. "] doesn't match provided name [" ..
                   name .. "]")
    end
end

function adbLootedStackPush(item)
    adbDebug("adbLootedStackPush " .. item.colorName, 5)

    -- It seems that invitem messages trim "," in item name, like this:
    -- a tarnished, silver flute (200)
    -- {invitem}2786399276,,a tarnished silver flute,200,6,0,-1,-1
    -- So strip name and compare against as well
    local nocommas_name = item.name:gsub(",", "")

    -- {invitem} messages comes before the actual loot message,
    -- so there should be an item with same name in invitem stack already.
    if adb_invitem_stack[#adb_looted_stack + 1] ~= nil and
        (adb_invitem_stack[#adb_looted_stack + 1].name == item.name or adb_invitem_stack[#adb_looted_stack + 1].name ==
            nocommas_name) then
        -- Fix invitem name to include commas if there're any
        adb_invitem_stack[#adb_looted_stack + 1].name = item.name
        table.insert(adb_looted_stack, item)
    else
        -- invmon events happen when we receive items from any source and not just looting from corpse
        -- let's try to see if we can find a match down the stack
        -- another alternative would be to write triggers to all those buy/auction/give etc messages, but i'm lazy
        for i = #adb_looted_stack + 2, #adb_invitem_stack, 1 do
            if adb_invitem_stack[i].name == item.name or adb_invitem_stack[i].name == nocommas_name then
                -- Fix invitem name to include commas if there're any
                adb_invitem_stack[i].name = item.name
                -- just remove all entries in invitem stack before the correct one
                for j = #adb_looted_stack + 1, i - 1, 1 do
                    local removed = table.remove(adb_invitem_stack, #adb_looted_stack + 1)
                    adbDebug("Removing invitem from untracked source: " .. removed.name, 5)
                end
                table.insert(adb_looted_stack, item)
                return
            end
        end

        -- Failed, report and clear stacks
        adbErr("------- adbLootedStackPush error -------")
        Note("Make sure you have invmon enabled. Type invmon to check.")
        Note("pushing:")
        tprint(item)
        adbOnAdbDebugDump()
        adbErr("Sync is broken between invitem/looted stacks.")

        adb_invitem_stack = {}
        adb_looted_stack = {}
    end
end

function adbInvitemStackRemoveLast(name)
    if (#adb_looted_stack == 0) then
        adbDebug("adbInvitemStackRemoveLast unexpected? #adb_looted_stack == 0", 1)
        return
    end

    -- {invitem} message comes before the actual loot message, so we can't just assume the last entry is the one
    -- we need to remove.
    -- Also, there could be other {invitem} elements from untracked sources.
    -- What we know for sure is that the item to remove should be somewhere at or after #adb_looted_stack,
    -- and it's the first encountered.
    for i = #adb_looted_stack, #adb_invitem_stack, 1 do
        if adb_invitem_stack[i].name == name then
            table.remove(adb_invitem_stack, i)
            return
        end
    end
    adbErr("Can't find invitem to remove [" .. name .. "]")
end

function adbInvitemStackPush(item)
    adbDebug("adbInvitemStackPush " .. item.id .. " " .. item.name, 5)
    table.insert(adb_invitem_stack, item)
end

------ Aliases/triggers callbacks ------
function adbOnItemLootedTrigger(trigger_name, line, wildcards, styles)
    -- don't care about gold
    if wildcards.gold ~= "" then
        adbDebug("adbOnItemLootedTrigger ignoring gold: " .. wildcards.gold, 5)
        return
    end

    -- don't record looting items from the corpse of yourself :P
    if wildcards.mob == gmcp("char.base.name") then
        adbDebug("adbOnItemLootedTrigger ignoring your own corpse: " .. wildcards.mob, 5)
        return
    end

    local color_name, color_mob
    local colored_line = StylesToColours(styles)
    adbDebug("adbOnItemLootedTrigger colored_line: " .. colored_line, 5)

    -- it seems that sometimes there's leftover color code from previous line
    -- at least I saw "@x248You get @Rminotaur clan @x069markings@w..."
    local name_start
    _, name_start = colored_line:find("^@?[%a%d]*You get @?[%a%d]*%d+@?[%a%d]* %* ")
    if name_start == nil then
        _, name_start = colored_line:find("^@?[%a%d]*You get ")
        if name_start == nil then
            adbErr("Can't parse name start: [" .. colored_line .. "]")
            return
        end
    end

    -- weird... sometimes you get items not from a corpse:
    -- You get (Enhanced 2) *-Victory-* from the torso of Mota.
    -- TODO: compile regex here instead of lua matches?
    local name_end_patterns = {"@w from the ?%a*,? ?%a* corpse of ", "@w from the ?%a*,? ?%a* torso of ",
                               " from the ?%a*,? ?%a* corpse of ", " from the ?%a*,? ?%a* torso of "}

    local name_end = nil
    local mob_start = nil
    local i = 1
    while name_end == nil and i <= #name_end_patterns do
        name_end, mob_start = colored_line:find(name_end_patterns[i])
        i = i + 1
    end
    if name_end == nil then
        adbErr("Can't parse name end and mob start: [" .. colored_line .. "]")
        return
    end
    color_name = colored_line:sub(name_start + 1, name_end - 1)

    assert(mob_start ~= nil)

    local mob_end
    mob_end = colored_line:find("@w%.$") or colored_line:find("%.$")
    if mob_end == nil then
        adbErr("Can't parse mob end: [" .. colored_line .. "]")
        return
    end
    color_mob = colored_line:sub(mob_start + 1, mob_end - 1)

    local t = {
        name = wildcards.item,
        colorName = color_name,
        mob = wildcards.mob,
        colorMob = color_mob,
        zone = gmcp("room.info.zone"),
        room = gmcp("room.info.num")
    }

    for i = 1, wildcards.count ~= "" and tonumber(wildcards.count) or 1, 1 do
        adbLootedStackPush(t)
    end

    -- one shotted mob without getting gmcp in combat state
    if gmcp("char.status.state") == "3" and not was_in_combat then
        -- get a chance for crumble trigger to fire
        AddTimer("DrainOneTimer", 0, 0, 1, "",
            timer_flag.Enabled + timer_flag.OneShot + timer_flag.Replace + timer_flag.Temporary, "adbDrainOne")
    end
end

function adbOnItemLootedCrumblesTrigger(name, line, wildcards)
    adbDebug("adbOnItemLootedCrumblesTrigger " .. line, 5)
    adbInvitemStackRemoveLast(wildcards.item)
    adbLootedStackRemoveLast(wildcards.item)
end

function adbOnInvitemTrigger(name, line, wildcards)
    adbDebug("invitem " .. line, 2)
    local t = {
        id = tonumber(wildcards.id),
        name = wildcards.item
    }
    adbInvitemStackPush(t)
end

function adbOnInvmonTrigger(name, line, wildcards)
    -- if wildcards.action == "4" or wildcards.action == "3" then
    --  Note("invmon "..line)
    -- end
end

function adbOnAdbDebugDump()
    Note("---------------- ADB ----------------")
    Note("invitems stack:")
    tprint(adb_invitem_stack)
    Note("looted stack:")
    tprint(adb_looted_stack)
    Note("recent cache:")
    print(adb_recent_cache.meta.count .. " entries")
    -- tprint(adb_recent_cache)
    adbIdDebugDump()
    Note("-------------------------------------")
end

function adbOnIdentifyCommand(name, line, wildcards)
    if wildcards.format ~= "" and adb_options[wildcards.format] == nil then
        adbInfo("Unknown format " .. wildcards.format .. " using default")
    end
    local identify_format = adb_options[wildcards.format] or
                                (adb_options[wildcards.channel == "" and adb_options.cockpit.identify_format or
                                    adb_options.cockpit.identify_channel_format])
    local ctx = {
        channel = wildcards.channel,
        format = identify_format,
        id = wildcards.id
    }
    adbIdentifyItem("id " .. wildcards.id .. wildcards.worn, adbOnIdentifyCommandIdResultsReadyCB, ctx)
end

function adbOnIdentifyCommandIdResultsReadyCB(obj, ctx)
    adbProcessIdResults(obj, ctx)
end

function adbProcessIdResults(obj, ctx)
    if (obj.stats.name == nil) then
        adbDebug("item not found", 2)
        adbInfo(ctx.id .. " not found.")
        return
    end

    adbDebug(function()
        print("id results:")
        tprint(obj)
        print("bloot: " .. tostring(adbGetBlootLevel(obj.stats.name)))
        print("base name: " .. adbGetBaseColorName(obj.colorName))
    end, 3)

    -- TODO: add to cache?

    local format = ctx.format
    if format.disechant_hyperlinks and ctx.channel == "" then
        format = copytable.deep(ctx.format)
        format.enchants_details = false
    end

    local message = adbIdReportGetItemString(obj, format)

    if format.location or format.bloot_diffs then
        local bloot = adbGetBlootLevel(obj.stats.name)
        local base_name = adbGetBaseColorName(obj.colorName)
        local base_item = obj.stats.foundat ~= nil and adbCacheGetItemByNameAndFoundAt(base_name, obj.stats.foundat) or
                              nil
        if base_item ~= nil then
            if format.bloot_diffs and bloot > 0 then
                local diff = adbDiffItems(base_item, obj, true)
                message = adbIdReportAddDiffString(message, diff, format)
            end
            if format.location then
                message = adbIdReportAddLocationInfo(message, base_item.location)
            end
        end
    end

    if ctx.channel == "" then
        AnsiNote(ColoursToANSI(message))
    else
        for line in message:gmatch("[^\n]+") do
            SendNoEcho(ctx.channel .. " " .. line)
        end
    end

    if format.disechant_hyperlinks and ctx.channel == "" and obj.enchants ~= nil and adbEnchantsPresent(obj.enchants) then

        for k, v in ipairs(adb_enchants.order) do
            if obj.enchants[v] ~= nil then
                local report = adb_options.colors.enchants .. " " .. v
                report = adbIdReportAddValue(report,
                    adbGetStatsGroupString(obj.enchants[v], adb_stat_groups.hrdr, true), "", adb_options.colors.default)
                report = adbIdReportAddValue(report,
                    adbGetStatsGroupString(obj.enchants[v], adb_stat_groups.basics, true), "",
                    adb_options.colors.default)
                if not obj.enchants[v].removable then
                    report = adbIdReportAddValue(report, "TP only", "", adb_options.colors.bad)
                else
                    report = report .. " " .. adb_options.colors.default .. "["
                end
                local styles = ColoursToStyles(report, adb_options.colors.default, ColourNameToRGB("black"), false,
                    false)
                for _, v in ipairs(styles) do
                    ColourTell(RGBColourToName(v.textcolour), RGBColourToName(v.backcolour), v.text)
                end

                if obj.enchants[v].removable then
                    styles = ColoursToStyles(adb_options.colors.good .. "remove " .. v)
                    local action = "disenchant " .. obj.stats.id .. " " .. v .. " confirm"

                    if ctx.bagid ~= nil and ctx.bagid ~= "" then
                        action = "get " .. obj.stats.id .. " " .. ctx.bagid .. "\n" .. action .. "\nput " ..
                                     obj.stats.id .. " " .. ctx.bagid
                    end

                    local color
                    if ctx[v] ~= nil and ctx[v] ~= "" and (adbGetEnchantSum(obj.enchants[v]) <= tonumber(ctx[v])) then
                        color = RGBColourToName(styles[1].textcolour)
                    else
                        color = "gray"
                    end
                    Hyperlink(action, "remove " .. v, "click to:\n" .. action, color, "black", false)
                    styles = ColoursToStyles("]", adb_options.colors.default, ColourNameToRGB("black"), false, false)
                    ColourTell(RGBColourToName(styles[1].textcolour), "black", "]")
                end
            end
        end

        Note("")
    end
end

------ aide command ------

local adb_aide_inv_data_queue = nil
local adb_aide_busy = false
local adb_aide_ctx = nil
function adbOnAIDECommand(name, line, wildcards)
    if adb_aide_busy then
        adbInfo("AIDE is already running, please retry when current operation finishes.")
        return
    end
    adb_aide_busy = true
    adbInfo(line)

    if wildcards.format ~= "" and adb_options[wildcards.format] == nil then
        adbInfo("Unknown format " .. wildcards.format .. " using default")
    end
    local identify_format = adb_options[wildcards.format] and adb_options[wildcards.format] or
                                adb_options[adb_options.cockpit.aide_format]

    adb_aide_ctx = {
        channel = "",
        format = identify_format,
        bagid = wildcards.id,
        Solidify = wildcards.solidify,
        Illuminate = wildcards.illuminate,
        Resonate = wildcards.resonate,
        IR = wildcards.IR,
        removable = wildcards.removable == "removable",
        enchanted = wildcards.enchanted == "enchanted",
        command = wildcards.command,
        compact_ctx = adbCompactMakeCtx(),
    }
    adb_aide_inv_data_queue = {}

    local add_id = (wildcards.id ~= "" and (" " .. wildcards.id) or "")

    if add_id ~= "" then
        -- If that's a non-existing container invdata will report: Item xxxxxxx not found.
        -- Abort busy state in this case.
        AddTriggerEx("AIDEFailedTrigger", "^Item" .. add_id .. " not found.$", "",
            trigger_flag.Replace + trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.OmitFromOutput +
                trigger_flag.OneShot + trigger_flag.Temporary, custom_colour.NoChange, 0, "", "adbInvDataNotFoundCB",
            sendto.scriptafteromit, 0);
    end

    adbCompact(true, adb_aide_ctx.compact_ctx)
    Capture.tagged_output("invdata" .. add_id, "{invdata" .. add_id .. "}", "{/invdata}", false, true, true, true,
        adbInvDataReadyCB, false)
end

function adbInvDataNotFoundCB()
    adbCompact(false, adb_aide_ctx.compact_ctx)
    adbInfo("AIDE container " .. adb_aide_ctx.bagid .. " not found.")
    adb_aide_busy = false
end

function adbInvDataReadyCB(style_lines)
    adbDebug("adbInvDataReadyCB", 2)
    for _, v in ipairs(style_lines) do
        local line = strip_colours(StylesToColours(v))
        local id
        _, _, id = line:find("^(%d+),.*,.*,.*,.*,.*,.*,.*$")
        if id ~= nil then
            table.insert(adb_aide_inv_data_queue, id)
        else
            adbErr("Can't find ID in invdata line " .. line)
        end
    end
    adbInfo("AIDE processing " .. #adb_aide_inv_data_queue .. " items(s).")
    adbInvDataQueueDrain()
end

function adbInvDataQueueDrain()
    if #adb_aide_inv_data_queue == 0 then
        adbCompact(false, adb_aide_ctx.compact_ctx)
        adb_aide_busy = false
        adbInfo("AIDE finished.")
        return
    end

    local item_id = table.remove(adb_aide_inv_data_queue, 1)
    local cmd = "id " .. item_id
    if adb_aide_ctx.bagid ~= "" then
        cmd = "get " .. item_id .. " " .. adb_aide_ctx.bagid .. "\n" .. cmd .. "\nput " .. item_id .. " " ..
                  adb_aide_ctx.bagid
    end
    adbIdentifyItem(cmd, adbInvDataDrainIdentifyReadyCB, adb_aide_ctx)
end

function adbGetEnchantSum(enchant)
    local result = 0
    if enchant ~= nil then
        for _, v in pairs(adb_enchant_stats) do
            result = result + (enchant[v] or 0)
        end
    end
    return result
end

function adbInvDataDrainIdentifyReadyCB(obj, ctx)
    local has_enchant = false
    local has_removable_enchant = false
    local has_enchant_check = false
    local passed_enchant_check = false

    for _, v in ipairs(adb_enchants.order) do
        has_enchant_check = has_enchant_check or (ctx[v] ~= "")
        if obj.enchants[v] ~= nil then
            has_enchant = true
            has_removable_enchant = has_removable_enchant or obj.enchants[v].removable
            local pass = (not ctx.removable or obj.enchants[v].removable) and
                             (ctx[v] ~= "" and (adbGetEnchantSum(obj.enchants[v]) <= tonumber(ctx[v])))
            passed_enchant_check = passed_enchant_check or pass
        end
    end

    local passes = (has_enchant or not ctx.enchanted) and (has_removable_enchant or not ctx.removable) and
                       (passed_enchant_check or not has_enchant_check)

    if ctx.IR ~= "" then
        passes = passes and
                     (tonumber(ctx.IR) >= adbGetEnchantSum(obj.enchants["Illuminate"]) +
                         adbGetEnchantSum(obj.enchants["Resonate"]))
    end

    if passes then
        adbProcessIdResults(obj, ctx)
        if ctx.command ~= "" then
            local command = ctx.command .. " " .. obj.stats.id
            if ctx.bagid ~= "" then
                command = "get " .. obj.stats.id .. " " .. ctx.bagid .. "\n" .. command
            end
            Execute(command)
        end
        Note("")
    end
    adbInvDataQueueDrain()
end

------ aench command ------
local adb_aench_inv_data_queue = nil
local adb_aench_busy = false
local adb_aench_ctx = nil
local adb_aench_gag_output = true
local adb_aench_noecho = true

-- aench container.2682741121 S8 S8 I7 I7 R4 R4 fail.dropsac
function adbOnAENCHCommand(name, line, wildcards)
    adbDebugTprint(wildcards, 2)
    if adb_aench_busy then
        adbInfo("AENCH is already running, please retry when current operation finishes.")
        return
    end
    adb_aench_busy = true
    adbInfo(line)

    if wildcards.format ~= "" and adb_options[wildcards.format] == nil then
        adbInfo("Unknown format " .. wildcards.format .. " using default")
    end
    local identify_format = adb_options[wildcards.format] and adb_options[wildcards.format] or
                                adb_options[adb_options.cockpit.aide_format]

    adb_aench_ctx = {
        fomat = identify_format,
        container = wildcards.container,
        item = wildcards.item,
        enchants = {},
        fail = wildcards.failcommand,
        pass = wildcards.passcommand,
        nofocus = wildcards.nofocus,
        any = wildcards.any,
        items_queue = {},
        any_skips = {},
        item_index = 0,
        enchant_index = 0,
        current_enchants = {},
        current_obj = nil,
        stats = {
            Solidify = {},
            Illuminate = {},
            Resonate = {},
            pass = 0,
            fail = 0,
            counts = {
                Solidify = 0,
                Illuminate = 0,
                Resonate = 0,
                Disenchant = 0,
                Identify = 0
            }
        },
        compact_ctx = adbCompactMakeCtx(),
    }

    local count = 0
    local enchants = wildcards.enchants
    while enchants ~= "" do
        count = count + 1
        local enchant, value
        _, _, enchant, value = enchants:find("^ ([SIR])(%d+)")
        if enchant ~= nil then
            enchants = enchants:gsub("^ [SIR]%d+", "")
            value = tonumber(value)
        else
            _, _, enchant = enchants:find("^ ([SIR])")
            if enchant == nil then
                adbErr("Failed to parse " .. enchants)
                adbAenchFinish()
                return
            end
            enchants = enchants:gsub("^ [SIR]", "")
            value = 0
        end
        table.insert(adb_aench_ctx.enchants, {
            enchant = adbEnchantShortNameToFull(enchant),
            value = value
        })
        if count > 100 then
            adbErr("Something is off parsing " .. wildcards.enchants)
            adbAenchFinish()
            return
        end
    end

    adbCompact(true, adb_aench_ctx.compact_ctx)

    if adb_aench_ctx.nofocus == "nofocus" then
        adbAenchGatherItemsList()
        return
    end

    adb_aench_ctx.step = "Checking enchanters focus"
    Capture.untagged_output("affects 'Enchanters focus'", adb_aench_noecho, adb_aench_gag_output, true,
        adbAenchCheckFocusCB, false, adbAenchTimeoutCB)
end

function adbEnchantShortNameToFull(name)
    for k, v in pairs(adb_enchants) do
        if k ~= "order" and v == name then
            return k
        end
    end
    adbErr("Can't guess enchant name for " .. name)
    return nil
end

function adbAenchTimeoutCB()
    adbInfo("AENCH timed out at: " .. adb_aench_ctx.step)
    adbDebugTprint(adb_aench_ctx, 2)
    adbAenchFinish()
end

function adbAenchGetStatsString(tbl, k1, k2)
    local min, max, sum
    sum = 0

    for k, v in pairs(tbl) do
        v = v[k1]
        if type(v) == "table" then
            v = v[k2]
        end
        sum = sum + adbGetStatNumberSafe(v)
        min = (min == nil or min > adbGetStatNumberSafe(v)) and adbGetStatNumberSafe(v) or min
        max = (max == nil or max < adbGetStatNumberSafe(v)) and adbGetStatNumberSafe(v) or max
    end

    if sum == 0 then
        return ""
    else
        return string.format("@W%4.2f @Cavg @R%d @Cmin @G%d @Cmax", sum / #tbl, min, max)
    end
end

function adbAenchGetEnchantReport(e)
    local report = ""

    if #e == 0 then
        return report
    end

    report = adbAenchGetStatsString(e, "sum")
    if report ~= "" then
        report = string.format("\n@W%11s: %s", "TOTAL", report)
    end
    -- todo sort
    for _, v in pairs(adb_enchant_stats) do
        local line = adbAenchGetStatsString(e, "ench", v)
        if line ~= "" then
            report = string.format("%s\n@W%11s: %s", report, v:upper(), line)
        end
    end
    return report
end

function adbAenchReportStats()
    adbInfo("------------------------------ AENCH ------------------------------")
    AnsiNote(ColoursToANSI(string.format("@CProcessed @W%d @Citems, @G%d@C successfully.",
        adb_aench_ctx.stats.pass + adb_aench_ctx.stats.fail, adb_aench_ctx.stats.pass)))
    AnsiNote(ColoursToANSI(string.format("@CDisenchanted @W%d @Ctime(s), identified @W%d @Ctimes(s).",
        adb_aench_ctx.stats.counts.Disenchant, adb_aench_ctx.stats.counts.Identify)))
    AnsiNote(ColoursToANSI(string.format("@CSolidified @W%d @Ctime(s):%s", adb_aench_ctx.stats.counts.Solidify,
        adbAenchGetEnchantReport(adb_aench_ctx.stats.Solidify))))
    AnsiNote(ColoursToANSI(string.format("@CIlluminated @W%d @Ctime(s):%s", adb_aench_ctx.stats.counts.Illuminate,
        adbAenchGetEnchantReport(adb_aench_ctx.stats.Illuminate))))
    AnsiNote(ColoursToANSI(string.format("@CResonated @W%d @Ctime(s):%s", adb_aench_ctx.stats.counts.Resonate,
        adbAenchGetEnchantReport(adb_aench_ctx.stats.Resonate))))
end

function adbAenchFinish()
    adbCompact(false, adb_aench_ctx.compact_ctx)
    adbAenchReportStats()
    adb_aench_busy = false
    adbInfo("aench command finished")
end

function adbAenchCheckFocusFalling()
    if adb_aench_ctx.focus ~= nil and adb_aench_ctx.focus.falls - os.time() < 20 then
        adbInfo("AENCH Enchanters focus is fading soon! Aboring! (add nofocus if you don't care)")
        adbAenchFinish()
        return false
    end
    return true
end

function adbAenchCheckFocusCB(style_lines)
    adbDebug("adbAenchCheckFocusCB", 2)
    for _, v in ipairs(style_lines) do
        local color_line = StylesToColours(v)
        local line = strip_colours(color_line)

        if line == "You are not affected by any skills or spells." then
            adbInfo("AENCH Enchanters focus isn't up! Aborting! (add nofocus if you don't care)")
            adbAenchFinish()
            return
        end

        local pct, min, sec
        _, _, pct, min, sec = line:find("^%s+Enchanters focus%s+: (%d+)%% enchanters focus %((%d+):(%d+)%)$")
        if pct ~= nil then
            adb_aench_ctx.focus = {
                pct = tonumber(pct),
                duration = tonumber(min) * 60 + tonumber(sec)
            }
            adb_aench_ctx.focus.falls = os.time() + adb_aench_ctx.focus.duration
            break
        end
    end

    if adb_aench_ctx.focus == nil then
        adbErr("AENCH failed to process affects.");
        adbAenchFinish()
        return
    end

    if adb_aench_ctx.focus.pct < 100 then
        adbInfo("AENCH Enchanters focus is only " .. tostring(adb_aench_ctx.focus.pct) ..
                    "%! Aborting! (add nofocus if you don't care)")
        adbAenchFinish()
        return
    end

    if not adbAenchCheckFocusFalling() then
        return
    end

    adbAenchGatherItemsList()
end

function adbAenchGatherItemsList()
    adbDebug("adbAenchGatherItemsList", 2)
    adb_aench_ctx.step = "Gathering invdata"

    local command = "invdata"
    if adb_aench_ctx.item ~= "" then
        adb_aench_ctx.stats.counts.Identify = adb_aench_ctx.stats.counts.Identify + 1
        adbIdentifyItem("id " .. adb_aench_ctx.item, adbAenchSingleItemIdReadyCB)
        return
    elseif adb_aench_ctx.container ~= "" then
        if tonumber(adb_aench_ctx.container) ~= nil then
            command = "invdata " .. adb_aench_ctx.container
        else
            adbErr("Shouldn't get here")
            adbAenchFinish()
            return
        end
    end

    Capture.untagged_output(command, adb_aench_noecho, adb_aench_gag_output, true, adbAenchCheckInvdata, false,
        adbAenchTimeoutCB)
end

function adbAenchSingleItemIdReadyCB(obj)
    if obj.stats.id == nil then
        adbInfo("Item " .. adb_aench_ctx.item .. " not found!")
        adbAenchFinish()
        return
    end

    local all_passed = true
    local any_passed = false
    local any_skips = {}

    for _, e in ipairs(adb_aench_ctx.enchants) do
        if not adbCanEnchant(obj, e.enchant) then
            all_passed = false
            if adb_aench_ctx.any == "any" then
                any_skips[e.enchant] = 0
            else
                break
            end
        else
            any_passed = true
        end
    end

    if not all_passed and not (adb_aench_ctx.any == "any" and any_passed) then
        AnsiNote(ColoursToANSI("@CAENCH: can't do requested enchants on " .. adbGetItemIdAndNameString(obj)))
        if obj.stats.type == "Container" then
            adbInfo("Use container." .. obj.stats.id .. " if you want to enchants items inside it.")
        end
        adbAenchFinish()
        return
    end

    table.insert(adb_aench_ctx.items_queue, {
        id = obj.stats.id,
        colorName = obj.colorName
    })
    table.insert(adb_aench_ctx.any_skips, any_skips)
    adbAenchDrainQueue()
end

function adbAenchCheckInvdata(style_lines)
    adbDebug("adbAenchCheckInvdata", 2)

    if #style_lines == 1 and #style_lines[1] == 1 and style_lines[1][1].text:match("^Item %d+ not found.$") then
        adbInfo("Container " .. adb_aench_ctx.container .. " not found")
        adbAenchFinish()
        return
    end

    for _, v in ipairs(style_lines) do
        local line = strip_colours(StylesToColours(v))
        local id, flags, name
        _, _, id, flags, name = line:find("^(%d+),(%a*),(.*),.*,.*,.*,.*,.*$")
        if id ~= nil then
            local enchant_checks = {
                Solidify = {
                    flag = "I",
                    present = true
                },
                Illuminate = {
                    flag = "G",
                    present = false
                },
                Resonate = {
                    flag = "H",
                    present = false
                }
            }
            local all_enchantable = true
            local any_enchantable = false
            local any_skips = {}

            for _, e in ipairs(adb_aench_ctx.enchants) do
                assert(enchant_checks[e.enchant] ~= nil)
                if not ((flags:match(enchant_checks[e.enchant].flag) ~= nil) == enchant_checks[e.enchant].present) then
                    all_enchantable = false
                    if adb_aench_ctx.any == "any" then
                        any_skips[e.enchant] = 0
                    else
                        break
                    end
                else
                    any_enchantable = true
                end
            end
            if all_enchantable or (adb_aench_ctx.any == "any" and any_enchantable) then
                table.insert(adb_aench_ctx.items_queue, {
                    id = id,
                    colorName = name
                })
                table.insert(adb_aench_ctx.any_skips, any_skips)
            end
        end
    end

    if #adb_aench_ctx.items_queue > 20 then
        adbInfo("You have " .. #adb_aench_ctx.items_queue .. " matching items, doing only 20 see help enchantbot")
        while #adb_aench_ctx.items_queue > 20 do
            table.remove(adb_aench_ctx.items_queue, 21)
        end
    end

    adbAenchDrainQueue()
end

function adbAenchDrainQueue()
    adbDebug("adbAenchDrainQueue", 2)
    adb_aench_ctx.step = "Draining queue"

    if #adb_aench_ctx.items_queue == 0 then
        adbInfo("Can't enchant any items in " ..
                    (adb_aench_ctx.container ~= "" and adb_aench_ctx.container or "inventory"))
        adbAenchFinish()
        return
    end

    adb_aench_ctx.item_index = 1
    adb_aench_ctx.enchant_index = 1
    adb_aench_ctx.current_obj = nil
    adb_aench_ctx.current_enchants = {}
    adbAenchDrainOne()
end

function adbCompactMakeCtx()
    return {
        compact_mode = gmcp("config.compact"),
        prompt_mode = gmcp("config.prompt"),
    }
end

function adbCompact(on, ctx)
    if ctx.compact_mode == "NO" then
        local set = on and "YES" or "NO"
        Send_GMCP_Packet("config compact " .. set)
        CallPlugin("3e7dedbe37e44942dd46d264" , "OnPluginTelnetSubnegotiation",
                   201, "config { \"compact\" : \"" .. set .. "\" }")
    end

    if ctx.prompt_mode == "YES" then
        local set = on and "NO" or "YES"
        Send_GMCP_Packet("config prompt " .. set)
        CallPlugin("3e7dedbe37e44942dd46d264" , "OnPluginTelnetSubnegotiation",
                   201, "config { \"prompt\" : \"" .. set .. "\" }")
    end
end

function adbAenchOnItemDone(result)
    local item = adb_aench_ctx.items_queue[adb_aench_ctx.item_index]
    if result == "pass" then
        adb_aench_ctx.stats.pass = adb_aench_ctx.stats.pass + 1
        if adb_aench_ctx.current_obj ~= nil then
            adbProcessIdResults(adb_aench_ctx.current_obj, {
                id = adb_aench_ctx.items_queue[adb_aench_ctx.item_index].id,
                format = adb_aench_ctx.fomat,
                bagid = adb_aench_ctx.container,
                channel = "",
            })
        else
            AnsiNote(
                ColoursToANSI(string.format("@CAENCH PASS: %s", adbCombineIdAndNameString(item.id, item.colorName))))
        end
    else
        adb_aench_ctx.stats.fail = adb_aench_ctx.stats.fail + 1
        local enchant = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index]
        AnsiNote(ColoursToANSI(string.format("@CAENCH FAILED at %d:%s: %s", adb_aench_ctx.enchant_index,
            adb_enchants[enchant.enchant] .. (enchant.value ~= 0 and enchant.value or ""),
            adbCombineIdAndNameString(item.id, item.colorName))))
    end

    local command = ""
    if adb_aench_ctx[result] ~= "" then
        command = adb_aench_ctx[result] .. " " .. adb_aench_ctx.items_queue[adb_aench_ctx.item_index].id
    elseif adb_aench_ctx.container ~= "" then
        command = "put " .. adb_aench_ctx.items_queue[adb_aench_ctx.item_index].id .. " " .. adb_aench_ctx.container
    end

    adb_aench_ctx.enchant_index = 1
    adb_aench_ctx.item_index = adb_aench_ctx.item_index + 1
    adb_aench_ctx.current_obj = nil
    adb_aench_ctx.current_enchants = {}

    local func = (adb_aench_ctx.item_index > #adb_aench_ctx.items_queue or
                     (adb_aench_ctx.stats.counts.Identify == 0 and adb_aench_ctx.stats.counts.Disenchant == 0)) and
                     adbAenchDrainOne or adbAenchPause

    if command == "" then
        func()
    else
        Capture.untagged_output(command, adb_aench_noecho,
            adb_aench_ctx[result] == "" and adb_aench_gag_output or false, true, func, true, adbAenchTimeoutCB)
    end
end

function adbAenchPause()
    adbCompact(false, adb_aench_ctx.compact_ctx)
    adb_aench_ctx.paused = true
    ColourTell("cyan", "black", "\nType <aench resume> or [")
    Hyperlink("aench resume", "Click to <aench resume>", "Click to resume AENCH", "green", "black", false)
    ColourTell("cyan", "black", "]")
    Note("")
end

function adbAenchResume()
    if adb_aench_ctx.paused then
        adb_aench_ctx.paused = false
        adbCompact(true, adb_aench_ctx.compact_ctx)
        adbAenchDrainOne()
    else
        adbInfo("AENCH isn't paused!")
    end
end

function adbAenchAbort()
    if adb_aench_ctx.paused then
        adb_aench_ctx.paused = false
        adbInfo("Aborting...")
        adbAenchFinish()
    else
        adbInfo("AENCH isn't paused!")
    end
end

function adbAenchDrainOne(ignored_arg)
    if adb_aench_ctx.enchant_index == 1 and not adbAenchCheckFocusFalling() then
        return
    end

    if adb_aench_ctx.item_index > #adb_aench_ctx.items_queue then
        adbAenchFinish()
        return
    end

    if adb_aench_ctx.enchant_index > #adb_aench_ctx.enchants then
        adbAenchOnItemDone("pass")
        return
    end

    local item = adb_aench_ctx.items_queue[adb_aench_ctx.item_index]
    local enchant = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index]

    if adb_aench_ctx.enchant_index == 1 then
        AnsiNote(ColoursToANSI(string.format("@CAENCH Enchanting [%d/%d]: %s", adb_aench_ctx.item_index,
            #adb_aench_ctx.items_queue, adbCombineIdAndNameString(item.id, item.colorName))))

        adb_aench_ctx.current_enchants = copytable.deep(adb_aench_ctx.any_skips[adb_aench_ctx.item_index])
        adb_aench_ctx.picked_item = false
    end

    if adb_aench_ctx.current_enchants[enchant.enchant] ~= nil then
        adbDebug("Skipping enchant " .. enchant.enchant, 2)
        adb_aench_ctx.enchant_index = adb_aench_ctx.enchant_index + 1
        adbAenchDrainOne()
        return
    end

    adb_aench_ctx.step = "Enchanting " .. adb_aench_ctx.item_index .. ":" .. adb_aench_ctx.enchant_index

    local command = "cast " .. enchant.enchant .. " " .. item.id
    if adb_aench_ctx.container ~= "" and not adb_aench_ctx.picked_item then
        adb_aench_ctx.picked_item = true
        command = "get " .. item.id .. " " .. adb_aench_ctx.container .. "\n" .. command
    end
    adbAenchCastSpell(command, adbAenchEnchantCastDoneCB, adbAenchCastFail, adbAenchTimeoutCB)
end

function adbAenchCastFail(command, reason)
    adbInfo("Failed to do: " .. command .. " because " .. reason)
    adbAenchFinish()
end

local adb_aench_cast_ctx = nil
function adbAenchCastSpell(command, passCB, failCB, timeoutCB)
    adb_aench_cast_ctx = {
        command = command,
        passCB = passCB,
        failCB = failCB,
        timeoutCB = timeoutCB
    }
    Capture.untagged_output(command, adb_aench_noecho, adb_aench_gag_output, true, adbAenchCastSpellDoneCB, false,
        timeoutCB)
end

function adbAenchCastSpellDoneCB(style_lines)
    adbDebug("adbAenchCastSpellDoneCB", 2)
    adbDebugTprint(style_lines, 3)

    local failed = false
    local recast = false
    local soft_fail = false
    local reason = "unknown"
    for _, v in ipairs(style_lines) do
        local line = strip_colours(StylesToColours(v))

        if line:find("^You do not have that item.$") then
            failed = true
            reason = line
            break
        end

        local snum, sfail_reason
        local sfail_to_reason = {
            ["1"] = "Regular fail, lost concentration.",
            ["2"] = "Already affected.",
            ["3"] = "Cast blocked by a recovery, see below.",
            ["4"] = "Not enough mana.",
            ["5"] = "You are in a nocast room.",
            ["6"] = "Fighting or other \"can't concentrate\".",
            ["8"] = "You don't know the spell.",
            ["9"] = "Tried to cast self only on other.",
            ["10"] = "You are resting / sitting.",
            ["11"] = "Skill/spell has been disabled.",
            ["12"] = "Not enough moves."
        }
        _, _, snum, sfail_reason = line:find("^{sfail}(%-?%d+),%d+,(%d+),%-?%d+$")
        if snum ~= nil then
            failed = true
            recast = sfail_reason == "1"
            reason = sfail_to_reason[sfail_reason]
            break
        end

        if line:match("^You dream about casting your spells.$") ~= nil then
            failed = true
            reason = line
            break
        end

        if line:match("^You dream about being able to disenchant.$") ~= nil then
            failed = true
            reason = line
            break
        end

        local enchant = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index]
        assert(enchant ~= nil)

        if line:match(" is not invisible.$") ~= nil or line:match(" is already glowing.$") ~= nil or
            line:match(" is already humming gently.$") ~= nil then
            -- shouldn't really get here
            assert(adb_aench_ctx.current_enchants[enchant.enchant] ~= nil)
            failed = true
            reason = line
            soft_fail = true
            break
        end

        if line:find(" cannot be illuminated%.$") or line:find(" cannot be resonated%.$") then
            assert(adb_aench_ctx.current_enchants[enchant.enchant] == nil)
            failed = true
            reason = line
            soft_fail = true
            break
        end

        local disenchanted
        _, _, disenchanted = line:find("^The (%a+) enchantment stats have been removed from this item$")
        if disenchanted ~= nil then
            assert(disenchanted:upper() == enchant.enchant:upper())
            assert(adb_aench_ctx.current_enchants[enchant.enchant] ~= nil)
            adb_aench_ctx.current_enchants[enchant.enchant] = nil
            break
        end

        local message_to_enchant_name = {
            ["^You solidify .+ making it visible again%.$"] = "Solidify",
            ["starts to glow brightly as you infuse it with holy magic%.$"] = "Illuminate",
            ["begins to hum softly%.$"] = "Resonate"
        }
        for k, v in pairs(message_to_enchant_name) do
            if line:find(k) then
                assert(v == enchant.enchant)
                assert(adb_aench_ctx.current_enchants[enchant.enchant] == nil)
                -- don't know if enchant is successful yet, so just mark as enchanted
                adb_aench_ctx.current_enchants[enchant.enchant] = 0
                break
            end
        end

        local enchant_pass_messages = {"^Magic pulses through .+, enhancing its power%.$",
                                       "^Magic pulses through .+, blessing it with fortune%.$"}
        for _, v in ipairs(enchant_pass_messages) do
            if line:find(v) then
                assert(adb_aench_ctx.current_enchants[enchant.enchant] ~= nil)
                -- don't know exact stats added, but it's at least 1 now
                adb_aench_ctx.current_enchants[enchant.enchant] = 1
                break
            end
        end

        -- TODO: add removed due to focus messages and recast
    end

    if recast then
        adbAenchCastSpell(adb_aench_cast_ctx.command, adb_aench_cast_ctx.passCB, adb_aench_cast_ctx.failCB,
            adb_aench_cast_ctx.timeoutCB)
        return
    elseif failed and not soft_fail then
        adb_aench_cast_ctx.failCB(adb_aench_cast_ctx.command, reason)
        return
    end

    adb_aench_cast_ctx.passCB(soft_fail, reason)
end

function adbAenchEnchantCastDoneCB(soft_fail, reason)
    adbDebug("adbAenchEnchantCastDoneCB", 2)

    local enchant = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index]
    assert(enchant)
    adb_aench_ctx.stats.counts[enchant.enchant] = adb_aench_ctx.stats.counts[enchant.enchant] + 1

    if soft_fail then
        -- can't enchant item at all, mark it as having 0 enchant
        adb_aench_ctx.current_enchants[enchant.enchant] = 0
    end

    -- We either know the value is 0, or it's >=1 without running actual Identify command
    -- TODO: I assume that enchants casted without focus which landed with 0 stats
    -- can't be disenchanted. Check this few more times?
    if enchant.value <= adb_aench_ctx.current_enchants[enchant.enchant] or
        adb_aench_ctx.current_enchants[enchant.enchant] == 0 then
        adbAenchItemIdReadyCB(nil)
    else
        adbDebug("doing ID", 2)
        adb_aench_ctx.stats.counts.Identify = adb_aench_ctx.stats.counts.Identify + 1
        adbIdentifyItem("id " .. adb_aench_ctx.items_queue[adb_aench_ctx.item_index].id, adbAenchItemIdReadyCB)
    end
end

function adbAenchItemIdReadyCB(obj)
    adbDebug("adbAenchItemIdReadyCB", 2)
    adbDebugTprint(obj, 3)
    adbDebugTprint(adb_aench_ctx.enchants, 3)

    if obj ~= nil and obj.stats.id == nil then
        adbInfo("Item " .. adb_aench_ctx.item .. " not found!")
        adbAenchFinish()
        return
    end

    adb_aench_ctx.current_obj = obj
    local enchant = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index]
    local min_value = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index].value

    if obj ~= nil then
        table.insert(adb_aench_ctx.stats[enchant.enchant], {
            sum = adbGetEnchantSum(obj.enchants[enchant.enchant]),
            ench = copytable.deep(obj.enchants[enchant.enchant])
        })
    elseif adb_aench_ctx.current_enchants[enchant.enchant] == 0 then
        table.insert(adb_aench_ctx.stats[enchant.enchant], {
            sum = 0,
            ench = {}
        })
    end

    if adb_aench_ctx.current_enchants[enchant.enchant] == nil or (obj ~= nil and obj.enchants[enchant.enchant] == nil) then
        adbErr("AENCH no " .. enchant.enchant .. " enchant on item!")
        adbAenchFinish()
        return
    end

    if min_value <= adb_aench_ctx.current_enchants[enchant.enchant] or
        (obj ~= nil and min_value <= adbGetEnchantSum(obj.enchants[enchant.enchant])) then
        adb_aench_ctx.enchant_index = adb_aench_ctx.enchant_index + 1
        adbAenchDrainOne()
        return
    end

    if adb_aench_ctx.current_enchants[enchant.enchant] == 0 or not obj.enchants[enchant.enchant].removable then
        adbAenchOnItemDone("fail")
        return
    end

    -- should only get here if item was actually identified
    local command = "disenchant " .. adb_aench_ctx.items_queue[adb_aench_ctx.item_index].id .. " " .. enchant.enchant ..
                        " confirm"
    adbAenchCastSpell(command, adbAenchDisenchantCastDoneCB, adbAenchCastFail, adbAenchTimeoutCB)
end

function adbAenchDisenchantCastDoneCB(soft_fail)
    adbDebug("adbAenchDisenchantCastDoneCB", 2)
    assert(not soft_fail)

    adb_aench_ctx.stats.counts.Disenchant = adb_aench_ctx.stats.counts.Disenchant + 1

    -- skip unnecessary item id, just alter relevant enchant and flags
    if adb_aench_ctx.current_obj ~= nil then
        local obj = adb_aench_ctx.current_obj
        local enchant = adb_aench_ctx.enchants[adb_aench_ctx.enchant_index]
        obj.enchants[enchant.enchant] = nil
        if enchant.enchant == "Solidify" then
            obj.stats.flags = obj.stats.flags:gsub("solidified", "")
            obj.stats.flags = obj.stats.flags .. " invis"
        elseif enchant.enchant == "Illuminate" then
            obj.stats.flags = obj.stats.flags:gsub("illuminated", "")
            obj.stats.flags = obj.stats.flags:gsub("glow", "")
        elseif enchant.enchant == "Resonate" then
            obj.stats.flags = obj.stats.flags:gsub("resonated", "")
            obj.stats.flags = obj.stats.flags:gsub("hum", "")
        else
            adbErr("Unknown enchant " .. enchant.enchant)
            adbAenchFinish()
            return
        end
    end

    adb_aench_ctx.enchant_index = adb_aench_ctx.enchant_index + 1
    if adb_aench_ctx.enchant_index > #adb_aench_ctx.enchants then
        adbAenchOnItemDone("fail")
    else
        adbAenchDrainOne()
    end
end

------ Adb shop ------
local adb_shop_busy = false
local adb_shop_ctx = nil
local adb_shop_queue = nil

function adbOnAdbShop(name, line, wildcards)
    if adb_shop_busy then
        adbInfo("adb shop is already running, please retry when current operation finishes.")
        return
    end
    if gmcp("char.status.state") ~= "3" then
        adbInfo("Can't run adb shop in current character state.")
        return
    end

    adb_shop_busy = true
    adbInfo(line)

    adb_shop_ctx = {
        all = wildcards.all,
        zone = gmcp("room.info.zone"),
        room = gmcp("room.info.num")
    }
    adb_shop_queue = {}

    Capture.untagged_output("list", true, true, true, adbOnAdbShopListReady, false)
end

function adbOnAdbShopListReady(style_lines)
    adbDebug("adbOnAdbShopListReady", 2)
    for _, v in ipairs(style_lines) do
        local color_line = StylesToColours(v)
        local line = strip_colours(color_line)

        if line == "There is no shopkeeper here." then
            adb_shop_busy = false
            adbInfo("There is no shopkeeper here.")
            return
        end

        local number, level, price, qty, name, color_name
        _, _, number, level, price, qty, name = line:find("^%s*(%d+)%s+(%d+)%s+(%d+ ?%a*)%s+(%S+)%s+(.-)%s*$")

        if number ~= nil then
            local pattern = "%s*%d+%s+%d+%s+%d+ ?%a*%s+%S+%s+(.-)%s*"
            -- strange item in Radiance Woods shop, where some spaces appear after @w
            -- [@w  1    200      950  ---  @C+++@WCure Poison@C+++@w  ]
            _, _, color_name = color_line:find("^@w" .. pattern .. "@w%s*$")
            if color_name == nil then
                _, _, color_name = color_line:find("^@w" .. pattern .. "$")
            end
            if color_name == nil then
                _, _, color_name = color_line:find("^@x%d%d%d" .. pattern .. "@w%s*$")
            end
            if color_name == nil then
                _, _, color_name = color_line:find("^@x%d%d%d" .. pattern .. "$")
            end
            if color_name == nil then
                adbErr("Can't parse color name in [" .. color_line .. "]")
            elseif adb_shop_ctx.all ~= "all" and qty ~= "---" then
                adbDebug("Skipping limited qty item " .. color_name, 2)
            elseif adbGetBlootLevel(name) > 0 then
                adbDebug("Skipping bloot item " .. color_name, 2)
            else
                local cache_item = nil
                if qty == "---" then
                    cache_item = adbCacheGetItem(color_name, adb_shop_ctx.zone)
                else
                    -- Can do something like
                    -- cache_item = adbCacheGetItemByName(color_name)
                    -- but that would mean we might actually miss the items with same name from different zones.
                    -- So will identify item and check to be sure.
                end

                if cache_item ~= nil then
                    -- TODO check if need to update identify version, full/partial id etc.
                    local mob = {
                        name = "shopkeeper",
                        colorName = "@Yshopkeeper",
                        rooms = adb_shop_ctx.room,
                        zone = adb_shop_ctx.zone
                    }
                    adbCacheItemAddMobs(cache_item, {mob})
                else
                    local t = {
                        number = number,
                        level = level,
                        price = price,
                        qty = qty,
                        name = name,
                        colorName = color_name
                    }
                    table.insert(adb_shop_queue, t)
                end
            end
        end
    end

    if #adb_shop_queue == 0 then
        adbInfo("adb shop found no items to update")
        adb_shop_busy = false
        return
    end

    adbInfo("adb shop checking " .. #adb_shop_queue .. " item(s).")
    adbShopQueueDrain()
end

function adbShopQueueDrain()
    if #adb_shop_queue == 0 then
        adb_shop_busy = false
        adbInfo("adb shop finished.")
        return
    end

    adb_shop_ctx.item = table.remove(adb_shop_queue, 1)
    adbIdentifyItem("appraise " .. adb_shop_ctx.item.number, adbShopIdreadyCB, adb_shop_ctx)
end

function adbShopIdreadyCB(obj, ctx)
    if obj.stats.id == nil then
        adbInfo("Failed to appraise " .. ctx.item.number .. " shop content changed.")
        adbShopQueueDrain()
        return
    end

    -- TODO check if need to update identify version, full/partial id etc.
    if ctx.item.colorName ~= obj.colorName then
        AnsiNote(ColoursToANSI("@CADB: shop content changed, ignoring @w[" .. ctx.item.colorName .. "@w] got [" ..
                                   obj.colorName .. "@w]"))
        -- there's no point to continue because all subsequent item indicies are out of sync too now
        -- let's try to find if some items were gone from the shop on timer and resync
        while #adb_shop_queue > 0 do
            ctx.item = adb_shop_queue[1]
            table.remove(adb_shop_queue, 1)
            if ctx.item.colorName == obj.colorName then
                break
            end
        end
    end

    if ctx.item.colorName ~= obj.colorName or adbGetBlootLevel(obj.stats.name) > 0 then
        -- Intentionally left blank
    elseif ctx.item.qty == "---" then
        obj.location = {
            zone = ctx.zone,
            mobs = {}
        }
        local mob = {
            name = "shopkeeper",
            colorName = "@Yshopkeeper",
            rooms = tostring(ctx.room),
            zone = ctx.zone
        }
        adbItemLocationAddMob(obj, mob)
        adbCacheAdd(obj)
    else
        local cache_item = adbCacheGetItemByNameAndFoundAt(obj.colorName, obj.stats.foundat)
        if cache_item == nil then
            if adbAreaNameXref[obj.stats.foundat] ~= nil then
                obj.location = {
                    zone = adbAreaNameXref[obj.stats.foundat],
                    mobs = {}
                }
                adbStripEnchants(obj)
                adbCacheAdd(obj)
            else
                adbErr("Don't know short zone name for " .. obj.stats.foundat)
            end
        else
            AnsiNote(ColoursToANSI("@CADB item already in cache: @w[" .. obj.colorName .. "@w]"))
        end
    end

    adbShopQueueDrain()
end

-- borrowed the list from s&d
adbAreaNameXref = {
    ["A Genie's Last Wish"] = "geniewish",
    ["A Magical Hodgepodge"] = "hodgepodge",
    ["A Peaceful Giant Village"] = "village",
    ["Aardington Estate"] = "aardington",
    ["Aardwolf Zoological Park"] = "zoo",
    ["Adventures in Sendhia"] = "sendhian",
    ["Aerial City of Cineko"] = "cineko",
    ["Afterglow"] = "afterglow",
    ["Alagh, the Blood Lands"] = "alagh",
    ["All in a Fayke Day"] = "fayke",
    ["Ancient Greece"] = "greece",
    ["Andolor's Ocean Adventure Park"] = "oceanpark",
    ["Annwn"] = "annwn",
    ["Anthrox"] = "anthrox",
    ["Arboretum"] = "arboretum",
    ["Arisian Realm"] = "arisian",
    ["Art of Melody"] = "melody",
    ["Artificer's Mayhem"] = "mayhem",
    ["Ascension Bluff Nursing Home"] = "nursing",
    ["Atlantis"] = "atlantis",
    ["Avian Kingdom"] = "avian",
    ["Battlefields of Adaldar"] = "adaldar",
    ["Black Lagoon"] = "lagoon",
    ["Black Rose"] = "blackrose",
    ["Brightsea and Glimmerdim"] = "glimmerdim",
    ["Canyon Memorial Hospital"] = "canyon",
    ["Castle Vlad-Shamir"] = "vlad",
    ["Chaprenula's Laboratory"] = "lab",
    ["Child's Play"] = "childsplay",
    ["Christmas Vacation"] = "xmas",
    ["Cloud City of Gnomalin"] = "gnomalin",
    ["Cradlebrook"] = "cradle",
    ["Crossroads of Fortune"] = "fortune",
    ["Crynn's Church"] = "crynn",
    ["Dark Elf Stronghold"] = "stronghold",
    ["Death's Manor"] = "manor",
    ["Deathtrap Dungeon"] = "deathtrap",
    ["Den of Thieves"] = "thieves",
    ["Descent to Hell"] = "hell",
    ["Desert Doom"] = "ddoom",
    ["Dhal'Gora Outlands"] = "dhalgora",
    ["Diamond Soul Revelation"] = "dsr",
    ["Dortmund"] = "dortmund",
    ["Dread Tower"] = "dread",
    ["Dusk Valley"] = "duskvalley",
    ["Earth Plane 4"] = "earthplane",
    ["Elemental Chaos"] = "elemental",
    ["Empyrean, Streets of Downfall"] = "empyrean",
    ["Entrance to Hades"] = "hades",
    ["Eternal Autumn"] = "autumn",
    ["Faerie Tales II"] = "ftii",
    ["Faerie Tales"] = "ft1",
    ["Fantasy Fields"] = "fantasy",
    ["Foolish Promises"] = "promises",
    ["Fort Terramire"] = "terramire",
    ["Gallows Hill"] = "gallows",
    ["Gelidus"] = "gelidus",
    ["Giant's Pet Store"] = "petstore",
    ["Gilda And The Dragon"] = "gilda",
    ["Gnoll's Quarry"] = "quarry",
    ["Gold Rush"] = "goldrush",
    ["Guardian's Spyre of Knowledge"] = "spyreknow",
    ["Wayfarer's Caravan"] = "caravan",
    ["Halls of the Damned"] = "damned",
    ["Hatchling Aerie"] = "hatchling",
    ["Hedgehogs' Paradise"] = "hedge",
    ["Helegear Sea"] = "helegear",
    ["Hotel Orlando"] = "orlando",
    ["House of Cards"] = "cards",
    ["Icefall"] = "icefall",
    ["Imagi's Nation"] = "imagi",
    ["Imperial Nation"] = "imperial",
    ["Insanitaria"] = "insan",
    ["Into the Long Night"] = "longnight",
    ["Intrigues of Times Past"] = "times",
    ["Island of Lost Time"] = "losttime",
    ["Jenny's Tavern"] = "jenny",
    ["Jotunheim"] = "jotun",
    ["Jungles of Verume"] = "verume",
    ["Keep of the Kobaloi"] = "kobaloi",
    ["Kerofk"] = "kerofk",
    ["Ketu Uplands"] = "ketu",
    ["Kiksaadi Cove"] = "cove",
    ["Kimr's Farm"] = "farm",
    ["Kingdom of Ahner"] = "ahner",
    ["Kingsholm"] = "kingsholm",
    ["Kobold Siege Camp"] = "siege",
    ["Kul Tiras"] = "kultiras",
    ["Land of Legend"] = "legend",
    ["Living Mines of Dak'Tai"] = "livingmine",
    ["Masquerade Island"] = "masq",
    ["Mount duNoir"] = "dunoir",
    ["Mudwog's Swamp"] = "mudwog",
    ["Nanjiki Ruins"] = "nanjiki",
    ["Nebulous Horizon"] = "horizon",
    ["Necromancers' Guild"] = "necro",
    ["Nenukon and the Far Country"] = "nenukon",
    ["New Thalos"] = "newthalos",
    ["Northstar"] = "northstar",
    ["Nottingham"] = "nottingham",
    ["Olde Worlde Carnivale"] = "carnivale",
    ["Onyx Bazaar"] = "bazaar",
    ["Ookushka Garrison"] = "ooku",
    ["Paradise Lost"] = "paradise",
    ["Plains of Nulan'Boar"] = "nulan",
    ["Pompeii"] = "pompeii",
    ["Prosper's Island"] = "prosper",
    ["Qong"] = "qong",
    ["Radiance Woods"] = "radiance",
    ["Raganatittu"] = "raga",
    ["Realm of Deneria"] = "deneria",
    ["Realm of the Firebird"] = "firebird",
    ["Realm of the Sacred Flame"] = "firenation",
    ["Realm of the Zodiac"] = "zodiac",
    ["Rebellion of the Nix"] = "rebellion",
    ["Rosewood Castle"] = "rosewood",
    ["Sagewood Grove"] = "sagewood",
    ["Sanctity of Eternal Damnation"] = "sanctity",
    ["Sen'narre Lake"] = "sennarre",
    ["Seven Wonders"] = "wonders",
    ["Shadow's End"] = "shadowsend",
    ["Sheila's Cat Sanctuary"] = "cats",
    ["Sho'aram, Castle in the Sand"] = "sandcastle",
    ["Siren's Oasis Resort"] = "sirens",
    ["Snuckles Village"] = "snuckles",
    ["Storm Mountain"] = "storm",
    ["Storm Ships of Lem-Dagor"] = "lemdagor",
    ["Sundered Vale"] = "vale",
    ["Swordbreaker's Hoard"] = "hoard",
    ["Tairayden Peninsula"] = "peninsula",
    ["Tai'rha Laym"] = "laym",
    ["Takeda's Warcamp"] = "takeda",
    ["Tanra'vea"] = "tanra",
    ["Thandeld's Conflict"] = "conflict",
    ["The Abyssal Caverns of Sahuagin"] = "sahuagin",
    ["The Amazon Nation"] = "amazon",
    ["The Amusement Park"] = "amusement",
    ["The Archipelago of Entropy"] = "entropy",
    ["The Astral Travels"] = "astral",
    ["The Aylorian Academy"] = "academy",
    ["The Blighted Tundra of Andarin"] = "andarin",
    ["The Blood Opal of Rauko'ra"] = "raukora",
    ["The Blood Sanctum"] = "sanctum",
    ["The Broken Halls of Horath"] = "horath",
    ["The Call of Heroes"] = "callhero",
    ["The Cataclysm"] = "cataclysm",
    ["The Chasm and The Catacombs"] = "chasm",
    ["The Chessboard"] = "chessboard",
    ["The Continent of Mesolar"] = "mesolar",
    ["The Coral Kingdom"] = "coral",
    ["The Cougarian Queendom"] = "cougarian",
    ["The Council of the Wyrm"] = "wyrm",
    ["The Covenant of Mistridge"] = "mistridge",
    ["The Cracks of Terra"] = "terra",
    ["The Curse of the Midnight Fens"] = "fens",
    ["The Dark Continent, Abend"] = "abend",
    ["The Dark Temple of Zyian"] = "zyian",
    ["The DarkLight"] = "darklight",
    ["The Darkside of the Fractured Lands"] = "darkside",
    ["The Deadlights"] = "deadlights",
    ["The Desert Prison"] = "desert",
    ["The Drageran Empire"] = "drageran",
    ["The Dungeon of Doom"] = "dundoom",
    ["The Earth Lords"] = "earthlords",
    ["The Eighteenth Dynasty"] = "dynasty",
    ["The Empire of Aiighialla"] = "empire",
    ["The Empire of Talsa"] = "talsa",
    ["The Fabled City of Stone"] = "stone",
    ["The Fire Swamp"] = "fireswamp",
    ["The First Ascent"] = "ascent",
    ["The Flying Citadel"] = "citadel",
    ["The Forest of Li'Dnesh"] = "lidnesh",
    ["The Fractured Lands"] = "fractured",
    ["The Gathering Horde"] = "gathering",
    ["The Gauntlet"] = "gauntlet",
    ["The Gladiator's Arena"] = "arena",
    ["The Glamdursil"] = "glamdursil",
    ["The Goblin Fortress"] = "fortress",
    ["The Grand City of Aylor"] = "aylor",
    ["The Graveyard"] = "graveyard",
    ["The Great City of Knossos"] = "knossos",
    ["The Great Salt Flats"] = "salt",
    ["The Icy Caldera of Mauldoon"] = "caldera",
    ["The Imperial City of Reme"] = "reme",
    ["The Infestation"] = "infest",
    ["The Keep of Kearvek"] = "kearvek",
    ["The Killing Fields"] = "fields",
    ["The Labyrinth"] = "labyrinth",
    ["The Land of Oz"] = "landofoz",
    ["The Land of the Beer Goblins"] = "beer",
    ["The Lower Planes"] = "lplanes",
    ["The Maelstrom"] = "maelstrom",
    ["The Marshlands of Agroth"] = "agroth",
    ["The Misty Shores of Yarr"] = "yarr",
    ["The Monastery"] = "monastery",
    ["The Mountains of Desolation"] = "desolation",
    ["The Nine Hells"] = "ninehells",
    ["The Nyne Woods"] = "nynewoods",
    ["The Old Cathedral"] = "cathedral",
    ["The Palace of Song"] = "songpalace",
    ["The Partroxis"] = "partroxis",
    ["The Path of the Believer"] = "believer",
    ["The Realm of Infamy"] = "infamy",
    ["The Realm of the Hawklords"] = "hawklord",
    ["The Relinquished Tombs"] = "tombs",
    ["The Reman Conspiracy"] = "remcon",
    ["The Ruins of Diamond Reach"] = "ruins",
    ["The Ruins of Stormhaven"] = "stormhaven",
    ["The Sanguine Tavern"] = "sanguine",
    ["The Scarred Lands"] = "scarred",
    ["The School of Horror"] = "soh",
    ["The Shadows of Minos"] = "minos",
    ["The Silver Volcano"] = "volcano",
    ["The Slaughter House"] = "slaughter",
    ["The Southern Ocean"] = "southern",
    ["The Stuff of Shadows"] = "stuff",
    ["The Temple of Shal'indrael"] = "temple",
    ["The Temple of Shouggoth"] = "shouggoth",
    ["The Three Pillars of Diatz"] = "diatz",
    ["The Titans' Keep"] = "titan",
    ["The Tournament of Illoria"] = "illoria",
    ["The Town of Solan"] = "solan",
    ["The Tree of Life"] = "tol",
    ["The Trouble with Gwillimberry"] = "gwillim",
    ["The Uncharted Oceans"] = "uncharted",
    ["The UnderDark"] = "underdark",
    ["The Upper Planes"] = "uplanes",
    ["The Uprising"] = "uprising",
    ["The Were Wood"] = "werewood",
    ["The Witches of Omen Tor"] = "omentor",
    ["The Wobbly Woes of Woobleville"] = "wooble",
    ["The Wood Elves of Nalondir"] = "woodelves",
    ["The Yurgach Domain"] = "yurgach",
    ["Tilule Rehabilitation Clinic"] = "tilule",
    ["Tir na nOg"] = "tirna",
    ["Tournament Camps"] = "camps",
    ["Transcendece"] = "transcend",
    ["Tribal Origins"] = "origins",
    ["Tumari's Diner"] = "diner",
    ["Umari's Castle"] = "umari",
    ["Unearthly Bonds"] = "bonds",
    ["Verdure Estate"] = "verdure",
    ["Vidblain, the Ever Dark"] = "vidblain",
    ["War of the Wizards"] = "wizards",
    ["Warrior's Training Camp"] = "wtc",
    ["Wayward Alehouse"] = "alehouse",
    ["Weather Observatory"] = "weather",
    ["Wedded Bliss"] = "bliss",
    ["Wildwood"] = "wildwood",
    ["Winds of Fate"] = "winds",
    ["Winterlands"] = "winter",
    ["Xyl's Mosaic"] = "xylmos",
    ["Yggdrasil: The World Tree"] = "ygg",
    ["Zangar's Demonic Grotto"] = "zangar",
    ["The Keep of the Asherodan"] = "asherodan",
    ["Bloodlust Dungeon"] = "dungeon",
    ["Oradrin's Chosen"] = "oradrin",
    -- ["Midgaard"] = "",
    ["From The Midgaardian Publishing Group"] = "gaardian",
    ["From The Seekers"] = "seekers",
    ["From Boot Camp"] = "bootcamp",
    ["From Crusaders of the Nameless One"] = "crusaders",
    ["From The Creation of Tao"] = "tao",
    ["From The Order of Light"] = "light",
    ["From The Fellowship of the Twin Lobes"] = "twinlobe",
    ["From The Watchmen of Aardwolf"] = "watchmen",
    ["From The Emerald Knights"] = "emerald",
    ["From Order of the Bard"] = "bard",
    ["From The Great Circle of Druids"] = "druid",
    ["From The Tribes of the Amazon"] = "amazonclan",
    ["From The Soul Pyre"] = "pyre",
    ["From Masaki Clan"] = "masaki",
    ["From Knights of Perdition"] = "perdition",
    ["From Loqui"] = "loqui",
    ["From House of Touchstone"] = "touchstone",
    ["Aardwolf Estates 2000"] = "manor3",
    ["Fractals of the Weave"] = "fractal",
    ["Chakra Spire"] = "chakra",
    ["Prairie Village Estates"] = "manorville",
    ["From The Order of Shadokil"] = "shadokil",
    ["From The Society of Tanelorn"] = "tanelorn",
    ["From Vanir"] = "vanir",
    ["Fellchantry"] = "chantry",
    ["Sea King's Dominion"] = "seaking",
    ["Transcendence"] = "transcend"
}

------  ACMP -------
local acmp_ctx = {}
function adbOnAcmp(name, line, wildcards)
    adbInfo(line)
    if wildcards.format ~= "" and adb_options[wildcards.format] == nil then
        adbInfo("Unknown format " .. wildcards.format .. " using default")
    end
    local format = adb_options[wildcards.format] or adb_options[adb_options.cockpit.identify_format]

    acmp_ctx = {
        item1 = wildcards.item1,
        item2 = wildcards.item2,
        format = format
    }
    adbIdentifyItem("id " .. wildcards.item1, adbAcmpItem1IdReadyCB, acmp_ctx)
end

function adbAcmpItem1IdReadyCB(obj, ctx)
    if obj.stats.id == nil then
        adbInfo(ctx.item1 .. " not found.")
        return
    end
    acmp_ctx["obj1"] = obj

    if ctx.item2 ~= "" then
        adbIdentifyItem("id " .. ctx.item2, adbAcmpItem2IdReadyCB, acmp_ctx)
        return
    end

    Capture.tagged_output("eqdata", "{eqdata}", "{/eqdata}", false, true, true, true, adbAcmpEqDataReadyCB, false)
end

local wearloc_to_flag_xref = {
    ["0"] = "light",
    ["1"] = "head",
    ["2"] = "eyes",
    ["3"] = "ear",
    ["4"] = "ear",
    ["5"] = "neck",
    ["6"] = "neck",
    ["7"] = "back",
    ["8"] = "medal",
    ["9"] = "medal",
    ["10"] = "medal",
    ["11"] = "medal",
    ["12"] = "torso",
    ["13"] = "body",
    ["14"] = "waist",
    ["15"] = "arms",
    ["16"] = "wrist",
    ["17"] = "wrist",
    ["18"] = "hands",
    ["19"] = "finger",
    ["20"] = "finger",
    ["21"] = "legs",
    ["22"] = "feet",
    ["23"] = "shield",
    ["24"] = "wield",
    ["25"] = "wield",
    ["26"] = "hold",
    ["27"] = "float",
    -- ["28"] = "???",
    -- ["29"] = "???",
    ["30"] = "above",
    ["31"] = "portal",
    ["32"] = "sleeping"
}

function adbAcmpEqDataReadyCB(style_lines)
    adbDebug("adbAcmpEqDataReadyCB", 2)
    local found_worn_item = false
    for _, v in ipairs(style_lines) do
        local line = strip_colours(StylesToColours(v))
        local id, wear_loc
        _, _, id, wear_loc = line:find("^(%d+),.*,.*,.*,.*,.*,(%d+),.*$")
        if id ~= nil and wear_loc ~= nil then
            if wearloc_to_flag_xref[wear_loc] ~= nil and acmp_ctx.obj1.stats.wearable ~= nil and
                acmp_ctx.obj1.stats.wearable:find(wearloc_to_flag_xref[wear_loc]) then
                found_worn_item = true
                adbIdentifyItem("id " .. id .. " worn", adbAcmpItem2IdReadyCB, acmp_ctx)
            end
        end
    end
    if not found_worn_item then
        adbInfo("No items worn as " .. tostring(acmp_ctx.obj1.stats.wearable))
    end
end

function adbCombineIdAndNameString(id, colorName)
    local name = adb_options.cockpit.show_bloot_level and adbAddBlootLevel(colorName) or colorName
    name = "@w[@W" .. tostring(id) .. "@w]:" .. name
    return name
end

function adbGetItemIdAndNameString(obj)
    return adbCombineIdAndNameString(obj.stats.id, obj.colorName)
end

function adbAcmpItem2IdReadyCB(obj, ctx)
    if obj.stats.id == nil then
        if ctx.item2 ~= "" then
            adbInfo(ctx.item2 .. " not found.")
        else
            adbInfo("worn item not found.")
        end
        return
    end

    local base_name = adbGetItemIdAndNameString(obj)
    local item_name = adbGetItemIdAndNameString(ctx.obj1)
    local worn = ctx.item2 == "" and "worn " or ""
    AnsiNote(ColoursToANSI("@CComparing " .. item_name .. " @Cto " .. worn .. base_name))

    local diff = adbDiffItems(obj, ctx.obj1, false)
    local message = adbIdReportAddDiffString("", diff, ctx.format, true)
    AnsiNote(ColoursToANSI(message))
end

------ Identify results reporting ------
function adbGetStatNumberSafe(stat)
    return stat ~= nil and stat or 0
end

function adbGetStatStringSafe(stat)
    return stat ~= nil and stat or ""
end

adb_stat_groups = {
    basics = {
        order = {"str", "int", "wis", "dex", "con", "luck"},
        ["str"] = "str",
        ["int"] = "int",
        ["wis"] = "wis",
        ["dex"] = "dex",
        ["con"] = "con",
        ["luck"] = "luk"
    },
    hrdr = {
        order = {"dam", "hit"},
        ["hit"] = "hr",
        ["dam"] = "dr"
    },
    vitals = {
        order = {"hp", "mana", "moves"},
        ["hp"] = "hp",
        ["mana"] = "mn",
        ["moves"] = "mv"
    },
    resists = {
        order = {"allphys", "allmagic", "slash", "pierce", "bash", "acid", "cold", "energy", "holy", "electric",
                 "negative", "shadow", "magic", "air", "earth", "fire", "light", "mental", "sonic", "water", "poison",
                 "disease"},
        ["allphys"] = "allPh",
        ["allmagic"] = "allMg",
        ["slash"] = "slash",
        ["pierce"] = "pierce",
        ["bash"] = "bash",
        ["acid"] = "acid",
        ["cold"] = "cold",
        ["energy"] = "energy",
        ["holy"] = "holy",
        ["electric"] = "electric",
        ["negative"] = "negative",
        ["shadow"] = "shadow",
        ["magic"] = "magic",
        ["air"] = "air",
        ["earth"] = "earth",
        ["fire"] = "fire",
        ["light"] = "light",
        ["mental"] = "mental",
        ["sonic"] = "sonic",
        ["water"] = "water",
        ["poison"] = "poison",
        ["disease"] = "disease"
    }
}

function adbGetStatsGroupTotal(stats, group)
    local result = 0
    for k, v in pairs(group) do
        result = result + adbGetStatNumberSafe(stats[k])
    end
    return result
end

function adbGetStatsGroupString(stats, group, show_plus)
    local result = ""
    for k, v in ipairs(group.order) do
        local stat = adbGetStatNumberSafe(stats[v])
        if stat ~= 0 then
            result = result .. (result:len() > 0 and " " or "") ..
                         (stat < 0 and adb_options.colors.bad or adb_options.colors.good) ..
                         ((show_plus and stat > 0) and "+" or "") .. tostring(stat) .. adb_options.colors.default ..
                         group[v]
        end
    end
    return result
end

function adbGetSkillModsString(item, show_plus)
    local result = ""
    for k, v in pairs(item.skillMods) do
        result = result .. (result:len() > 0 and ", " or "") .. adb_options.colors.flags .. k .. " " ..
                     (v < 0 and adb_options.colors.bad or adb_options.colors.good) ..
                     ((show_plus and v > 0) and "+" or "") .. tostring(v) .. adb_options.colors.default
    end
    return result
end

function adbGetWeaponString(item, format)
    return
        adb_options.colors.weapon .. tostring(adbGetStatNumberSafe(item.stats.avedam)) .. adb_options.colors.default ..
            "avg " .. adb_options.colors.value .. adbGetStatStringSafe(item.stats.weapontype) .. " " ..
            (format.weapon_material and (adb_options.colors.value .. adbGetStatStringSafe(item.stats.material) .. " ") or
                "") .. adb_options.colors.value .. adbGetStatStringSafe(item.stats.damtype) .. " " ..
            adb_options.colors.value .. adbGetStatStringSafe(item.stats.specials)
end

function adbIdReportAddValue(report, value, label, color, show_plus)
    if value == nil or value == 0 or value == "" then
        return report
    end
    if report:len() > 0 then
        report = report .. " "
    end

    report = report .. adb_options.colors.default .. "[" .. color ..
                 ((show_plus and type(value) == "number" and value > 0) and "+" or "") .. tostring(value) ..
                 adb_options.colors.default .. label .. "]"
    return report
end

function adbShortenRoomsString(rooms)
    local rooms_table = {}
    local result = ""
    for room in rooms:gmatch("[^, ]+") do
        table.insert(rooms_table, tonumber(room))
    end
    table.sort(rooms_table, function(a, b)
        return a < b
    end)

    local start, last
    table.foreach(rooms_table, function(k, v)
        if start then
            if v == (last and last or start) + 1 then
                last = v
            else
                if last then
                    result = result .. (last == start + 1 and ", " or "-") .. tostring(last)
                end
                result = result .. ", " .. tostring(v)
                start = v
                last = nil
            end
        else
            result = result .. tostring(v)
            start = v
        end
    end)
    if last then
        result = result .. (last == start + 1 and ", " or "-") .. tostring(last)
    end

    return result
end

function adbIdReportAddLocationInfo(report, location)
    if location == nil then
        return report
    end

    local header_added = false
    for k, v in pairs(location.mobs) do
        if not header_added then
            report = report .. "\n" .. adb_options.colors.section .. " Looted from:"
            header_added = true
        end

        report =
            report .. "\n" .. adb_options.colors.value .. " " .. v.colorName .. adb_options.colors.default .. " [" ..
                adb_options.colors.value .. v.zone .. adb_options.colors.default .. "] " .. "Room(s) [" ..
                adb_options.colors.value .. adbShortenRoomsString(v.rooms) .. adb_options.colors.default .. "]"
    end

    return report
end

function adbEnchantsPresent(enchants)
    for k, v in pairs(adb_enchants) do
        if enchants[k] ~= nil then
            return true
        end
    end
    return false
end

function adbCanEnchant(item, enchant)
    if enchant == "Solidify" then
        return item.stats.flags:find("invis") and not item.stats.flags:find("solidified")
    elseif enchant == "Illuminate" then
        return not item.stats.flags:find("glow") and not item.stats.flags:find("illuminated")
    elseif enchant == "Resonate" then
        return not item.stats.flags:find("hum") and not item.stats.flags:find("resonated")
    end
    return false
end

function adbGetEnchantsShortString(item)
    local res = ""
    for k, v in ipairs(adb_enchants.order) do
        if item.enchants[v] ~= nil then
            res = res .. adb_options.colors.enchants .. adb_enchants[v]
        elseif adbCanEnchant(item, v) then
            res = res .. adb_options.colors.default .. adb_enchants[v]
        end
    end
    return res
end

function adbIdReportAddEnchantsInfo(report, enchants)
    if enchants == nil or not adbEnchantsPresent(enchants) then
        return report
    end

    report = report .. "\n"
    for k, v in ipairs(adb_enchants.order) do
        if enchants[v] ~= nil then
            report = report .. adb_options.colors.enchants .. " " .. v
            report = adbIdReportAddValue(report, adbGetStatsGroupString(enchants[v], adb_stat_groups.hrdr, true), "",
                adb_options.colors.default)
            report = adbIdReportAddValue(report, adbGetStatsGroupString(enchants[v], adb_stat_groups.basics, true), "",
                adb_options.colors.default)
            report = adbIdReportAddValue(report, enchants[v].removable and "removable" or "TP only", "",
                enchants[v].removable and adb_options.colors.good or adb_options.colors.bad)
        end
    end
    return report
end

function adbGetSpellsString(spells)
    result = nil
    for _, v in ipairs(spells) do
        result = result ~= nil and (result .. ", ") or ""
        result = result .. adb_options.colors.value .. v.count .. adb_options.colors.default .. " x " ..
                     adb_options.colors.value .. v.name
        result = adbIdReportAddValue(result, v.level, " lvl", adb_options.colors.level)
    end
    return result
end

function adbIdReportAddDiffString(report, diff, format, no_prefix_lines)
    if not no_prefix_lines then
        report = report .. "\n" .. adb_options.colors.section .. " Bloot changes:"
        if format.sections_name_newline then
            report = report .. "\n"
        end
    end

    if (diff.stats.level ~= nil) then
        report = adbIdReportAddValue(report, adbGetStatNumberSafe(diff.stats.level), " lvl", adb_options.colors.level,
            true)
    end

    if (diff.stats.avedam ~= nil) then
        report = adbIdReportAddValue(report, adbGetStatNumberSafe(diff.stats.avedam), "avg", adb_options.colors.weapon,
            true)
    end

    if format.score then
        report = adbIdReportAddValue(report, diff.stats.score, "score", adb_options.colors.score, true)
    end
    report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.hrdr, true), "",
        adb_options.colors.default)
    if format.stats_total then
        report = adbIdReportAddValue(report, adbGetStatsGroupTotal(diff.stats, adb_stat_groups.basics), "stats",
            adb_options.colors.score, true)
    end
    if format.stats then
        report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.basics, true), "",
            adb_options.colors.default)
    end
    if format.vitals then
        report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.vitals, true), "",
            adb_options.colors.default)
    end
    if format.resists then
        report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.resists, true), "",
            adb_options.colors.default)
    end

    if format.weight then
        report = adbIdReportAddValue(report, diff.stats.weight, "wgt", adb_options.colors.value, true)
    end
    if format.worth then
        report = adbIdReportAddValue(report, diff.stats.worth, "g", adb_options.colors.value, true)
    end

    return report
end

function adbIdReportGetItemString(item, format)
    local res = ""

    if format.dbid and item.cache ~= nil then
        res = adbIdReportAddValue(res, adbGetStatNumberSafe(item.cache.rowid), "db", adb_options.colors.value)
    end
    if format.id then
        res = adbIdReportAddValue(res, adbGetStatNumberSafe(item.stats.id), "", adb_options.colors.value)
    end
    if res ~= "" then
        res = res .. " "
    end

    res = res .. (adb_options.cockpit.show_bloot_level and adbAddBlootLevel(item.colorName) or item.colorName)
    if format.level then
        res = adbIdReportAddValue(res, item.stats.level, " lvl", adb_options.colors.level)
    end
    if format.type then
        res = adbIdReportAddValue(res, item.stats.type, "", adb_options.colors.value)
    end
    if format.wearable then
        res = adbIdReportAddValue(res, item.stats.wearable, "", adb_options.colors.value)
    end

    if (item.stats.type == "Weapon") then
        res = adbIdReportAddValue(res, adbGetWeaponString(item, format), "", adb_options.colors.value)
    end

    if format.score then
        res = adbIdReportAddValue(res, item.stats.score, "score", adb_options.colors.score)
    end
    res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.hrdr), "",
        adb_options.colors.default)
    if format.stats_total then
        res = adbIdReportAddValue(res, adbGetStatsGroupTotal(item.stats, adb_stat_groups.basics), "stats",
            adb_options.colors.score)
    end
    if format.stats then
        res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.basics), "",
            adb_options.colors.default)
    end
    if format.vitals then
        res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.vitals), "",
            adb_options.colors.default)
    end
    if format.resists then
        res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.resists), "",
            adb_options.colors.default)
    end
    if format.skill_mods then
        res = adbIdReportAddValue(res, adbGetSkillModsString(item, true), "", adb_options.colors.default)
    end

    if format.weight then
        res = adbIdReportAddValue(res, item.stats.weight, "wgt", adb_options.colors.value)
    end
    if format.worth then
        res = adbIdReportAddValue(res, item.stats.worth, "g", adb_options.colors.value)
    end
    if format.enchants_sir then
        res = adbIdReportAddValue(res, adbGetEnchantsShortString(item), "", adb_options.colors.enchants)
    end

    if format.spells and item.stats.spells then
        res = adbIdReportAddValue(res, adbGetSpellsString(item.stats.spells), "", adb_options.colors.value)
    end

    if format.flags or format.foundat then
        res = res .. "\n"
        if format.flags then
            res = adbIdReportAddValue(res, item.stats.flags, "", adb_options.colors.value)
        end
        if format.foundat then
            res = adbIdReportAddValue(res, item.stats.foundat, "", adb_options.colors.value)
        end
    end

    if adbEnchantsPresent(item.enchants) then
        if format.enchants_total or format.enchants_details then
            res = res .. "\n"
            if format.enchants_total then
                res = adbIdReportAddValue(res, adbGetEnchantsShortString(item), "", adb_options.colors.enchants)
                res = adbIdReportAddValue(res, adbGetStatsGroupString(item.enchants, adb_stat_groups.hrdr, true), "",
                    adb_options.colors.default)
                if format.stats_total then
                    res = adbIdReportAddValue(res, adbGetStatsGroupTotal(item.enchants, adb_stat_groups.basics, true),
                        "stats", adb_options.colors.score)
                end
                if format.stats then
                    res = adbIdReportAddValue(res, adbGetStatsGroupString(item.enchants, adb_stat_groups.basics, true),
                        "", adb_options.colors.default)
                end
            end
            if format.enchants_details then
                res = adbIdReportAddEnchantsInfo(res, item.enchants)
            end
        end
    end

    if format.keywords then
        res = res .. adb_options.colors.section .. "\n Keywords:"
        res = adbIdReportAddValue(res, item.stats.keywords, "", adb_options.colors.value)
    end

    if format.location then
        res = adbIdReportAddLocationInfo(res, item.location)
    end

    if format.comments and item.comment then
        res = res .. adb_options.colors.section .. "\n Comments:"
        res = adbIdReportAddValue(res, item.comment, "", adb_options.colors.value)
    end

    res = res .. "@w"
    return res
end

------ Bloot ------
local adb_bloot_names = {
    Polished = 1,
    Enhanced = 2,
    Burnished = 3,
    Shiny = 4,
    Vibrant = 5,
    Sparkling = 6,
    Gleaming = 7,
    Shimmering = 8,
    Dazzling = 9,
    Brilliant = 10,
    Radiant = 11,
    Wondrous = 12,
    Majestic = 13,
    Exalted = 14,
    Eternal = 15,
    Legendary = 16,
    Epic = 17,
    Fabled = 18,
    Mythical = 19,
    Divine = 20,
    Godly = 21
}

function adbStripEnchants(item)
    if item.enchants == nil then
        return
    end

    for k, v in pairs(adb_enchant_stats) do
        if item.enchants[v] ~= nil then
            item.stats[v] = adbGetStatNumberSafe(item.stats[v1]) - item.enchants[v]
        end
    end

    item.enchants = {}
end

local adb_diff_fields = {"score", "weight", "worth", "avedam", "level"}
function adbDiffItems(item1, item2, ignore_enchants)
    local result = {
        stats = {}
    }

    for k, v in pairs(adb_diff_fields) do
        result.stats[v] = adbGetStatNumberSafe(item2.stats[v]) - adbGetStatNumberSafe(item1.stats[v])
    end

    for k, v in pairs(adb_stat_groups) do
        for k1, v1 in ipairs(v.order) do
            result.stats[v1] = adbGetStatNumberSafe(item2.stats[v1]) - adbGetStatNumberSafe(item1.stats[v1])
            if ignore_enchants then
                if item1.enchants ~= nil then
                    result.stats[v1] = result.stats[v1] + adbGetStatNumberSafe(item1.enchants[v1])
                end
                if item2.enchants ~= nil then
                    result.stats[v1] = result.stats[v1] - adbGetStatNumberSafe(item2.enchants[v1])
                end
            end
        end
    end

    -- TODO diff flags, material, weapon specific etc ?

    return result
end

function adbGetBlootLevel(name)
    -- assuming bloot name is always first word
    -- never seen Godly items :) not sure if they're in fact ((Godly)) or just (Godly)
    match = name:match("^%((%a+)%)")
    if match ~= nil and adb_bloot_names[match] ~= nil then
        return adb_bloot_names[match]
    end

    return 0
end

-- returns colored item name with stripped out bloot tag
function adbGetBaseColorName(color_name)
    -- never seen Godly items :) not sure if they're in fact ((Godly)) or just (Godly)
    return color_name:gsub("^@[%a%d]+%(@%a%a+@%a%)@[%a%d]+ ", "")
end

function adbAddBlootLevel(color_name)
    local bloot
    _, _, bloot = color_name:find("%(@%a(%a+)@%a%)")
    if bloot == nil or adb_bloot_names[bloot] == nil then
        return color_name
    end
    local bloot_lvl = adb_bloot_names[bloot]
    local bloot_replace = ""
    if bloot_lvl < 9 then
        bloot_replace = bloot .. " " .. tostring(bloot_lvl)
    elseif bloot_lvl < 16 then
        bloot_replace = bloot .. " <" .. tostring(bloot_lvl) .. ">"
    else
        bloot_replace = bloot .. " <<" .. tostring(bloot_lvl) .. ">>"
    end
    return color_name:gsub("%((@%a)" .. bloot, "%(%1" .. bloot_replace, 1)
end

function adbOnBlootNameTrigger(name, line, wildcards, styles)
    local bloot_lvl = adb_bloot_names[wildcards.bloot]
    local bloot = wildcards.bloot
    if bloot_lvl < 9 then
        bloot = bloot .. " " .. tostring(bloot_lvl)
    elseif bloot_lvl < 16 then
        bloot = bloot .. " <" .. tostring(bloot_lvl) .. ">"
    else
        bloot = bloot .. " <<" .. tostring(bloot_lvl) .. ">>"
    end
    local colored_line = StylesToColours(styles)
    local changed_line = colored_line:gsub("%((@[%a%d]+)" .. wildcards.bloot, "%(%1" .. bloot, 1)
    -- While dinv is doing refresh this triggers without proper styles,
    -- just ignore this line as dinv intention is to hide it anyways.
    if colored_line ~= changed_line then
        AnsiNote(ColoursToANSI(changed_line))
    end
end

------ DB ------
adb_db_filename = "adb.db"
adb_db_version = 3
adb_db = nil

local adb_db_special_fields = {
    dbid = true,
    colorName = true,
    zone = true,
    comment = true,
    identifyLevel = true,
    identifyVersion = true,
    skillMods = true,
    shop = true
}
function adbDbMakeItemFromRow(row)
    adbDebug("adbDbMakeItemFromRow " .. row.dbid, 2)
    adbDebugTprint(row, 3)

    local result = {
        stats = {},
        cache = {
            rowid = row.dbid,
            new = false,
            dirty = false,
            timestamp = os.time()
        },
        location = {
            zone = row.zone,
            mobs = {},
            shop = row.shop
        },
        enchants = {},
        skillMods = {},
        colorName = row.colorName,
        comment = row.comment,
        identifyLevel = row.identifyLevel,
        identifyVersion = row.identifyVersion
    }

    for k, v in pairs(row) do
        if not adb_db_special_fields[k] and not k:find("^spells%d") then
            result.stats[k:lower()] = v
        end
    end

    if row["spells1name"] then
        result.stats.spells = {}
    end
    for i = 1, 5, 1 do
        if row["spells" .. i .. "name"] then
            local spell = {
                level = row["spells" .. i .. "level"],
                count = row["spells" .. i .. "count"],
                name = row["spells" .. i .. "name"]
            }
            table.insert(result.stats.spells, spell)
        end
    end

    if row.skillMods then
        for s in row.skillMods:gmatch("[^,]+") do
            local skill, value
            _, _, skill, value = s:find("^(.*) (-?%d+)$")
            result.skillMods[skill] = tonumber(value)
        end
    end

    local sql = string.format([[
    SELECT mobs.* from item_mobs
    INNER JOIN mobs on mobs.dbid = item_mobs.mob_dbid
    WHERE item_dbid = %d;
  ]], row.dbid)

    for mob_row in adbDbNrowsExec(sql) do
        local mob = {
            name = mob_row.name,
            colorName = mob_row.colorName,
            rooms = mob_row.rooms,
            zone = mob_row.zone,
            rowid = mob_row.dbid
        }
        adbItemLocationAddMob(result, mob)
    end

    adbDebug("Resulting item:", 3)
    adbDebugTprint(result, 3)
    return result
end

function adbDbGetItem(color_name, zone)
    assert(color_name ~= nil and zone ~= nil)
    adbDebug("adbDbGetItem [" .. color_name .. "] [" .. zone .. "]", 2)

    local result = nil
    local sql = string.format("SELECT * FROM items WHERE zone = %s AND colorName = %s;", adbSqlTextValue(zone),
        adbSqlTextValue(color_name))
    for row in adbDbNrowsExec(sql) do
        if result ~= nil then
            adbDebug("Got more than one row!", 1)
            adbDebugTprint(row, 1)
        end
        result = adbDbMakeItemFromRow(row)
    end
    return result
end

function adbDbGetItemByNameAndFoundAt(color_name, found_at)
    assert(color_name ~= nil and found_at ~= nil)
    adbDebug("adbDbGetItemByNameAndFoundAt [" .. color_name .. "] [" .. found_at .. "]", 2)

    local result = nil
    local sql = string.format("SELECT * FROM items WHERE foundAt = %s AND colorName = %s;", adbSqlTextValue(found_at),
        adbSqlTextValue(color_name))
    for row in adbDbNrowsExec(sql) do
        if result ~= nil then
            adbDebug("Got more than one row!", 1)
            adbDebugTprint(row, 1)
            break
        end
        result = adbDbMakeItemFromRow(row)
    end
    return result
end

function adbDbGetItemsByName(color_name)
    assert(color_name ~= nil)
    adbDebug("adbDbGetItemsByName [" .. color_name .. "]", 2)
    local sql = string.format("SELECT * FROM items WHERE colorName = %s;", adbSqlTextValue(color_name))
    local result = {}
    for row in adbDbNrowsExec(sql) do
        table.insert(result, adbDbMakeItemFromRow(row))
    end
    return result
end

function trim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

-- DB exec functions are borrowed from aard_GMCP_mapper.xml
function adbDbCheck(code, msg, query)
    if code ~= sqlite3.OK and -- no error
    code ~= sqlite3.ROW and -- completed OK with another row of data
    code ~= sqlite3.DONE then -- completed OK, no more rows
        local err = msg .. "\n\nCODE: " .. code .. "\nQUERY: " .. query .. "\n"
        adb_db:exec("ROLLBACK") -- rollback any transaction to unlock the database
        error(err, 3) -- show error in caller's context
    end -- if
end -- dbcheck

adb_db_max_retries = 10
adb_db_sleep_duration = 1
function adbDbCheckExecute(query)
    local code = adb_db:exec(query)
    local count = 0
    while ((code == sqlite3.BUSY) or (code == sqlite3.LOCKED)) and (count < adb_db_max_retries) do
        adbInfo(string.format("DB ERROR: %s. Retrying %d times: `%s`", adb_db:errmsg():upper(), adb_db_max_retries,
            query))
        adb_db:exec("ROLLBACK")
        local socket = require "socket"
        socket.sleep(adb_db_sleep_duration)
        code = adb_db:exec(query)
        count = count + 1
    end

    if (not adbDbCheck(code, adb_db:errmsg(), query)) and (count > 0) then
        adbInfo("Succeded after retry: " .. query)
    end
end

function adbDbNrowsExec(query)
    local ok, iter, vm, i = pcall(adb_db.nrows, adb_db, query)

    local count = 0
    while (not ok) and (count < adb_db_max_retries) do
        local code = adb_db:errcode()
        adbInfo(string.format("DB ERROR: %s. Retrying %d times: `%s`", adb_db:errmsg():upper(), adb_db_max_retries,
            query))
        if (code ~= sqlite3.BUSY) and (code ~= sqlite3.LOCKED) then
            break
        end
        adb_db:exec("ROLLBACK")
        local socket = require "socket"
        socket.sleep(adb_db_sleep_duration)
        ok, iter, vm, i = pcall(adb_db.nrows, adb_db, query)
        count = count + 1
    end

    if (not adbDbCheck(adb_db:errcode(), adb_db:errmsg(), query)) and (count > 0) then
        adbInfo("Succeded after retry: " .. query)
    end

    local function itwrap(vm, i)
        retval = iter(vm, i)
        if not retval then
            return nil
        end
        return retval
    end
    return itwrap, vm, i
end

function adbSqlTextValue(value)
    local res = value:gsub("'", "''")
    return "'" .. res .. "'"
end

function adbDbAddItem(item)
    adbDebug("adbDbAddItem [" .. item.colorName .. "] [" .. item.location.zone .. "] [" .. item.stats.foundat .. "]", 2)

    -- It's possible that some items from different zones were given to mobs in another zone and we incorrectly
    -- assigned item's zone field. Search for such items in db and erase.
    local dbitem = adbDbGetItemByNameAndFoundAt(item.colorName, item.stats.foundat)
    if dbitem ~= nil then
        adbDebug("Erasing erroneous item from DB " .. dbitem.cache.rowid, 0)
        adbDbCheckExecute("DELETE FROM items WHERE dbid = " .. dbitem.cache.rowid .. ";")
    end

    local sql = [[
    BEGIN TRANSACTION;
    INSERT INTO items (identifyVersion, zone, colorName
  ]]
    if item.comment then
        sql = sql .. ", comment"
    end
    if item.identifyLevel then
        sql = sql .. ", identifyLevel"
    end
    if item.location.shop then
        sql = sql .. ", shop"
    end

    for k, v in pairs(item.stats) do
        if type(v) ~= "table" then
            sql = sql .. ", " .. k
        end
    end
    if item.stats.spells then
        -- 5 spells only ... too lazy to add another table
        if #item.stats.spells > 5 then
            adbErr("adbDbAddItem #item.stats.spells = " .. #item.stats.spells)
        end
        for i = 1, 5, 1 do
            if item.stats.spells[i] then
                sql = sql .. ", spells" .. i .. "level"
                sql = sql .. ", spells" .. i .. "count"
                sql = sql .. ", spells" .. i .. "name"
            end
        end
    end

    for _, _ in pairs(item.skillMods) do
        sql = sql .. ", skillMods"
        break
    end

    sql = sql .. [[
    ) VALUES (
  ]]
    sql = sql .. item.identifyVersion .. ", "
    sql = sql .. adbSqlTextValue(item.location.zone) .. ", "
    sql = sql .. adbSqlTextValue(item.colorName)
    if item.comment then
        sql = sql .. ", " .. adbSqlTextValue(item.comment)
    end
    if item.identifyLevel then
        sql = sql .. ", " .. adbSqlTextValue(item.identifyLevel)
    end
    if item.location.shop then
        sql = sql .. ", " .. tostring(item.location.shop)
    end

    for k, v in pairs(item.stats) do
        if type(v) ~= "table" then
            sql = sql .. ",\r\n" .. (type(v) == "string" and adbSqlTextValue(v) or tostring(v))
        elseif k == "spells" then
            -- intentionally left empty
        else
            adbErr("Unexpected table in item stats: " .. k)
        end
    end
    if item.stats.spells then
        for i = 1, 5, 1 do
            if item.stats.spells[i] then
                sql = sql .. ",\r\n" .. item.stats.spells[i].level
                sql = sql .. ",\r\n" .. item.stats.spells[i].count
                sql = sql .. ",\r\n" .. adbSqlTextValue(item.stats.spells[i].name)
            end
        end
    end

    local mods = nil
    for k, v in pairs(item.skillMods) do
        mods = (mods ~= nil and (mods .. ",") or "") .. k .. " " .. tostring(v)
    end
    if mods ~= nil then
        sql = sql .. ",\r\n" .. adbSqlTextValue(mods)
    end

    sql = sql .. ");"

    adbDbCheckExecute(sql)
    item.cache.rowid = adb_db:last_insert_rowid()

    if item.location.mobs ~= nil then
        for k, v in pairs(item.location.mobs) do
            sql = string.format("INSERT INTO mobs (colorName, name, zone, rooms) VALUES(%s, %s, %s, %s);",
                adbSqlTextValue(v.colorName), adbSqlTextValue(v.name), adbSqlTextValue(v.zone), adbSqlTextValue(v.rooms))
            adbDbCheckExecute(sql)
            v.rowid = adb_db:last_insert_rowid()

            sql = string.format("INSERT INTO item_mobs (item_dbid, mob_dbid) VALUES (%d, %d);", item.cache.rowid,
                v.rowid)
            adbDbCheckExecute(sql)
        end
    end

    adbDbCheckExecute("COMMIT;")

    item.cache.new = false
    item.cache.dirty = false
end

function adbDbUpdateItem(item)
    -- Easiest way is to just delete and add item again
    -- maybe one day it would be worth to try doing real update,
    -- but it's complicated with potentially removed mobs etc.
    adbDebug(
        "adbDbUpdateItem [" .. item.cache.rowid .. "] [" .. item.colorName .. "] [" .. item.location.zone .. "] [" ..
            item.stats.foundat .. "]", 2)

    adbDbCheckExecute("DELETE FROM items WHERE dbid = " .. item.cache.rowid .. ";")

    -- for row in adbDbNrowsExec("SELECT changes() AS mod;") do
    --   if row.mod ~= 1 then
    --     adbErr("Something is off, updating item [" .. item.colorName .. "] failed to delete existing item from db " .. tostring(item.cache.rowid))
    --   end
    -- end

    adbDbAddItem(item)
end

function adbDbSyncCache()
    adbInfo("Syncing " .. adb_recent_cache.meta.count .. " cache items with db.")
    local add_count = 0
    local update_count = 0
    for k, v in pairs(adb_recent_cache) do
        if k ~= "meta" then
            if v.cache.new then
                add_count = add_count + 1
                adbDbAddItem(v)
            elseif v.cache.dirty then
                update_count = update_count + 1
                adbDbUpdateItem(v)
            end
            assert(not (v.cache.new or v.cache.dirty))
        end
    end
    adbInfo("Sync finished. Added " .. add_count .. " and updated " .. update_count .. " items.")
end

local adb_inv_stats_text_fields = {
    name = true,
    wearable = true,
    keywords = true,
    type = true,
    flags = true,
    affectMods = true,
    material = true,
    foundAt = true,
    ownedBy = true,
    clan = true,
    spells = true,
    leadsTo = true,
    inflicts = true,
    damType = true,
    weaponType = true,
    specials = true,
    location = true
}

function adbDbUpdateVersion(version)
    adbInfo("Updating DB from version " .. version)
    if version == 0 then
        local sql = [[
      PRAGMA foreign_keys = ON;

      CREATE TABLE IF NOT EXISTS zones (
        dbid     INTEGER PRIMARY KEY AUTOINCREMENT,
        name     TEXT NOT NULL,
        UNIQUE(name)
      );
      CREATE UNIQUE INDEX IF NOT EXISTS zones_name_index ON zones(name);

      CREATE TABLE IF NOT EXISTS items (
        dbid           INTEGER PRIMARY KEY AUTOINCREMENT,
        colorName      TEXT NOT NULL,
        zone           TEXT,
        comment        TEXT,
        identifyLevel  TEXT,
    ]]

        for k, v in pairs(inv.stats) do
            sql = sql .. "\r\n" .. v.name .. (adb_inv_stats_text_fields[k] and " TEXT," or " INTEGER,")
        end

        -- 4 spells only ... too lazy to add another table
        for i = 1, 4, 1 do
            sql = sql .. "\r\n spells" .. i .. "level INTEGER,"
            sql = sql .. "\r\n spells" .. i .. "count INTEGER,"
            sql = sql .. "\r\n spells" .. i .. "name TEXT,"
        end

        sql = sql .. [[

        FOREIGN KEY(zone) REFERENCES zones (name)
      );
      CREATE INDEX IF NOT EXISTS items_colorName_index ON items (colorName);
      CREATE UNIQUE INDEX IF NOT EXISTS items_zone_colorName_index ON items (zone, colorName);
      CREATE UNIQUE INDEX IF NOT EXISTS items_foundAt_colorName_index ON items (foundAt, colorName);

      CREATE TRIGGER IF NOT EXISTS items_insert_zone_name_trigger
        BEFORE INSERT ON items
        WHEN NOT EXISTS(select 1 from zones where name = NEW.zone)
      BEGIN
        INSERT INTO zones (name) VALUES (NEW.zone);
      END;

      CREATE TRIGGER IF NOT EXISTS items_update_zone_name_trigger
        BEFORE UPDATE ON items
        WHEN NOT EXISTS(select 1 from zones where name = NEW.zone)
      BEGIN
        INSERT INTO zones (name) VALUES (NEW.zone);
      END;

      CREATE TABLE IF NOT EXISTS mobs (
        dbid        INTEGER PRIMARY KEY AUTOINCREMENT,
        colorName   TEXT NOT NULL,
        name        TEXT NOT NULL,
        zone        TEXT NOT NULL,
        rooms       TEXT NOT NULL,
        FOREIGN KEY(zone) REFERENCES zones (name)
      );

      CREATE TRIGGER IF NOT EXISTS mobs_insert_zone_name_trigger
        BEFORE INSERT ON mobs
        WHEN NOT EXISTS(select 1 from zones where name = NEW.zone)
      BEGIN
        INSERT INTO zones (name) VALUES (NEW.zone);
      END;

      CREATE TRIGGER IF NOT EXISTS mobs_update_zone_name_trigger
        BEFORE UPDATE ON mobs
        WHEN NOT EXISTS(select 1 from zones where name = NEW.zone)
      BEGIN
        INSERT INTO zones (name) VALUES (NEW.zone);
      END;

      CREATE TABLE IF NOT EXISTS item_mobs (
        item_dbid      INTEGER,
        mob_dbid       INTEGER,
        PRIMARY KEY (item_dbid, mob_dbid),
        FOREIGN KEY (item_dbid) REFERENCES items (dbid)
          ON DELETE CASCADE ON UPDATE NO ACTION,
        FOREIGN KEY (mob_dbid) REFERENCES mobs (dbid)
          ON DELETE CASCADE ON UPDATE NO ACTION
      );

      CREATE TRIGGER IF NOT EXISTS item_mobs_delete_trigger
      AFTER DELETE ON item_mobs
      BEGIN
        DELETE FROM mobs WHERE dbid = OLD.mob_dbid;
      END;

      PRAGMA user_version = 1;
    ]]
        adbDbCheckExecute(sql)
        version = 1
        adbInfo("Updated DB to version " .. version)
    end

    if version == 1 then
        local sql = [[
      PRAGMA foreign_keys = ON;
      BEGIN TRANSACTION;

      ALTER TABLE items ADD spells5level     INTEGER;
      ALTER TABLE items ADD spells5count     INTEGER;
      ALTER TABLE items ADD spells5name      TEXT;

      ALTER TABLE items ADD skillMods        TEXT;

      ALTER TABLE items ADD identifyVersion  INTEGER NOT NULL DEFAULT 1;

      COMMIT;

      PRAGMA user_version = 2;
    ]]
        adbDbCheckExecute(sql)
        version = 2
        adbInfo("Updated DB to version " .. version)
    end

    if version == 2 then
        local sql = [[
      PRAGMA foreign_keys = ON;
      BEGIN TRANSACTION;

      ALTER TABLE items ADD shop     INTEGER;

      UPDATE items
        SET shop = 1
      WHERE EXISTS (
        SELECT items1.dbid FROM items items1
        LEFT JOIN item_mobs on items1.dbid = item_mobs.item_dbid
        LEFT JOIN mobs on mobs.dbid = item_mobs.mob_dbid
        WHERE mobs.colorName == '@Yshopkeeper' and items.dbid = items1.dbid
      );

      COMMIT;

      PRAGMA user_version = 3;
    ]]
        adbDbCheckExecute(sql)
        version = 3
        adbInfo("Updated DB to version " .. version)
    end

    assert(version == adb_db_version)
end

function adbDbOpen()
    adbDebug("adbDbOpen", 1)
    local filename = GetPluginInfo(GetPluginID(), 20) .. adb_db_filename
    adb_db = assert(sqlite3.open(filename))
    adb_db:busy_timeout(100)
    adbInfo("Opened " .. filename)
end

function adbDbLoad()
    adbDebug("adbDbLoad", 1)
    if adb_db ~= nil and adb_db:isopen() then
        return
    end

    adbDbOpen()

    adbDbCheckExecute("PRAGMA journal_mode=WAL;")
    local db_user_version = 0
    for row in adbDbNrowsExec("PRAGMA user_version") do
        db_user_version = row.user_version
    end

    adbInfo("Opened DB version " .. db_user_version)

    if db_user_version ~= adb_db_version then
        adbDbUpdateVersion(db_user_version)
    end
end

function adbDbSave()
    local opened = adb_db:isopen()
    if not opened then
        adbDbOpen()
    end

    adbDebug("adbDbSave", 1)
    adbDbCheckExecute("PRAGMA wal_checkpoint(FULL);")

    adbDbSyncCache()

    if adb_db:isopen() then
        adb_db:close()
        if opened then
            adbDbOpen()
        end
    end
end

function adbDbClose()
    adbDebug("adbDbClose", 1)
    adbDbCheckExecute("PRAGMA optimize;")
    if adb_db:isopen() then
        adb_db:close()
    end
end

function adbOnAdbInfo()
    adbDbSave()

    local id = GetPluginID()
    Note("")
    adbInfo("Running ADB version: " .. tostring(GetPluginInfo(id, 19)))
    Note("Installed as: " .. GetPluginInfo(id, 6))
    Note("Identify module version: " .. adb_id_version)
    Note("Cache version: " .. adb_recent_cache.meta.version .. " contains " .. adb_recent_cache.meta.count .. " item(s)")
    Note("Loaded DB " .. GetPluginInfo(id, 20) .. adb_db_filename)
    local result = 0
    for row in adbDbNrowsExec("SELECT count(*) as count FROM items;") do
        result = row.count
    end
    Note("DB Version: " .. adb_db_version .. " contains " .. result .. " items(s)")
    for row in adbDbNrowsExec("SELECT count(*) as count FROM items WHERE identifyVersion<>" .. adb_id_version .. ";") do
        result = row.count
    end
    if (result > 0) then
        Note("  " .. result .. " item(s) scheduled to update identify version")
    end
    Note("")
end

function adbOnAdbFind(name, line, wildcards)
    adbDbSave()

    adbInfo(line)
    if wildcards.format ~= "" and adb_options[wildcards.format] == nil then
        adbInfo("Unknown format " .. wildcards.format .. " using default")
    end
    local format = adb_options[wildcards.format] or adb_options[adb_options.cockpit.db_find_format]

    local sql = "SELECT * FROM items WHERE " .. wildcards.query .. ";"
    vm, err = adb_db:prepare(sql)
    if (not vm) then
        Note(string.format("QUERY ERROR -> %s.", adb_db:errmsg():upper()))
        return
    end

    -- TODO: reuse compiled statement instead of adbDbNrowsExec(sql)
    local count = 0
    for row in adbDbNrowsExec(sql) do
        local item = adbDbMakeItemFromRow(row)
        local message = adbIdReportGetItemString(item, format)
        count = count + 1
        AnsiNote(count .. ". " .. ColoursToANSI(message))
    end
    adbInfo("Found " .. count .. " items.")
end
------ Debug ------
adb_debug_level = 0

function adbOnDebugLevel(name, line, wildcards)
    adb_debug_level = tonumber(wildcards.level)
end

function adbDebug(what, level)
    if level ~= nil and level > adb_debug_level then
        return
    end

    if type(what) == "string" then
        Note("ADB Debug: " .. what)
    elseif type(what) == "function" then
        Note("ADB Debug:")
        what()
    end
end

function adbDebugTprint(t, level)
    if level == nil or level <= adb_debug_level then
        if t == nil then
            print("Table is nil")
        else
            tprint(t)
        end
    end
end

function adbErr(message)
    ColourNote("white", "red", "ADB ERROR: " .. message)
    ColourNote("white", "red", "Please report this to Athlau with a couple pages of screen output before this message.")
end

function adbInfo(message)
    ColourNote("blue", "white", "ADB: " .. message)
end
------ Plugin Callbacks ------
was_in_combat = false
function OnPluginBroadcast(msg, id, name, text)
    if (id == '3e7dedbe37e44942dd46d264') then
        if (text == "char.status") then
            -- 3 - Player fully active and able to receive MUD commands
            -- 8 - Player in combat
            local state = gmcp("char.status.state")
            if state == "8" then
                if not was_in_combat then
                    adbDebug("-> in combat", 4)
                end
                was_in_combat = true
            elseif state == "3" and was_in_combat then
                adbDebug("-> out of combat", 4)
                was_in_combat = false
                adbDrainStacks()
            end
        elseif text == "room.info" then
            local off = adb_state.auto_adb_off_for_zones[gmcp("room.info.zone")] or false
            if off ~= adb_state.adb_off_for_current_zone then
                adb_state.adb_off_for_current_zone = off
                if off then
                    adbInfo("Aucto actions are OFF: Entered ignored area " .. gmcp("room.info.zone"))
                else
                    adbInfo("Aucto actions are " .. (adb_options.cockpit.enable_auto_actions and "ON" or "OFF") ..
                                ": Left ignored area")
                end
            end
        end
    end
end

local adb_help = {
    ["commands"] = [[
@R-----------------------------------------------------------------------------------------------
@Waid@w           - identify an item, see @Gadb help aid@w for more info.
@Wacmp@w          - compare items, see @Gadb help acmp@w for more info.
@Wadb options@w   - various adb options, see @Gadb help options@w for more details.
@Wadb format@w    - display format settings, see @Gadb help format@w for more details.
@Wadb info@w      - show adb plugin information.
@Wadb find@w      - search the item database, see @Gadb help find@w for more details.
@Waide@w          - command to search/manage items based on their enchants,
                see @Gadb help aide@w for more details.
@Waench@w         - command to enchant or batch enchant items.
                see @Gadb help aench@w for more details.

@Wadb [on|off]@w  - disable or enable auto actions.
                It's the same as typing longer command:
                @Wadb options set cockpit enable_auto_actions [false|true]@w

@Wadb shop@w      - add shop's inventory to database, see @Gadb help shop@w for more details.
@R-----------------------------------------------------------------------------------------------
  ]],
    ["aid"] = [[
@R-----------------------------------------------------------------------------------------------
@Waid <item> [worn] [channel] [format.name]@w
 This command will identify given <item> and report output locally or to a
 specified channel.
 Examples:
 @Waid 2685807183@w  - will identify item and output results locally using
                   format specified in @Gidentify_format@w
 @Waid something format.full@w  - will identify item and output results locally
                              using format.full settings
 @Waid sword gtell@w - will identify item and output result to group channel
                   using format specified in identify_channel_format
 @Waid sword worn t Sletch spam incoming: format.full@w - spam Sletch with full details :P
@R-----------------------------------------------------------------------------------------------
  ]],
    ["acmp"] = [[
@R-----------------------------------------------------------------------------------------------
@Wacmp <item1> [item2] [format.name]@w
 This command will compare given <item1> to an @Gitem2@w or an item(s)

Examples:
@Wacmp dag card@w  - compare "dag" and "card" using format specified in @Gidentify_format@w
 @CComparing @w[@W2777147290@w:@YDagger of @RAardwolf@w] @Cto @w[@W2723916584@w:@G(@WSparkling 6@G)@w a @Rc@ra@Rr@rd @wsword]
 @D[@C+98@D lvl] [@M+312@Davg] [@Y+1218@Dscore] [@G+5@Ddr @G+9@Dhr] [@Y-10@Dstats] [@R-7@Dint @R-1@Ddex @R-2@Dluk] [@R-40@Dhp @R-20@Dmn] [@R-10@Delectric] [@W-15@Dwgt] [@W-5000@Dg]

@Wacmp card@w  - compare item "card" to worn items using format specified in @Gidentify_format@w
 @CComparing @w[@W2723916584@w:@G(@WSparkling 6@G)@w a @Rc@ra@Rr@rd @wsword] @Cto worn @w[@W2777147290@w:@YDagger of @RAardwolf@w]
 @D[@C-98@D lvl] [@M-312@Davg] [@Y-1218@Dscore] [@R-5@Ddr @R-9@Dhr] [@Y+10@Dstats] [@G+7@Dint @G+1@Ddex @G+2@Dluk] [@G+40@Dhp @G+20@Dmn] [@G+10@Delectric] [@W+15@Dwgt] [@W+5000@Dg]
 @w
 @CComparing @w[@W2723916584@w:@G(@WSparkling 6@G)@w a @Rc@ra@Rr@rd @wsword] @Cto worn @w[@W2777147295@w:@YDagger of @RAardwolf@w]
 @D[@C-98@D lvl] [@M-312@Davg] [@Y-1218@Dscore] [@R-5@Ddr @R-9@Dhr] [@Y+10@Dstats] [@G+7@Dint @G+1@Ddex @G+2@Dluk] [@G+40@Dhp @G+20@Dmn] [@G+10@Delectric] [@W+20@Dwgt] [@W+5000@Dg]
@R-----------------------------------------------------------------------------------------------
      ]],
    ["options"] = [[
@R-----------------------------------------------------------------------------------------------
@Wadb options [edit|reset|set <group> <option> [value] ]@w
 This command shows or changes ADB options.
 Examples:
 @Wadb options@w - show current options
 @Wadb options edit@w - edit options
 @Wadb options reset@w - reset options to defaults.
 @Wadb options set format.full flags false@w - don't show flags in format.full
 @Wadb options set cockpit show_db_updates false@w - don't show DB update messages
 @Wadb options set auto_actions on_normal_looted_cmd put %item bag@w -
   Executes "put %item bag" command for all non-bloot items looted from corpses.
   @W%item@w will be replaced with looted item id.
         Default options are explicitly conflicting, lua script will drop low cost
         items and then "_cmd" will try to put this dropped item in *my* bag.
         You can either modify the lua part to drop item in "else" clause or just
         clear it if you don't care.
 @Wadb options set auto_actions on_normal_looted_cmd@w - clear this action

@Ccockpit@W options@w
 Those could be set via @Wadb options edit@w or @Wadb options set cockpit <options> <value>@w:

 @Wenable_auto_actions <true|false>@w - enables or disables auto actions.
   Those actions from @Cauto_actions@w group are executed when you loot an item.
   @mon_normal_looted_lua@w - lua script, executed when you loot normal - not bloot item.
   @mon_normal_looted_cmd@w - regular command, it's sent to "Execute" so you can use
                          aliases here.

   For "normal" looted items you can use all of the item fields prefixed with % symbol
   to get actual values for the currently looted item. See "@Gadb help fields@w" for a full list.
   @WWith an @Rexception@W of @Gid@W field which is replaced by @G%item@W.

   There are few special fields available:
   @G%item@w - looted item ID.
   @G%bloot@w - bloot level of the item, 0 for "normal" loot.
   @G%gpp@w - item's gold per pound value, worth/weight (checked for division by 0).

   With auto actions you can do all kind of things, depends on your level of scripts understanding.
   To put all looted items into container one could go with simple
   @Won_normal_looted_cmd@w set to @W"put %item bag"
   More sophisticated approach might be to put keys onto keyring, drop cheap loot, put more expensive
   items to bag. See default settings for some very minimal examples.
   Note: check out new AKM plugin, which deals keys and keyring management.

   @mon_bloot_looted_lua@w and @mon_bloot_looted_cmd@w are the same as normal actions,
   but are only executed for bonus loot items. In other words %bloot is bigger than 0.
   @RNote@R: bonus loot items aren't automatically identified. Instead you will get
   @Rmost field values from it's "base" counterpart if that's found in the DB. Except for
   @G%item@R, @G%name@R, @G%colorName@R and @G%bloot@R which correspond to the actually looted item.
   Note: @RBloot actions with not be executed if base items isn't found in DB.@w

   I'm trying to decide if this usable or should there be an options to actually
   identify bloot items as well.

 @Wshow_bloot_level <true|false>@w - show/hide bloot level next to bloot names in game.
   If enabled changes your game output to look like this:
     @R(K)@B(M)@W(G)@C(H) @G(@WShimmering 8@G)@w @yM@Yon@ykey @wB@Wo@wne @W(@G154@W)
     @R(K)@B(M)@W(G)@C(H) @G(@WPolished 1@G)@w @RBi@Gol@Bum@Yin@Ces@Mce@Wnc@Re!@w @W(@G150@W)
     @R(K)@B(M)@W(G)@C(H) @R(@WRadiant <11>@R)@w a pair of icy boots @W(@G198@W)
     @R(K)@B(M)@W(G)@C(H) @G(@WEnhanced 2@G)@w @YE@ylvish @YR@yobes @Yo@yf @YP@yriesthood@w @W(@G153@W)@w

 @Widentify_command@w - command to use for item identification. Default's to "id",
   @rNot implemented@w

 @Wupdate_db_on_loot <true|false>@w   - update DB with looted items.

 @Wshow_db_updates <true|false>@w     - show/hide information when new items are adeed to DB.

 @Wshow_db_cache_hits <true|false>@w  - show/hide DB cache hit messages.

 @Wcache_added_format <format.name>@w - item ID output format used to display new items.

 @Widentify_format@w - default "aid" output format when channel is not specifief.

 @Widentify_channel_format@w - default "aid" output format when sending to a channel.
   TODO: more details on format, add format add/remove commands.
   For now you can check options under "format.brief" and "format.full"

 @Wdb_find_format <format.name>@w - default "adb find" output format.

 @Wauto_adb_off_for_zones@w - a list of zones where ADB will not execute any of auto_actions for
 looted items.
 Defaults to list of EPICs. Use @Wadb options edit@w to edit.

 @Wignore_aucto_actions_for_items@w - a list of item names (with optional zone name) to skipped
 when executing auto actions. Defaults to some "special" items needed for goals, getting keys as
 well as various @R(@YAarchaeology@R)@w, @RAardWords@w etc.
 See note below for more details. Use @Wadb options edit@w to edit.

 @Wignore_db_updates_for_items@w - a list of item names (with optional zone name) to skip from
 automatically adding/updating the DB. Defaults to various @R(@YAarchaeology@R)@w, @RAardWords@w, etc.
 Because those are random drop and it doesn't make much sense storing information where it was looted
 from. See note below for more details. Use @Wadb options edit@w to edit.

 @WNote:@w Lines for items ignore list should be formed like this:
 @G[<zone name>:]<item name regex>@w
 If @G[<zone name>:]@w is not present, setting will apply to all zones.
 See default options for some examples.
@R-----------------------------------------------------------------------------------------------
  ]],
    ["format"] = [[
@R-----------------------------------------------------------------------------------------------
@Wadb format add format.<newname> [<existing name>]@w - adds new output format with specified <new name>
  and copies settings from existing format. After adding a format you can change it's settings
  via @Wadb options set <format.newname> <setting> <value>@w
  or @Wadb format edit@w command.
  For example: adb format add format.mine

@Wadb format remove [<existing name>]@w - remove existing output format
  For example: adb format remove
               adn format remove format.mine

@Wadb format edit [<existing name>]@w - edit existing format
  For example: adb format edit
@R-----------------------------------------------------------------------------------------------
  ]],
    ["find"] = [[
@R-----------------------------------------------------------------------------------------------
@Wadb find <query> [format.name]@w - search db using provided <query>.
The query should be formed following sqlite3 select rules.

@WSome examples:

@CFind all weapons between level 26 and 29, sort output first by average weapon damage descending,
@Cthen by item level in the ascending order.
@Wadb find type='Weapon' and level>25 and level<30 ORDER BY avedam desc, level asc
  @B1. @D[@W17885@Ddb] a wicked shortsword [@C29@D lvl] [@Wwield@D] [@M46@Davg @Wsword steel Pierce @D] [@Y214@Dscore] [@G3@Ddr @G3@Dhr] [IR]
  @B2. @D[@W12766@Ddb] @ga @ws@Wil@wv@Wer@g poignard @D[@C29@D lvl] [@Wwield@D] [@M43@Davg @Wdagger silver Pierce @D] [@Y187@Dscore] [@G2@Ddr @G1@Dhr] [IR]
  @B3. @D[@W17664@Ddb] a Huge Club [@C29@D lvl] [@Wwield@D] [@M42@Davg @Wmace wood Bash @D] [@Y168@Dscore] [@G5@Ddr @R-5@Dhr] [IR]
  @B4. @D[@W12518@Ddb] A wicked longsword [@C26@D lvl] [@Wwield@D] [@M40@Davg @Wsword steel Slash sharp@D] [@Y170@Dscore] [@Y1@Dstats] [@G1@Dstr] [IR]

@CFind all items with sum of DamRoll and HitRoll greater than 49, use format.full to display results.
@Wadb find dam+hit>=50 format.full
  @B1. @D[@W1906@Ddb] [@W2797061957@D] @WA@wsh @D[@C181@D lvl] [@WWeapon@D] [@Wwield@D] [@M420@Davg @Wsword ash Negative vampiric@D] [@Y1930@Dscore] [@G25@Ddr @G25@Dhr] [@G200@Dhp@D @R-300@Dmn] [@W22@Dwgt] [@W4000@Dg]
  @x244 @D[@Wglow, hum, evil, magic, anti-good, anti-neutral, noremove, V3@D] [@WThe Mountains of Desolation@D]
  @x201 Keywords: @D[@Wash sword grey evil@D]
  @M Looted from:
  @W King Mendan@D [@Wdesolation@D] Room(s) [@W19627@D]

@CFind level 41 items which are sold by shopkeepers, could be worn on wrist and are enchantable.
@Wadb find level=41 and shop=1 and wearable='wrist' and (flags like '%invis%' or not flags like '%hum%' or not flags like '%glow%')
  @B1. @D[@W8001@Ddb] A @Cglow-in-the-dark @wWrist @YSundial @D[@C41@D lvl] [@Wwrist@D] [@Y40@Dscore] [@G3@Ddr @G1@Dhr] [@Y2@Dstats] [@G2@Dint] [@G2@DallPh @G2@DallMg] [SR]
  @B2. @D[@W13795@Ddb] @YGolden Bracers @wof @MBalboa @D[@C41@D lvl] [@Wwrist@D] [@Y35@Dscore] [@G3@Ddr] [@Y2@Dstats] [@G2@Ddex] [@G2@DallPh @G2@DallMg] [SR]

@CFind level 41 items which are sold by shopkeepers and are enchantable, order by wear location.
@Wadb find level=41 and shop=1 and (flags like '%invis%' or not flags like '%hum%' or not flags like '%glow%') order by wearable
  @B1. @D[@W8029@Ddb] @WS@wc@Wriven@wer'@Ws @y((!@MMight@y!)) @D[@C41@D lvl] [@Warms@D] [@Y60@Dscore] [@G4@Ddr] [@Y4@Dstats] [@G2@Dstr @G2@Ddex] [@G2@DallPh @G1@DallMg] [SR]
  @B2. @D[@W12623@Ddb] @WS@wu@Wb@wl@Wi@wm@We @wB@Wr@wa@Wc@we@Wr@ws @Wo@wf @WV@we@Wn@wg@We@wa@Wn@wc@We @D[@C41@D lvl] [@Warms@D] [@Y60@Dscore] [@G4@Ddr] [@Y4@Dstats] [@G2@Ddex @G2@Dcon] [@G2@DallPh @G2@DallMg] [IR]
  @B3. @D[@W13767@Ddb] a large @YSandstone @MBlock @D[@C41@D lvl] [@Wback@D] [@Y60@Dscore] [@G4@Ddr] [@Y4@Dstats] [@G4@Dstr] [@G2@DallPh @G2@DallMg] [SR]
  @B4. @D[@W8032@Ddb] A @MMaroon Apron@w with a @m<<@y|@wGaardBucks@y|@m>> @MLogo @D[@C41@D lvl] [@Wbody@D] [@Y60@Dscore] [@G4@Ddr] [@Y4@Dstats] [@G4@Dint] [@G2@DallPh @G2@DallMg] [SR]

@RNote@w: field values are case sensitive. If you don't care you could do something like:
  @Wadb find LOWER(name) like '%sword%'@w - which will match all items with names containing
  sword, SWORD, SwOrD etc.

See "@Gadb help fields@w" for a list of available fields.
@R-----------------------------------------------------------------------------------------------
  ]],
    ["aide"] = [[
@R-----------------------------------------------------------------------------------------------
@Waide [container_id] [enchanted] [removable] [S<num>] [I<num>] [R<num>] [IR<num>] [format.name] [command.<command>]@w - Enchanters aid.
This command will identify all matching items in the container or inventory if @Gcontainer_id@w is not specified.
See @Ghelp objectid@w for deails on gettings/using @Gcontainer id@w.
It will run a given @G<command>@w on all matching items if it's specified.

@Genchanted@w - only show items which have one or more enchants present
@Gremovable@w - only show items which have one or more removable (by enchanter) enchants

@GS<num>@w - show items with Solidify giving <= @G<num>@w HR/DR.
@GI<num>@w - show items with Illuminate giving <= @G<num>@w Stats.
@GR<num>@w - show items with Resonate giving <= @G<num>@w Stats.
@GIR<num>@w - show items with Resonate + Solidify giving <= @G<num>@w Stats.
  If more 2 or more of the SIR parameters are present then items matching at least one of the given checks will be shown.
  If @Gremovable@w options is given, then only items with removable SIR enchants passing the comparision will be shown.

@Gformat.name@w - format to use with Identify output, defaults to @Wcockpit.aide_format@w option.
@Gcommand.<command>@w - execute given command after showing item info. Item ID will be appended to given command.

Examples:
  @Waide@w - identify all items in inventory

  @Waide 2785187925 enchanted@w - show all @Genchanted@w items in container 2785187925:

    @D[@W2668599686@D] @G(@WDazzling <9>@G)@w @x117a @x153ghostly @x117helmet @D[@C201@D lvl] [@Whead@D]
      [@G36@Ddr @G12@Dhr] [@Y27@Dstats] [@G2@Dstr @G5@Dint @G5@Dwis @G4@Ddex @G11@Dluk] [@CSIR@D]
    @x051 Solidify @x244[@x046+6@x244dr] [@x046remove Solidify@x244]@x051 Illuminate @x244[@x046+4@x244wis] [@x046remove Illuminate@x244]@x051 Resonate @x244[@x046+3@x244luk] [@x046remove Resonate@x244]

    @D[@W2685807183@D] @RAura @Yof @GTrivia @D[@C1@D lvl] [@Wabove@D] [@G9@Ddr @G7@Dhr] [@Y21@Dstats] [@G3@Dstr @G1@Dint @G7@Dwis @G3@Ddex @G2@Dcon @G5@Dluk] [@CSIR@D]
    @x051 Solidify @x244[@x046+2@x244dr] [@x196TP only@x244]@x051 Illuminate @x244[@x046+4@x244wis] [@x046remove Illuminate@x244]@x051 Resonate @x244[@x046+3@x244luk] [@x046remove Resonate@x244]

  @Waide 2785187925 removable S2@w - show items in container 2785187925 which either have removeable
                                Illuminate/Resonate enchants or removable Solidify with HR/DR<=2
  Will output same as above.

  @Waide 2695030721 enchanted S3 I0 R0@w - show items in container 2695030721 which have solidify enchant giving <= 3 HR/DR:

    @D[@W2706637349@D] @G(@WVibrant 5@G)@w @y-@W)@w=@y=@w=@Wdull lance@w=@y=@w==--- @D[@C92@D lvl] [@Wwield@D]
      [@M232@Davg @Wpolearm Pierce @D] [@G11@Ddr @G6@Dhr] [@Y7@Dstats] [@G1@Dint @G6@Dluk] [@CSR@D]
    @x051 Solidify @x244[@x046+1@x244dr] [@x046remove Solidify@x244]@x051 Resonate @x244[@x046+2@x244luk] [@x046remove Resonate@x244]

    @D[@W2756839229@D] @G(@WEnhanced 2@G)@w @C. @W+ @Rbloody liver greaves @W+ @C. @D[@C200@D lvl] [@Wlegs@D]
      [@G24@Ddr @G5@Dhr] [@Y29@Dstats] [@G7@Dstr @G5@Dint @G3@Dwis @G7@Ddex @G6@Dcon @G1@Dluk]@D [@CSIR@D]
    @x051 Solidify @x244[@x046+3@x244hr] [@x196TP only@x244]@x051 Illuminate @x244[@x046+3@x244wis][@x046remove Illuminate@x244]@x051 Resonate @x244[@x046+1@x244luk] [@x196TP only@x244]

    @D[@W2757910324@D] @G(@WPolished 1@G)@w @x086a shapeshifting shield @D[@C200@D lvl] [@Wshield@D]
      [@G26@Ddr @G11@Dhr] [@Y24@Dstats] [@G4@Dstr @G2@Dint @G8@Dwis @G5@Ddex @G1@Dcon @G4@Dluk]@D [@CSIR@D]
    @x051 Solidify @x244[@x046+1@x244hr] [@x196TP only@x244]@x051 Illuminate @x244[@x046+4@x244wis] [@x046remove Illuminate@x244]@x051 Resonate @x244[@x046+3@x244luk] [@x196TP only@x244]

  @Waide removable S3 I2 R2@w - show items in inventory which have a @Mremovable@w Solidify<=3 or Illuminate<=2 or Resonate<=2:

    @D[@W2682741121@D] @G(>@WTouchstone@G<) @CRock Collecting Bag @D[@C200@D lvl] [@Whold@D]
      [@G20@Ddr @G21@Dhr] [@Y12@Dstats] [@G10@Dstr @G1@Dwis @G1@Dluk] [@CSI@D]
    @x051 Solidify @x244[@x046+1@x244hr] [@x046remove Solidify@x244]@x051 Illuminate @x244[@x046+1@x244wis @x046+1@x244luk] [@x046remove Illuminate@x244]

  @wI find this handy to use after batch enchanting items in a container. So I can find items with "bad" enchants
  like 1-2-3 HR/DR, 1-2 stat IR, to disenchant and attempt to land a better enchant.
  @WNote:@w If disechant_hyperlinks is set in the @Gformat@w used, then you'll see a clickable Hyperlink to remove any
  of removable enchants for the particular item. Hyperlink command will take item out of container and put it back after
  disenchanting if necessary.

  @Waide S5 I0 R0 command.drop@w - drop all items from inventory which have Solidify enchant giving less than 6 HR/DR.
  @WNote@w Make sure to dry run query without command... to see what items gonna be affected
@R-----------------------------------------------------------------------------------------------
  ]],
    ["shop"] = [[
@R-----------------------------------------------------------------------------------------------
@Wadb shop [all]@w - adds items from shop to DB.
This command will identify and add items with unlimited amount sold by shopkeeper in current room to DB.
Item's location will be set to current zone and a special "shopkeeper" mob with current room #.
If @Gall@w is specified this command will also identify and add all base items sold by store to DB with unknown
location which will be automatically updated if you find a mob dropping this item.
@R-----------------------------------------------------------------------------------------------
  ]],
    ["fields"] = [[
@R-----------------------------------------------------------------------------------------------
@WADB shares lots of field names with the ones in DINV plugin (listed below after specific fields).
@RNote@W: field names are @RCase SeNsItIvE@W and should be prefixed with @G%@W if used in auto actions.
  ]],
    ["aench"] = [[
@R-----------------------------------------------------------------------------------------------
@Waench [<item> | container.<container_id>] <S|I|R>[num]... [any] [nofocus] [format.<name>] [fail.<command>] [pass.<command>]@w
@WUse this command to enchant a single item or batch enchant items in inventory or container.

@Waench resume@w - resume batch processing (more details below).
@Waench abort@w - abort batch processing (more details below).

@Gitem@w                     - item name or id to enchant.
@Gcontainer.<container_id>@w - container id to enchant items in.
  See @Ghelp objectid@w for deails on gettings/using @Gcontainer_id@w.
@WNote: If neither @G<item>@W nor @Gcontainer.<container_id>@W is present will enchant items in inventory.

@G<S|I|R>[num]...@w          - one or more S I R with optional number (like S8) in any sequence.
  See below for more details.

@Gany@w                      - use this option to process items enchantable with any of the requested enchants.
  By default @Caench@w command will only process items which could be enchanted by all of the requested enchants.

@Gnofocus@w                  - don't check @Wenchanters focus@w affect, percentage and duration.
  By default @Caench@w command will abort if you're not affected by @W100% enchanters focus@w
  or remaining duration is less than @W30 seconds@w when starting to process new item.

@Gformat.<name>@w            - format to use with Identify output, defaults to @Wcockpit.aide_format@w option.

@Gfail.<command>@w           - execute given @G<command>@w for items not passing requested enchant options.
@Gpass.<command>@w           - execute given @G<command>@w for "Successfully" enchanter items.
@G<command>@w does @Gnot@w have to be a single word.
  For ex: @Waench S2 fail.echo I failed enchanting this pass.echo I've finally made a great item
@WNote@w: Item ID or keyword will be appended to the end of given @G<command>@w.
  You can use your aliases in the @G<command>@w if you need item id somewhere else.
  Fox ex: use @Gfail.dropsac@w to call alias @Gdropsac@w on failed items.
  Which could be something like @Cdropsac *@w -> @Cdrop %1;sacrifice %1

@WAll @Caench@W arguments are optional except that there has to be at least one requested enchant via @G<S|I|R>[num]...@w group.

@G<S|I|R>[num]...@w group has the following meaning:
  @GS@w - Cast @MSolidify@w on item(s)
  @GI@w - Cast @MIlluminate@w on item(s)
  @GR@w - Cast @MResonate@w on item(s)
  @GS<num>@w - Cast @MSolidify@w on item, @Wdisenchant@w if @MSolidify@w landed with less than @G<num>@w stats.
           If it's not possible to @Wdisenchant@w (without using TPs) consider item as @Mfailed@w.
@WSome examples: 
  @CR S I@w - cast resonate. cast solidify. cast illuminate.
          Only items which could be enchanted by all 3 spells would be processed unless @Gany@w option is present.

  @CS8 S2 I4 I@w - cast solidify. disenchant if it gave @Gless than 8@w HR/DR.
               cast solidify if disenchanted in the step above. if it still gives @Gless than 2@w HR/DR then fail.
               cast illuminate, disenchant if it gave @G<4@w stats.
               cast illuminate if disenchanted in the step above.

  @CS8 S I5 I @Gany@w - will go though all items which could be Solidified and/or Illuminated.
                    @CS8 S@w would be ignored for items which can't be Solidified.
                    @CI5 I@w would be ignored for items which can't be Illuminated.

@RNote: I suppose you will not be able to use @GS<num>@w form if you don't have @Gidentify wish@w.
Might add a check for it one day, but I'm lazy :D

Batch enchanting will work automatically only if you're not using @GS<num>@W form.
@WOtherwise you'll have to either type @Caench resume@W or click the link when single item is processed.

@WExamples:

@Maench cap I8 I6 R4 R2 fail.sell
@CAENCH Enchanting [1/1]: @w[@W2832990729@w]:@g[@wRecruit@g] @yCa@gmo@wuf@yla@gge @wCa@yp
@R39912@w/@r39912@whp @G13827@w/@g13927@wmana @Y908@wtnl Quest: @C26@G Dbl: 7 @bNESW@B>
@D[@W2832990729@D] @g[@wRecruit@g] @yCa@gmo@wuf@yla@gge @wCa@yp @D[@C1@D lvl] [@Whead@D] [@Y12@Dstats] [@G1@Dstr @G4@Dwis @G7@Dluk] [@CIR@D]
@x051 Illuminate @x244[@x046+4@x244wis @x046+4@x244luk] [remove Illuminate]@x051 Resonate @x244[@x046+3@x244luk] [@x196TP only@x244]
@CADB: aench command finished

@Maench container.2682741121 R4 R3 I5 I3 fail.sell
@CAENCH Enchanting [1/3]: @w[@W2833002690@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@CAENCH FAILED at 2:R3: @w[@W2833002690@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt

@x051Type <aench resume> or [@x002Click to <aench resume>@x051]

@CAENCH Enchanting [2/3]: @w[@W2833002695@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@D[@W2833002695@D] @g[@wRecruit@g] Br@wow@yn L@gea@wth@yer @gBe@wlt @D[@C1@D lvl] [@Wwaist@D] [@Y10@Dstats] [@G4@Dwis @G6@Dluk] [@CIR@D]
@x051 Illuminate @x244[@x046+2@x244wis @x046+3@x244luk] [@x196TP only@x244]@x051 Resonate @x244[@x046+1@x244wis @x046+3@x244luk] [remove Resonate]

@x051Type <aench resume> or [@x002Click to <aench resume>@x051]

@CAENCH Enchanting [3/3]: @w[@W2833002696@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@CAENCH FAILED at 2:R3: @w[@W2833002696@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@x021ADB: ------------------------------ AENCH ------------------------------
@CProcessed @W3 @Citems, @G1@C successfully.
@CDisenchanted @W3 @Ctime(s), identified @W7 @Ctimes(s).
@CSolidified @W0 @Ctime(s):
@CIlluminated @W2 @Ctime(s):
@W      TOTAL: 4.00 @Cavg @R3 @Cmin @G5 @Cmax
@W       LUCK: 1.50 @Cavg @R0 @Cmin @G3 @Cmax
@W        WIS: 2.50 @Cavg @R2 @Cmin @G3 @Cmax
@CResonated @W5 @Ctime(s):
@W      TOTAL: 2.80 @Cavg @R2 @Cmin @G4 @Cmax
@W       LUCK: 2.60 @Cavg @R2 @Cmin @G3 @Cmax
@W        WIS: 0.20 @Cavg @R0 @Cmin @G1 @Cmax
@CADB: aench command finished

@Maench container.2682741121 I S R any nofocus
@CAENCH Enchanting [1/2]: @w[@W2833007158@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@CAENCH PASS: @w[@W2833007158@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@CAENCH Enchanting [2/2]: @w[@W2833007160@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@CAENCH PASS: @w[@W2833007160@w]:@g[@wRecruit@g] Br@Dow@yn L@gea@Dth@yer @gBe@Dlt
@x021ADB: ------------------------------ AENCH ------------------------------
@CProcessed @W2 @Citems, @G2@C successfully.
@CDisenchanted @W0 @Ctime(s), identified @W0 @Ctimes(s).
@CSolidified @W0 @Ctime(s):
@CIlluminated @W2 @Ctime(s):
@CResonated @W2 @Ctime(s):
@CADB: aench command finished
@R-----------------------------------------------------------------------------------------------
  ]],
    ["changelog"] = [[
@R-----------------------------------------------------------------------------------------------
@MChangelog@w:
1.003
Added @Wadb format add/remove/edit
Added @Wadb options edit
1.004
Don't update db when looting your own corpse.
Fix 0 weight items check.
Fix loot trigger for corpses without adjectives.
1.005
Fix for loot from from double adjective corpses.
Process items if mob was one-shotted.
1.006
Added sqlite db under cache (check cockpit.max_cache_size option)
Fix for loot lines not starting with color codes.
1.007
Fix for clan items which don't have clan instead of foundat field.
Added extra debug command
Added colorName field to action commands
Fix db update on cache sync
1.008
Bunch of internal debugging changes.
Added support to track loot from 'torso'.
1.009
Added items Skill Mods support.
Bumped DB version to 2
Added format options to output DB id, in-game item ID, Skill Mods, Comments, Keywords
Added format.db and default db_find_format options.
Added adb info command
1.010
Added adb find command
Fix for reading Skill Mods from DB.
Set default debug level to 0.
1.011
Change bloot actions to use name and colorName of the actually looted item.
Minor fix to identify version updates which was forgotten sometimes.
String are passed to lua auto actions without surrounding quotes now.
1.012
One more pattern for loot from the chrisp, charred corpse :D
1.013
Add note about invmon to related error message.
Fix for items with really loooooong names taking more than one line.
Fix reading of items with negative skillmods from db.
1.014
Added aide - aid for Enchanters.
New format options to show item type, spells, disenchant hyperlinks.
Switched to use wrapped_captures: no more extra prompts, empty lines etc.
1.015
Added lvl difference to blood diff display.
Fix "aid" error for items which are not in bags.
1.016
Fix error when looting crumbling items while one-shotting mobs
aide - show hyperlinks in grey for "good" removable enchants
aide - add option to run custom command on matched items
aide - not specifying one of S I R options now ignores value of relevant enchant
aide - added IR option
1.017
aide - get item from bag if needed before executing command
1.018
Added items ignore list to exclude from auto actions (special items needed to get keys etc)
Added items ignore list to exclude from db updates (random aarch, aardword etc)
Added zones list to switch adb off automatically (welcome to EPICS!)
Check cockpit options for more details.
1.019
Added adb shop command.
1.020
Fixed a bug for items looted from mobs not in item's FountAt zone.
1.021
Update shop location for already known items if needed.
1.022
Display missing enchants as grey SIR
1.023
Fix aid error for characters without identify wish.
Split help into multiple topics.
1.024
Added clan zones to lookup table.
Added shop field to db.
1.025
Fixed another error for characters without identify wish and added message to disable db updates.
1.026
Fixed double location lines for aid items.
1.027
Fixed adb shop updates when shop content changes during scan.
Added Fractals of the Weave and Aardwolf Estates 2000 zones.
1.028
Abort adb shop command on first mismatched item.
1.029
Show error message for outdated mush clients.
1.030
Shorten mob rooms display.
Add Chakra Spire zone.
1.031
Strip enchants when adding player sold items from shops to DB.
Fix for some items in radiance woods shop.
1.032
Fix error when trying to save db when client is disconnected.
1.033
Add Fellchantry zone
1.034
Add Sea King's Dominion zone
1.035
Fixed loot from sohtwo zone.
Fixed some typos.
Reformatted lua files.
1.036
Added acmp command.
Added error message when item's not found for aid command.
1.037
Sync cache before doing adb find.
1.038
Add external interface for AKM
Add Temple2 goal items to ignore-list.
1.039
Add timeout check to adbIdentifyItem
1.040
Added help for db fields used in 'adb find' and auto_actions.
Added ADB_AddItem
Added Transcendence zone short name.
1.041
Added aench command.
Compacted output for aide command.
Fixed bloot order for Fabled = 18, Mythical = 19.
Removed error message on rare loot queue desync.
@R-----------------------------------------------------------------------------------------------
  ]]
}

local adb_ignore_dinv_fields = {
    ["organize"] = true,
    ["loc"] = true,
    ["rloc"] = true,
    ["key"] = true,
    ["keyword"] = true,
    ["rlocation"] = true,
    ["rname"] = true
}

local adb_fields = {
    ["dbid"] = {
        name = "dbid",
        desc = "Unique database row id for item."
    },
    ["colorName"] = {
        name = "colorName",
        desc = "Item name including aardwolf color codes."
    },
    ["zone"] = {
        name = "zone",
        desc = "Shorname for a zone item is looted from."
    },
    ["comment"] = {
        name = "comment",
        desc = "User entered comments for the item."
    },
    ["identifyLevel"] = {
        name = "identifyLevel",
        desc = "\"@Gfull@W\" for items identified with \"@Gidentify wish@W\". Other modes aren't supported much as of now."
    },
    ["spellsXlevel"] = {
        name = "spellsXlevel",
        desc = "Level of the spell number X cast by item. Use as spells1level .. spells5level."
    },
    ["spellsXname"] = {
        name = "spellsXname",
        desc = "Name of the spell number X cast by item. Use as spells1name .. spells5name."
    },
    ["spellsXcount"] = {
        name = "spellsXcount",
        desc = "Count of spellcasts of the spell number X cast by item. Use as spells1count .. spells5count."
    },
    ["skillMods"] = {
        name = "skillMods",
        desc = "Skill mods applied by item."
    },
    ["identifyVersion"] = {
        name = "identifyVersion",
        desc = "Version of identify module used when item was added to DB. Items with old version will be utomatically updated when seen again."
    },
    ["shop"] = {
        name = "shop",
        desc = "\"1\" if unlimited amount of item is sold by a shopkeeper."
    }
}

function adbPrintFields(tbl)
    local keys = {}
    table.foreach(tbl, function(k, v)
        table.insert(keys, k)
    end)
    table.sort(keys, function(key1, key2)
        return tbl[key1].name < tbl[key2].name
    end)

    for i = 1, #keys, 1 do
        if not adb_ignore_dinv_fields[tbl[keys[i]].name] then
            AnsiNote(ColoursToANSI(string.format("@C%15s@W: %s", tbl[keys[i]].name, tbl[keys[i]].desc)))
        end
    end
end

function adbHelpFields()
    AnsiNote(ColoursToANSI("@W------ ADB specific fields ------\n"))
    adbPrintFields(adb_fields)
    AnsiNote(ColoursToANSI("\n@W------ Fields common with DINV ------\n"))
    adbPrintFields(inv.stats)
    AnsiNote(ColoursToANSI(
        "@R-----------------------------------------------------------------------------------------------"))
end

function adbOnHelp(name, line, wildcards)
    if wildcards == nil or not adb_help[wildcards.topic] then
        local message = [[

@R    It's required to enable server side invmon for this plugin to work!
@w    Execute the following command to enable it:
      @Winvmon
      @wYou will now see inventory update tags.

@Gadb help@w -> show this list

@WAvailable help topics:@w]]
        adbInfo("Running ADB version: " .. tostring(GetPluginInfo(world.GetPluginID(), 19)))
        AnsiNote(ColoursToANSI(message))
        local keys = {}
        table.foreach(adb_help, function(k, v)
            table.insert(keys, k)
        end)
        table.sort(keys, function(key1, key2)
            return key1 < key2
        end)

        for i = 1, #keys, 1 do
            AnsiNote(ColoursToANSI("@Gadb help " .. keys[i] .. "@w"))
        end
        AnsiNote("")
    else
        AnsiNote(ColoursToANSI(adb_help[wildcards.topic]))

        if wildcards.topic == "fields" then
            adbHelpFields()
        end
    end
end

function OnPluginInstall()
    adbInfo("Running ADB version: " .. tostring(GetPluginInfo(world.GetPluginID(), 19)))
    AnsiNote(ColoursToANSI(world.GetPluginInfo(world.GetPluginID(), 3)))
    OnPluginEnable()
end

function OnPluginEnable()
    OnPluginConnect()
end

local aard_extras = require "aard_lua_extras"
local adb_min_client_version = 2249
function adbCheckClientVersion()
    local version, err = aard_extras.PackageVersion()
    if err == nil and version <= adb_min_client_version then
        adbErr("ADB requires MUSH client version " .. tostring(adb_min_client_version) ..
                   " or later! Your client version is " .. tostring(version))
    end
end

function OnPluginConnect()
    adbCheckClientVersion()
    adbLoadOptions()
    adbDbLoad()
    adbCacheLoad()
end

function OnPluginDisconnect()
    adbSaveOptions()
    adbDbSave()
    adbCacheSave()
    adbDbClose()
end

function OnPluginDisable()
end

function OnPluginSaveState()
    adbSaveOptions()
    adbDbSave()
    adbCacheSave()
end

-- Some item names in the game have extra(erroneous) color codes which appear in the inv/keyring data
-- but can't be captured in the identify output.
local color_names_fixup = {
    ["@Y(t@Rh@re a@Rm@Yu@yl@Re@rt of @rf@Rl@Ya@ym@Re@r@Ys@y)"] = "@Y(t@Rh@re a@Rm@Yu@yl@Re@rt of f@Rl@Ya@ym@Re@Ys@y)"
}
------- Functions for external plugins -------

-- returns string containing serialized array of matching item(s) from DB
function ADB_GetItem(color_name)
    adbDebug("ADBGetItem " .. color_name, 2)
    local result = {}
    if color_name == nil then
        return serialize.save_simple(result)
    end
    color_name = color_names_fixup[color_name] ~= nil and color_names_fixup[color_name] or color_name
    return serialize.save_simple(adbCacheGetItemsByName(color_name))
end

-- Identifies item using <command>, calls provided <callback> function with
-- serialized identify result when results are ready.
-- Returns false on failure.
function ADB_IdentifyItem(command, plugin, callback, ctx)
    adbDebug("ADBIdentifyItem " .. command .. " from plugin " .. plugin, 2)
    if command == nil then
        return false
    end

    local id_ctx = {
        plugin = plugin,
        callback = callback,
        ctx = ctx
    }
    adbIdentifyItem(command, function(obj, ctx)
        CallPlugin(ctx.plugin, ctx.callback, serialize.save_simple(obj), ctx.ctx)
    end, id_ctx)

    return true
end

-- Adds given non bloot item to DB
function ADB_AddItem(item)
    adbDebug("ADBAddItem " .. item, 2)
    local item = loadstring(string.format("return %s", item))()
    if item == nil or item.stats == nil or item.stats.name == nil or item.colorName == nil or item.stats.foundat == nil or
        adbGetBlootLevel(item.stats.name) > 0 then
        return false
    end
    item.location = item.location == nil and {} or item.location
    item.location.mobs = item.location.mobs == nil and {} or item.location.mobs
    item.location.zone = item.location.zone == nil and adbAreaNameXref[item.stats.foundat] or item.location.zone
    if item.location.zone == nil then
        adbErr("Don't know short zone name for " .. item.stats.foundat)
        return false
    end
    adbCacheAdd(item)
    return true
end

-- Calls <plugin> <callback> when provided <filter> function
-- returns "true" for a looted item.
-- Note: adb auto actions are ignored for such items.
-- Note: going to be called for non-bloot items only, yet.
-- Returns false on failure.
function ADB_RegisterLootFilter(filter, plugin, callback)
    local func, err
    func, err = loadstring(filter)
    if func == nil then
        adbInfo("Failed to compile loot filter: " .. err)
        return false
    end

    adb_external_loot_filters["filter"] = {
        func = func,
        plugin = plugin,
        callback = callback
    }
    adbInfo("Registered loot filter " .. callback .. " for plugin " .. plugin)
    return true
end
