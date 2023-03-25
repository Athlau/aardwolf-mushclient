require "tprint"
require "var"
require "serialize"
require "gmcphelper"
require "wait"
require "wrapped_captures"
dofile(GetInfo(60) .. "aardwolf_colors.lua")

local akm_state = {}
local akm_options = {}

function akmGetDefaultOptions()
    local default_options = {
        version = "1.001"
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
@R-----------------------------------------------------------------------------------------------
  ]],
    ["changelog"] = [[
@R-----------------------------------------------------------------------------------------------
@MChangelog@w:
1.001
Initial drop.
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

local adb_plugin_id = "cf78ba52f9bbad41f7e6b2e8"
local akm_min_adb_version = 1.037
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
end

function OnPluginDisconnect()
    akmSaveOptions()
end

function OnPluginDisable()
end

function OnPluginSaveState()
    akmSaveOptions()
end
