require "tprint"
require "var"
require "serialize"
require "gmcphelper"
require "wait"
require "wrapped_captures"
dofile(GetInfo(60) .. "aardwolf_colors.lua")

local akm_state = {}
local akm_options = {}
local adb_plugin_id = "cf78ba52f9bbad41f7e6b2e8"

local akm_keyring_data_queue = nil
function akmUpdateKeyringData()
    akmInfo("Updating keyring data...")
    akm_keyring_data_queue = {}
    Capture.tagged_output("keyring data", "{keyring}", "{/keyring}", false, true, true, true, akmKeyringDataReadyCB, false)
end

function akmDedupKeyring()
    akmInfo("Deduplicating existing keys...")
    table.sort(akm_keyring_data_queue, function(a, b)
        return a.name > b.name
    end)
    for i = #akm_keyring_data_queue - 1, 1, -1 do
        if akm_keyring_data_queue[i].name == akm_keyring_data_queue[i + 1].name then
            local ri = (akm_keyring_data_queue[i].level >= akm_keyring_data_queue[i + 1].level
                            and not akm_keyring_data_queue[i].flags:find("K")) and i or i + 1
            if akm_keyring_data_queue[ri].flags:find("K") then
                ri = not akm_keyring_data_queue[i].flags:find("K") and i or nil
            end
            if ri == nil then
                akmInfo("Skipping kept duplicate keys " .. akm_keyring_data_queue[i].name ..
                        " with IDs ".. akm_keyring_data_queue[i].id .. " and " .. akm_keyring_data_queue[i + 1].id)
            else
                SendNoEcho("keyring get " .. akm_keyring_data_queue[ri].id)
                table.remove(akm_keyring_data_queue, ri)
            end
        end
    end
    akmInfo("Done")
end

function akmKeyringDataReadyCB(style_lines)
    akmDebug("akmKeyringDataReadyCB", 2)
    for _, v in ipairs(style_lines) do
        local line = strip_colours(StylesToColours(v))
        local id, flags, name, level
        _, _, id, flags, name, level = line:find("^(%d+),(.*),(.*),(.*),.*,.*,.*,.*$")
        if id ~= nil then
            name = name:gsub("^@w", ""):gsub("@w$", "")
            table.insert(akm_keyring_data_queue, {
                id = id,
                flags = flags,
                name = name,
                level = tonumber(level),
            })
        else
            akmErr("Can't find ID in keyring data line " .. line)
        end
    end
    akmDedupKeyring()
    akmInfo("processing " .. #akm_keyring_data_queue .. " items(s).")
    akmKeyringDataQueueDrain()
end

local akm_queue_draining = false
function akmKeyringDataQueueDrain()
    akmDebug("akmKeyringDataQueueDrain", 2)
    if #akm_keyring_data_queue == 0 then
        akm_queue_draining = false
        akmInfo("Done")
        return
    end
    if not akm_queue_draining then
        akm_queue_draining = true
        akm_state.keyring = {}
    end
    local ctx = {
        key = akm_keyring_data_queue[1],
        retries = 0,
    }
    table.remove(akm_keyring_data_queue, 1)
    local rc, items = CallPlugin(adb_plugin_id, "ADB_GetItem", ctx.key.name)
    if rc ~= error_code.eOK then
        akmErr("Failed to call ADB_GetItem " .. items)
    else
        items = loadstring(string.format("return %s", items))()
        akmDebug("Found " .. tostring(#items) .. " items matching [".. ctx.key.name .. "]", 2)

        if #items == 1 then
            table.insert(akm_state.keyring, {
                id = ctx.key.id,
                item = items[1],
            })
            akmKeyringDataQueueDrain()
        else
            if not akmIdentifyItemHelper(ctx) then
                akmKeyringDataQueueDrain()
            end
        end
    end
end

function akmIdentifyItemHelper(ctx)
    akmDebug("calling ADB_IdentifyItem", 2)
    local rc, result
    rc, result = CallPlugin(adb_plugin_id, "ADB_IdentifyItem",
                                "keyring get " .. ctx.key.id .. "\n" ..
                                "id " .. ctx.key.id .. "\n" ..
                                "keyring put " .. ctx.key.id,
                                GetPluginID(), "akmIdentifyResultReadyCB", serialize.save_simple(ctx))
    if rc ~= error_code.eOK or result ~= true then
        akmErr("Failed to call ADB_GetItem " .. result)
        return false
    end
    return true
end

function akmIdentifyResultReadyCB(obj, ctx)
    akmDebug("akmIdentifyResultReadyCB", 2)
    local obj = loadstring(string.format("return %s", obj))()
    local ctx = loadstring(string.format("return %s", ctx))()

    if obj.stats.id == nil or obj.stats.id ~= tonumber(ctx.key.id) then
        if ctx.retries < 1 then
            akmDebug("Failed to identify " .. ctx.key.id .. " retrying.", 1)
            ctx.retries = 1
            if not akmIdentifyItemHelper(ctx) then
                akmKeyringDataQueueDrain()
            end
            return
        else
            akmErr("Failed to identify " .. ctx.key.id)
        end
    else
        if ctx.key.name ~= obj.colorName then
            akmErr("Identified name [" .. obj.colorName .. "] doesn't match keyring data name [" .. ctx.key.name .. "]")
        end
        table.insert(akm_state.keyring, {
            id = ctx.key.id,
            item = obj,
        })
        CallPlugin(adb_plugin_id, "ADB_AddItem", serialize.save_simple(obj))
    end

    akmKeyringDataQueueDrain()
end

function akmAdbKeyFilter(id, bloot, item)
    return item.stats.type == "Key" or string.find(item.stats.flags, "iskey")
end

function akmHasRotTimer(item)
    return item.stats.notes ~= nil and string.find(item.stats.notes, "^Expires in")
end

function akmOnKeyLooted(id, bloot, item)
    local item = loadstring(string.format("return %s", item))()
    
    for _, v in ipairs(akm_state.keyring) do
        if v.item.colorName == item.colorName then
            if not string.find(item.stats.flags, "melt%-drop") and not string.find("%flags", "nodrop") then
                if akm_options.get_rid_of_key_cmd ~= "" then
                    SendNoEcho(akm_options.get_rid_of_key_cmd .. " " .. tostring(id))
                end
            end
            return
        end
    end

    if not akmHasRotTimer(item) then
        table.insert(akm_state.keyring, {
            id = id,
            item = item,
        })
        SendNoEcho("keyring put " .. tostring(id))
    end
end

------ Options ------
function akmGetDefaultOptions()
    local default_options = {
        version = "1.001",
        get_rid_of_key_cmd = "drop"
    }
    return default_options
end

function akmCheckOptions()
    if akm_options.version ~= akmGetDefaultOptions().version then
        akmInfo("AKM options stored are too old, resetting to defaults!")
        akm_options = copytable.deep(akmGetDefaultOptions())
    end
end

function akmOnOptionsResetCommand()
    akm_options = copytable.deep(akmGetDefaultOptions())
    akmInfo("AKM options reset to defaults!")
    akmCheckOptions()
    akmSaveOptions()
end

function akmLoadOptions()
    akm_options = loadstring(string.format("return %s", var.config or serialize.save_simple(akmGetDefaultOptions())))()
    akmCheckOptions()
    akmSaveOptions()
end

function akmSaveOptions()
    var.config = serialize.save_simple(akm_options)
end

-- function akmOnOptionsEditCommand(name, line, wildcards)

function akmOnOptionsCommand(name, line, wildcards)
    akmInfo("Options:")
    if wildcards.key1 == "" then
        tprint(akm_options)
        return
    end

    if akm_options[wildcards.key1] == nil then
        akmInfo("Warn: unknown option group " .. wildcards.key1)
        return
    end
    if akm_options[wildcards.key1][wildcards.key2] == nil then
        Note("Warn: unknown option " .. wildcards.key2)
        return
    end

    local type = type(akm_options[wildcards.key1][wildcards.key2])

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
        akmInfo("Warn: unexpected value type " .. type)
    end

    if value ~= nil then
        akm_options[wildcards.key1][wildcards.key2] = value
        akmCheckOptions()
        akmSaveOptions()
        akmInfo("Set " .. wildcards.key1 .. " " .. wildcards.key2 .. " to " ..
                    tostring(akm_options[wildcards.key1][wildcards.key2]))
    else
        akmInfo(wildcards.value .. " is not a valid " .. type)
    end
end

------ Debug ------
akm_debug_level = 0

function akmOnDebugLevel(name, line, wildcards)
    akm_debug_level = tonumber(wildcards.level)
end

function akmDebug(what, level)
    if level ~= nil and level > akm_debug_level then
        return
    end

    if type(what) == "string" then
        Note("AKM Debug: " .. what)
    elseif type(what) == "function" then
        Note("AKM Debug:")
        what()
    end
end

function akmDebugTprint(t, level)
    if level == nil or level <= akm_debug_level then
        if t == nil then
            print("Table is nil")
        else
            tprint(t)
        end
    end
end

function akmErr(message)
    ColourNote("white", "red", "AKM ERROR: " .. message)
    ColourNote("white", "red", "Please report this to Athlau with a couple pages of screen output before this message.")
end

function akmInfo(message)
    ColourNote("blue", "white", "AKM: " .. message)
end

------ Plugin Callbacks ------
local akm_help = {
    ["commands"] = [[
@R-----------------------------------------------------------------------------------------------
@Wakm help [topic]@w  - show help message.
@Wakm options@w       - various akm options, see @Gakm help options@w for more details.
@Wakm update@w        - rescan keys on your keyring (done automatically on connect).
                        Use it if you manually removed/dropped/gave away keys.
@R-----------------------------------------------------------------------------------------------
  ]],
    ["options"] = [[
@R-----------------------------------------------------------------------------------------------
@Wakm options [edit|reset|set <group> <option> [value] ]@w
 This command shows or changes AKM options.
 Examples:
 @Wakm options@w - show current options
 @Wakm options edit@w - edit options
 @Wakm options reset@w - reset options to defaults.

 Note: akm options edit not implemented yet :P
 Note: and can't edit drop command too :(
@R-----------------------------------------------------------------------------------------------
  ]],
    ["changelog"] = [[
@R-----------------------------------------------------------------------------------------------
@MChangelog@w:
1.001
Initial drop.
1.002
Capture timed out id requests.
1.003
Add existing keys to DB if needed.
1.004
Fix deduplicating of freshly looted keys.
Don't try to put keys with rot timer on keyring.
@R-----------------------------------------------------------------------------------------------
  ]]
}

function akmOnHelp(name, line, wildcards)
    if wildcards == nil or not akm_help[wildcards.topic] then
        local message = [[

@Gakm help@w -> show this list

@WAvailable help topics:@w]]
        akmInfo("Running AKM version: " .. tostring(GetPluginInfo(world.GetPluginID(), 19)))
        AnsiNote(ColoursToANSI(message))
        for k, _ in pairs(akm_help) do
            AnsiNote(ColoursToANSI("@Gakm help " .. k .. "@w"))
        end
        AnsiNote("")
    else
        AnsiNote(ColoursToANSI(akm_help[wildcards.topic]))
    end
end

local akm_initialized = false

function akmInit()
    akm_initialized = true
    akmUpdateKeyringData()
end

function OnPluginBroadcast(msg, id, name, text)
    if not akm_initialized then
        if (id == '3e7dedbe37e44942dd46d264') then
            if (text == "char.status") then
                local state = tonumber(gmcp("char.status.state"))
                if state == 3 or state == 4 or state == 8 or state == 9 or state == 11 or state == 12 then
                    akmInit()
                end
            end
        end
    end
end

function OnPluginInstall()
    akmInfo("Running AKM version: " .. tostring(GetPluginInfo(world.GetPluginID(), 19)))
    AnsiNote(ColoursToANSI(world.GetPluginInfo(world.GetPluginID(), 3)))
    OnPluginEnable()
end

function OnPluginEnable()
    OnPluginConnect()
end

local aard_extras = require "aard_lua_extras"
local akm_min_client_version = 2249
function akmCheckClientVersion()
    local version, err = aard_extras.PackageVersion()
    if err == nil and version <= akm_min_client_version then
        akmErr("AKM requires MUSH client version " .. tostring(akm_min_client_version) ..
                   " or later! Your client version is " .. tostring(version))
    end
end

local akm_min_adb_version = 1.042
function akmCheckADBVersion()
    if GetPluginInfo(adb_plugin_id, 19) == nil then
        akmErr("AKM requires ADB plugin!")
    elseif not GetPluginInfo(adb_plugin_id, 17) then
        akmErr("AKM requires ADB plugin to be ENABLED!")
    elseif GetPluginInfo(adb_plugin_id, 19) < akm_min_adb_version then
        akmErr("AKM requires ADB plugin version " .. tostring(akm_min_adb_version) .. 
        " or later! Your ADB version is " .. tostring(GetPluginInfo(adb_plugin_id, 19)))
    end
end

function OnPluginConnect()
    akmCheckClientVersion()
    akmCheckADBVersion()
    akmLoadOptions()
    CallPlugin(adb_plugin_id, "ADB_RegisterLootFilter", string.dump(akmAdbKeyFilter), GetPluginID(), "akmOnKeyLooted")
    Send_GMCP_Packet("request char")
end

function OnPluginDisconnect()
    akmSaveOptions()
end

function OnPluginDisable()
end

function OnPluginSaveState()
    akmSaveOptions()
end
