require "tprint"
require "var"
require "serialize"
require "gmcphelper"
require "wait"
require "wrapped_captures"
dofile(GetPluginInfo(GetPluginID(), 20).."adb_id.lua")

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
    disechant_hyperlinks = "Show hyperlinks to disenchant removable enchants on item",
  },
}

function adbGetDefaultOptions()
  local default_options = {
    version = "1.004",
    auto_actions = {
      on_bloot_looted_cmd = "gtell just looted;aid %item gtell;aid %item",
      on_bloot_looted_lua = "if %bloot>5 then SendNoEcho(\"say Looted good bloot %bloot %colorName\") end",
      on_normal_looted_cmd = "echo could have done \"put %item bag\" here",
      on_normal_looted_lua = "if %gpp<200 and (\"%type\"==\"Armor\" or \"%type\"==\"Weapon\" or \"%type\"==\"Trash\" or \"%type\"==\"Treasure\") then " ..
                                "Send(\"echo drop %item\") elseif %type~=\"Key\" then Send(\"put %item 2785187925\") end",
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
      enchants = "@C",
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
      disechant_hyperlinks = true,
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
      disechant_hyperlinks = false,
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
      disechant_hyperlinks = false,
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
      disechant_hyperlinks = true,
    },
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
        local copy_from = adbGetDefaultOptions()[k] and adbGetDefaultOptions()[k] or adbGetDefaultOptions()["format.full"]
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
        local copy_from = adbGetDefaultOptions()[k] and adbGetDefaultOptions()[k] or adbGetDefaultOptions()["format.full"]
        for _, v1 in ipairs(added) do
          adb_options[k][v1] = copy_from[v1]
        end
      end
    end
    adb_options["format.enchanter"] = copytable.deep(adbGetDefaultOptions()["format.enchanter"])
    adb_options.cockpit.aide_format = "format.enchanter"
  end

  if adb_options.version ~= adbGetDefaultOptions().version then
    adbInfo("ADB options stored are too old, resetting to defaults!")
    adb_options = copytable.deep(adbGetDefaultOptions())
  end

  if adb_options.cockpit.max_cache_size <= 0 then
    adb_options.cockpit.max_cache_size = adbGetDefaultOptions().cockpit.max_cache_size
  end

  EnableTrigger("adbBlootNameTrigger", adb_options.cockpit.show_bloot_level)
  EnableTriggerGroup("adbLootTriggerGroup", adb_options.cockpit.update_db_on_loot or adb_options.cockpit.enable_auto_actions)
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
    if key1 == "cockpit" and (key2 == "identify_format" or key2 == "identify_channel_format" or 
                              key2 == "cache_added_format" or key2 == "aide_format") then
      local format = adbPickFormat("Choose " .. key2, adb_options[key1][key2])
      if format == nil then return end
      adb_options[key1][key2] = format
    elseif key1 == "auto_actions" then
      local cmd = utils.editbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2])
      if cmd == nil then return end
      adb_options[key1][key2] = cmd
    else
      local value = utils.inputbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2])
      if value == nil then return end
      adb_options[key1][key2] = value
    end
  elseif type(adb_options[key1][key2]) == "boolean" then
    local value = utils.msgbox(key1 .. "." .. key2, "ADB", "yesnocancel", "?", adb_options[key1][key2] and 1 or 2)
    if value == "cancel" then return end
    adb_options[key1][key2] = value == "yes"
  elseif type(adb_options[key1][key2]) == "number" then
    local value = utils.inputbox("Edit " .. key1 .. "." .. key2, "ADB", adb_options[key1][key2])
    if value == nil then return end
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
    adbInfo("Set " .. wildcards.key1 .. " " .. wildcards.key2 .. " to " .. tostring(adb_options[wildcards.key1][wildcards.key2]))
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
      if format == nil then return end
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
      if format == nil then return end
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
      if format == nil then return end
      assert(adb_options[format])
    end
  end

  local choices = {}
  local defaults = {}
  for k, v in pairs(adb_options[format]) do
    choices[k] = adb_options_description.format[k]
    defaults[k] = v
  end
  local selection = utils.multilistbox("Select " .. format .. " options (use ctrl to select multiple items)", "ADB", choices, defaults)
  if selection == nil then return end

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
    count = 0,
  },
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

  table.sort(keys, function (key1, key2)
    return adb_recent_cache[key1].cache.timestamp > adb_recent_cache[key2].cache.timestamp
  end)

  for i = #keys, force_full_clear and 1 or (adb_options.cockpit.max_cache_size + 1), -1 do
    local item = adb_recent_cache[keys[i]]
    if item.cache.new then
      assert(not item.cache.rowid)
      adbDbAddItem(item)
    elseif item.cache.dirty then
      adbDbUpdateItem(item)
    end
    adbDebug("Evicted from cache [" .. item.cache.rowid .. "] [".. item.colorName .. "] [".. item.location.zone .. "]", 2)
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
      count = 0,
    }
    local count = 0
    for k, v in pairs(adb_recent_cache) do
      if k ~= "meta" then
        count = count + 1
        v.cache = {
          new = true,
          dirty = false,
          timestamp = os.time(),
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
        count = 0,
      }
    }
  end

  adbDebug("Cache version " .. adb_recent_cache.meta.version .. " contains " .. adb_recent_cache.meta.count .. " item(s).", 1)
end

function adbCacheGetKey(name, zone)
  return zone.."->"..name
end

function adbCacheGetItem(color_name, zone)
  adbDebug("adbCacheGetItem [" .. color_name .. "] [" .. zone .. "]", 3)
  local result = adb_recent_cache[adbCacheGetKey(color_name, zone)]

  if result == nil then
    result = adbDbGetItem(color_name, zone)
    if result then adbCacheAdd(result, true) end
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
    if result then adbCacheAdd(result, true) end
  end

  if result ~= nil then
    result.cache.timestamp = os.time()
  end
  return result
end

function adbCacheItemUpdateIdentify(cache_item, item)
  assert(cache_item.colorName == item.colorName)
  cache_item.cache.dirty = true

  local ignore_keys = {
    cache = true,
    location = true,
  }
  for k, _ in pairs(item) do
    if not ignore_keys[k] then
      cache_item[k] = item[k]
    end
  end

  if adb_options.cockpit.show_db_updates then
    AnsiNote(ColoursToANSI("@CADB updated identify version:\n"
                           .. adbIdReportGetItemString(cache_item, adb_options[adb_options.cockpit.cache_added_format])))
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
      AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo("@CADB updated cache item @w[" .. cache_item.colorName .. "@w] @C:", cache_item.location)))
    end
  elseif adb_options.cockpit.show_db_cache_hits then
    AnsiNote(ColoursToANSI("@CADB item already in cache: @w[" .. cache_item.colorName .. "@w]"))
  end
end

function adbCacheAdd(item, skip_cache_search)
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
        timestamp = os.time(),
      }
    end
    if not adb_recent_cache[key] then
      adb_recent_cache.meta.count = adb_recent_cache.meta.count + 1
    end
    adb_recent_cache[key] = item
    adbDebug("Added to cache:", 3)
    adbDebugTprint(item, 3)
    if adb_options.cockpit.show_db_updates then
      if not skip_cache_search then
        AnsiNote(ColoursToANSI("@CADB added to cache:\n" .. adbIdReportGetItemString(item, adb_options[adb_options.cockpit.cache_added_format])))
      else
        adbDebug(function()
          AnsiNote(ColoursToANSI("@CADB loaded to cache from db:\n" .. adbIdReportGetItemString(item, adb_options[adb_options.cockpit.cache_added_format])))
        end, 1)
      end
    end
    adbCacheShrink()
  else
    adbDebug(item.colorName.." already in cache, updated timestamp", 3)
    cache_item.cache.timestamp = os.time()
    if adb_options.cockpit.show_db_updates then
      AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo("@CADB updated cache item " .. cache_item.colorName .. "@C :", cache_item.location)))
    end
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
  cmd = cmd:gsub("%%%f[%a]" .."bloot" .. "%f[%A]", bloot)
  cmd = cmd:gsub("%%%f[%a]" .."name" .. "%f[%A]", lua and adbMakeLuaString(name) or name)
  local cname = adb_options.cockpit.show_bloot_level and adbAddBlootLevel(colorName) or colorName
  cmd = cmd:gsub("%%%f[%a]" .."colorName" .. "%f[%A]", lua and adbMakeLuaString(cname) or cname)

  local gpp = base_item.stats.weight == 0 and 99999999 or (base_item.stats.worth / base_item.stats.weight)
  cmd = cmd:gsub("%%%f[%a]" .."gpp" .. "%f[%A]", gpp)

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

  if not adb_options.cockpit.enable_auto_actions then
    return
  end

  local cmd
  cmd = adb_options.auto_actions.on_normal_looted_lua
  if cmd ~= "" then
    cmd = adbReplacePatterns(cmd, id, bloot, item.stats.name, item.colorName, item, true)
    local lua = loadstring(cmd)
    if lua ~= nil then
      adbDebug("Executing lua " .. cmd, 3)
      lua()
    else
      adbInfo("Failed to compile lua " .. cmd)
    end
  end
  cmd = adb_options.auto_actions.on_normal_looted_cmd
  if cmd ~= "" then
    cmd = adbReplacePatterns(cmd, id, bloot, item.stats.name, item.colorName, item)
    adbDebug("Executing cmd " .. cmd, 3)
    Execute(cmd)
  end
end

function adbOnBlootItemLooted(id, drain_loot_item)
  adbDebug("adbOnBlootItemLooted " .. id .. " " .. drain_loot_item.name, 2)
  if not adb_options.cockpit.enable_auto_actions or
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
    local lua = loadstring(cmd)
    if lua ~= nil then
      adbDebug("Executing lua " .. cmd, 3)
      lua()
    else
      adbInfo("Failed to compile lua " .. cmd)
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
    adbErr("adbDrainOne -> inv.name "..adb_drain_inv_item.name.." != "..adb_drain_loot_item.name)
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
    adbDebug(adb_drain_loot_item.colorName.." found in cache", 4)
    if adb_options.cockpit.update_db_on_loot then
        adbCacheItemAddMobs(cache_item, {adbCreateMobFromLootItem(adb_drain_loot_item)})

        -- we have old item in cache/db, inentify again
        if cache_item.identifyVersion ~= adb_id_version then
          adbDebug("Updating old identify version for ".. adb_drain_loot_item.colorName, 1)
          local ctx = {
            drain_inv_item = adb_drain_inv_item,
            drain_loot_item = adb_drain_loot_item,
            cache_item = cache_item,
          }
          adbIdentifyItem("id " .. tostring(adb_drain_inv_item.id), adbDrainIdResultsReadyCB, ctx)
          return
        end
    end

    adbOnItemLooted(adb_drain_inv_item.id, cache_item)
    adbDrainOne()
    return
  end

  if adb_options.cockpit.update_db_on_loot then
    local ctx = {
      drain_inv_item = adb_drain_inv_item,
      drain_loot_item = adb_drain_loot_item,
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
  local key = mob.zone .. "->" .. mob.colorName
  local existing_mob = item.location.mobs[key]
  if existing_mob ~= nil then
    existing_mob.rooms = adbMergeMobRooms(existing_mob, mob)
  else
    item.location.mobs[key] = mob
  end
end

function adbCreateMobFromLootItem(item)
  return {
    name = item.mob,
    colorName = item.colorMob,
    rooms = item.room,
    zone = item.zone,
  }
end

function adbDrainIdResultsReadyCB(item, ctx)
  -- TODO: check if identify failed...

  if ctx.drain_inv_item.id ~= item.stats.id then
    adbInfo("adbDrainIdResultsReadyCB -> something is off! Expected id "..tostring(ctx.drain_inv_item.id) ..
           " but got " .. tostring(item.stats.id) ..
           ". Did you throw away [" .. ctx.drain_loot_item.name .. "] already?")
    adbDrainOne()
    return
  end

  -- TODO: not sure if "same" items could be carried by mobs in different zones
  -- for now going to have location.zone which is set to first mob's zone
  if ctx.cache_item == nil then
    item.location = {
      zone = ctx.drain_loot_item.zone,
      mobs = {},
    }
    adbItemLocationAddMob(item, adbCreateMobFromLootItem(ctx.drain_loot_item))
    adbCacheAdd(item)
  else
    -- if identify had to queue this call, cache_item was copied and no longer
    -- references actual table in recent cache.
    local cache_item = adb_recent_cache[adbCacheGetKey(ctx.cache_item.colorName, ctx.cache_item.location.zone)]
    assert(cache_item)
    adbCacheItemUpdateIdentify(cache_item, item)
  end

  adbOnItemLooted(item.stats.id, item)
  adbDrainOne()
end

function adbLootedStackRemoveLast(name)
  adbDebug("adbLootedStackRemoveLast "..name, 5)

  if #adb_looted_stack == 0 then
    adbDebug("adbLootedStackRemoveLast unexpected? #adb_looted_stack == 0", 1)
    return
  end

  if adb_looted_stack[#adb_looted_stack].name == name then
    table.remove(adb_looted_stack)
   else
    adbErr("Looted stack last ["..adb_looted_stack[#adb_looted_stack].name.."] doesn't match provided name ["..
           name.."]")
  end
end

function adbLootedStackPush(item)
  adbDebug("adbLootedStackPush "..item.colorName, 5)

  -- It seems that invitem messages trim "," in item name, like this:
  -- a tarnished, silver flute (200)
  -- {invitem}2786399276,,a tarnished silver flute,200,6,0,-1,-1
  -- So strip name and compare against as well
  local nocommas_name = item.name:gsub(",", "")

  -- {invitem} messages comes before the actual loot message,
  -- so there should be an item with same name in invitem stack already.
  if adb_invitem_stack[#adb_looted_stack + 1] ~= nil and 
     (adb_invitem_stack[#adb_looted_stack + 1].name == item.name or
      adb_invitem_stack[#adb_looted_stack + 1].name == nocommas_name) then
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
          adbDebug("Removing invitem from untracked source: "..removed.name, 5)
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
  adbErr("Can't find invitem to remove ["..name.."]")
end

function adbInvitemStackPush(item)
  adbDebug("adbInvitemStackPush "..item.id.." "..item.name, 5)
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
  adbDebug("adbOnItemLootedTrigger colored_line: "..colored_line, 5)

  -- it seems that sometimes there's leftover color code from previous line
  -- at least I saw "@x248You get @Rminotaur clan @x069markings@w..."
  local name_start
  _, name_start = colored_line:find("^@?[%a%d]*You get @?[%a%d]*%d+@?[%a%d]* %* ")
  if name_start == nil then 
    _, name_start = colored_line:find("^@?[%a%d]*You get ")
    if name_start == nil then
      adbErr("Can't parse name start: ["..colored_line.."]")
      return
    end
  end

  -- weird... sometimes you get items not from a corpse:
  -- You get (Enhanced 2) *-Victory-* from the torso of Mota.
  -- TODO: compile regex here instead of lua matches?
  local name_end_patterns = {
    "@w from the ?%a*,? ?%a* corpse of ",
    "@w from the ?%a*,? ?%a* torso of ",
    " from the ?%a*,? ?%a* corpse of ",
    " from the ?%a*,? ?%a* torso of ",
  }

  local name_end = nil
  local mob_start = nil
  local i = 1
  while name_end == nil and i <= #name_end_patterns do
    name_end, mob_start = colored_line:find(name_end_patterns[i])
    i = i + 1
  end
  if name_end == nil then
    adbErr("Can't parse name end and mob start: ["..colored_line.."]")
    return
  end
  color_name = colored_line:sub(name_start + 1, name_end - 1)

  assert(mob_start ~= nil)

  local mob_end
  mob_end = colored_line:find("@w%.$") or colored_line:find("%.$")
  if mob_end == nil then
    adbErr("Can't parse mob end: ["..colored_line.."]")
    return
  end
  color_mob = colored_line:sub(mob_start + 1, mob_end - 1)

  local t = {
    name = wildcards.item,
    colorName = color_name,
    mob = wildcards.mob,
    colorMob = color_mob,
    zone = gmcp("room.info.zone"),
    room = gmcp("room.info.num"),
  }

  for i = 1, wildcards.count ~= "" and tonumber(wildcards.count) or 1, 1 do
    adbLootedStackPush(copytable.deep(t))
  end

  -- one shotted mob without getting gmcp in combat state
  if gmcp("char.status.state") == "3" and not was_in_combat then
    -- get a chance for crumble trigger to fire
    AddTimer("DrainOneTimer", 0, 0, 1, "", timer_flag.Enabled + timer_flag.OneShot + timer_flag.Replace + timer_flag.Temporary, "adbDrainOne")
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
    name = wildcards.item,
  }
  adbInvitemStackPush(t)
end

function adbOnInvmonTrigger(name, line, wildcards)
  --if wildcards.action == "4" or wildcards.action == "3" then
  --  Note("invmon "..line)
  --end
end

function adbOnAdbDebugDump()
  Note("---------------- ADB ----------------")
  Note("invitems stack:")
  tprint(adb_invitem_stack)
  Note("looted stack:")
  tprint(adb_looted_stack)
  Note("recent cache:")
  print(adb_recent_cache.meta.count .. " entries")
  --tprint(adb_recent_cache)
  adbIdDebugDump()
  Note("-------------------------------------")
end

function adbOnIdentifyCommand(name, line, wildcards)
  if wildcards.format ~= "" and adb_options[wildcards.format] == nil then
    adbInfo("Unknown format " .. wildcards.format .. " using default")
  end
  local identify_format = adb_options[wildcards.format] or
                          (adb_options[wildcards.channel == "" and
                                       adb_options.cockpit.identify_format or adb_options.cockpit.identify_channel_format])
  local ctx = {
    channel = wildcards.channel,
    format = identify_format,
  }
  adbIdentifyItem("id " .. wildcards.id .. wildcards.worn, adbOnIdentifyCommandIdResultsReadyCB, ctx)
end

function adbOnIdentifyCommandIdResultsReadyCB(obj, ctx)
  adbProcessIdResults(obj, ctx)
end

function adbProcessIdResults(obj, ctx)
  if (obj.stats.name == nil) then
    adbDebug("item not found", 2)
    return
  end

  adbDebug(function()
    print("id results:")
    tprint(obj)
    print("bloot: ".. tostring(adbGetBlootLevel(obj.stats.name)))
    print("base name: ".. adbGetBaseColorName(obj.colorName))
  end, 3)

  --TODO: add to cache?

  local format = ctx.format
  if format.disechant_hyperlinks and ctx.channel == "" then
    format = copytable.deep(ctx.format)
    format.enchants_details = false
  end

  local message = adbIdReportGetItemString(obj, format)

  if format.location or format.bloot_diffs then
    local bloot = adbGetBlootLevel(obj.stats.name)
    local base_name = adbGetBaseColorName(obj.colorName)
    local base_item = adbCacheGetItemByNameAndFoundAt(base_name, obj.stats.foundat)
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

  if format.disechant_hyperlinks and ctx.channel == "" and
     obj.enchants ~= nil and adbEnchantsPresent(obj.enchants) then

    for k, v in ipairs(adb_enchants.order) do
      if obj.enchants[v] ~= nil then
        local report = adb_options.colors.enchants .. " " .. v
        report = adbIdReportAddValue(report, adbGetStatsGroupString(obj.enchants[v], adb_stat_groups.hrdr, true), "", adb_options.colors.default)
        report = adbIdReportAddValue(report, adbGetStatsGroupString(obj.enchants[v], adb_stat_groups.basics, true), "", adb_options.colors.default)
        if not obj.enchants[v].removable then
          report = adbIdReportAddValue(report, "TP only", "", adb_options.colors.bad)
        else
          report = report .. " " .. adb_options.colors.default .. "["
        end
        local styles = ColoursToStyles(report, adb_options.colors.default, ColourNameToRGB("black"), false, false)
        for _, v in ipairs(styles) do
          ColourTell(RGBColourToName(v.textcolour), RGBColourToName(v.backcolour), v.text)
        end

        if obj.enchants[v].removable then
          styles = ColoursToStyles(adb_options.colors.good .. "remove " .. v)
          local action = "disenchant " .. obj.stats.id .. " " .. v .. " confirm"

          if ctx.bagid ~= nil and ctx.bagid ~= "" then
            action = "get " .. obj.stats.id .. " " .. ctx.bagid .. "\n" ..
                     action ..
                     "\nput " .. obj.stats.id .. " " .. ctx.bagid
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

local adb_inv_data_queue = nil
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
  --TODO add default format
  --adb_options.cockpit.identify_format
  local identify_format = adb_options[wildcards.format] and adb_options[wildcards.format] or adb_options[adb_options.cockpit.aide_format]

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
  }
  adb_inv_data_queue = {}

  local add_id = (wildcards.id ~= "" and (" " .. wildcards.id) or "")

  if add_id ~= "" then
    -- If that's a non-existing container invdata will report: Item xxxxxxx not found.
    -- Abort busy state in this case.
    AddTriggerEx("AIDEFailedTrigger",
                "^Item" .. add_id .. " not found.$", "",
                trigger_flag.Replace + trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.OmitFromOutput + trigger_flag.OneShot + trigger_flag.Temporary,
                custom_colour.NoChange, 0, "", "adbInvDataNotFoundCB", sendto.scriptafteromit, 0);
  end

  Capture.tagged_output(
    "invdata" .. add_id,
    "{invdata" .. add_id .. "}",
    "{/invdata}",
    false,
    true,
    true,
    true,
    adbInvDataReadyCB,
    false
  )
end

function adbInvDataNotFoundCB()
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
      table.insert(adb_inv_data_queue, id)
    else
      adbErr("Can't find ID in invdata line " .. line)
    end
  end
  adbInfo("AIDE processing " .. #adb_inv_data_queue .. " items(s).")
  adbInvDataQueueDrain()
end

function adbInvDataQueueDrain()
  if #adb_inv_data_queue == 0 then
    adb_aide_busy = false
    adbInfo("AIDE finished.")
    return
  end
  --TODO: disable show_bloot_level while running this?
  --EnableTrigger("adbBlootNameTrigger", adb_options.cockpit.show_bloot_level)
  local item_id = table.remove(adb_inv_data_queue, 1)
  local cmd = "id " .. item_id
  if adb_aide_ctx.bagid ~= "" then
    cmd = "get " .. item_id .. " " .. adb_aide_ctx.bagid .. "\n" ..
          cmd ..
          "\nput " .. item_id .. " " .. adb_aide_ctx.bagid
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

  local passes = (has_enchant or not ctx.enchanted) and (has_removable_enchant or not ctx.removable) and (passed_enchant_check or not has_enchant_check)

  if ctx.IR ~= "" then
    passes = passes and (tonumber(ctx.IR) >= adbGetEnchantSum(obj.enchants["Illuminate"]) + adbGetEnchantSum(obj.enchants["Resonate"]))
  end

  if passes then
    adbProcessIdResults(obj, ctx)
    if ctx.command ~= "" then
      local command = ctx.command .. " " .. obj.stats.id
      if ctx.bagid ~= "" then
        command = "get " .. item_id .. " " .. ctx.bagid .. "\n" .. command
      end
      Execute(command)
    end
  end
  adbInvDataQueueDrain()
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
    ["luck"] = "luk",
  },
  hrdr = {
    order = {"dam", "hit"},
    ["hit"] = "hr",
    ["dam"] = "dr",
  },
  vitals = {
    order = {"hp", "mana", "moves"},
    ["hp"] = "hp",
    ["mana"] = "mn",
    ["moves"] = "mv",
  },
  resists = {
    order = {"allphys", "allmagic", "slash", "pierce", "bash", "acid", "cold", "energy",
             "holy", "electric", "negative", "shadow", "magic", "air", "earth", "fire",
             "light", "mental", "sonic", "water", "poison", "disease",
            },
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
    ["disease"] = "disease",
  },
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
      result = result .. (result:len() > 0 and " " or "")
               .. (stat < 0 and adb_options.colors.bad or adb_options.colors.good)
               .. ((show_plus and stat > 0) and "+" or "") .. tostring(stat)
               .. adb_options.colors.default .. group[v]
    end
  end
  return result
end

function adbGetSkillModsString(item, show_plus)
  local result = ""
  for k, v in pairs(item.skillMods) do
    result = result .. (result:len() > 0 and ", " or "")
             .. adb_options.colors.flags .. k .. " "
             .. (v < 0 and adb_options.colors.bad or adb_options.colors.good)
             .. ((show_plus and v > 0) and "+" or "") .. tostring(v)
             .. adb_options.colors.default
  end
  return result
end

function adbGetWeaponString(item, format)
  return adb_options.colors.weapon .. tostring(adbGetStatNumberSafe(item.stats.avedam)) .. adb_options.colors.default .. "avg "
         .. adb_options.colors.value .. adbGetStatStringSafe(item.stats.weapontype) .. " "
         .. (format.weapon_material and (adb_options.colors.value .. adbGetStatStringSafe(item.stats.material) .. " ") or "")
         .. adb_options.colors.value .. adbGetStatStringSafe(item.stats.damtype) .. " "
         .. adb_options.colors.value .. adbGetStatStringSafe(item.stats.specials)
end

function adbIdReportAddValue(report, value, label, color, show_plus)
  if value == nil or value == 0 or value == "" then
    return report
  end
  if report:len() > 0 then report = report .. " " end

  report = report .. adb_options.colors.default .. "[" .. color
           .. ((show_plus and type(value) == "number" and value > 0) and "+" or "") .. tostring(value)
           .. adb_options.colors.default .. label .. "]"
  return report
end

function adbIdReportAddLocationInfo(report, location)
  if location == nil then
    return report
  end

  if #location.mobs then
    report = report .. "\n" .. adb_options.colors.section .. " Looted from:"
  end

  for k, v in pairs(location.mobs) do
    report = report .. "\n" .. adb_options.colors.value .. " " .. v.colorName
             .. adb_options.colors.default .. " [" .. adb_options.colors.value .. v.zone .. adb_options.colors.default .. "] "
             .. "Room(s) [" .. adb_options.colors.value .. v.rooms .. adb_options.colors.default .. "]"
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

function adbGetEnchantsShortString(item)
  local res = ""
  for k, v in ipairs(adb_enchants.order) do
    if item.enchants[v] ~= nil then
      res = res .. adb_enchants[v]
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
      report = adbIdReportAddValue(report, adbGetStatsGroupString(enchants[v], adb_stat_groups.hrdr, true), "", adb_options.colors.default)
      report = adbIdReportAddValue(report, adbGetStatsGroupString(enchants[v], adb_stat_groups.basics, true), "", adb_options.colors.default)
      report = adbIdReportAddValue(report, enchants[v].removable and "removable" or "TP only", "", enchants[v].removable and adb_options.colors.good or adb_options.colors.bad)
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

function adbIdReportAddDiffString(report, diff, format)
  report = report .. "\n" .. adb_options.colors.section .. " Bloot changes:"
  if format.sections_name_newline then
    report = report .. "\n"
  end

  if (diff.stats.level ~= nil) then
    report = adbIdReportAddValue(report, adbGetStatNumberSafe(diff.stats.level), " lvl", adb_options.colors.level, true)
  end

  if (diff.stats.avedam ~= nil) then
    report = adbIdReportAddValue(report, adbGetStatNumberSafe(diff.stats.avedam), "avg", adb_options.colors.weapon, true)
  end

  if format.score then
    report = adbIdReportAddValue(report, diff.stats.score, "score", adb_options.colors.score, true)
  end
  report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.hrdr, true), "", adb_options.colors.default)
  if format.stats_total then
    report = adbIdReportAddValue(report, adbGetStatsGroupTotal(diff.stats, adb_stat_groups.basics), "stats", adb_options.colors.score, true)
  end
  if format.stats then
    report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.basics, true), "", adb_options.colors.default)
  end
  if format.vitals then
    report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.vitals, true), "", adb_options.colors.default)
  end
  if format.resists then
    report = adbIdReportAddValue(report, adbGetStatsGroupString(diff.stats, adb_stat_groups.resists, true), "", adb_options.colors.default)
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
  res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.hrdr), "", adb_options.colors.default)
  if format.stats_total then
    res = adbIdReportAddValue(res, adbGetStatsGroupTotal(item.stats, adb_stat_groups.basics), "stats", adb_options.colors.score)
  end
  if format.stats then
    res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.basics), "", adb_options.colors.default)
  end
  if format.vitals then
    res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.vitals), "", adb_options.colors.default)
  end
  if format.resists then
    res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.resists), "", adb_options.colors.default)
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
        res = adbIdReportAddValue(res, adbGetStatsGroupString(item.enchants, adb_stat_groups.hrdr, true), "", adb_options.colors.default)
        if format.stats_total then
          res = adbIdReportAddValue(res, adbGetStatsGroupTotal(item.enchants, adb_stat_groups.basics, true), "stats", adb_options.colors.score)
        end
        if format.stats then
          res = adbIdReportAddValue(res, adbGetStatsGroupString(item.enchants, adb_stat_groups.basics, true), "", adb_options.colors.default)
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
  Mythical = 18,
  Fabled = 19,
  Divine = 20,
  Godly = 21,
}

local adb_diff_fields = {"score", "weight", "worth", "avedam", "level"}
function adbDiffItems(item1, item2, ignore_enchants)
  local result = {stats={}}

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

  --TODO diff flags, material, weapon specific etc ?

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
adb_db_version = 2
adb_db = nil

local adb_db_special_fields = {
  dbid = true,
  colorName = true,
  zone = true,
  comment = true,
  identifyLevel = true,
  identifyVersion = true,
  skillMods = true,
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
      timestamp = os.time(),
    },
    location = {
      zone = row.zone,
      mobs = {},
    },
    enchants = {},
    skillMods = {},
    colorName = row.colorName,
    comment = row.comment,
    identifyLevel = row.identifyLevel,
    identifyVersion = row.identifyVersion,
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
        name = row["spells" .. i .. "name"],
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
      rowid = mob_row.dbid,
    }
    adbItemLocationAddMob(result, mob)
  end

  adbDebug("Resulting item:", 3)
  adbDebugTprint(result, 3)
  return result
end

function adbDbGetItem(color_name, zone)
  assert(color_name ~= nil and zone ~= nil)
  adbDebug("adbDbGetItem [" .. color_name .. "] [".. zone .. "]", 2)

  local result = nil
  local sql = string.format("SELECT * FROM items WHERE zone = %s AND colorName = %s;",
                            adbSqlTextValue(zone), adbSqlTextValue(color_name))
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
  adbDebug("adbDbGetItemByNameAndFoundAt [" .. color_name .. "] [".. found_at .. "]", 2)

  local result = nil
  local sql = string.format("SELECT * FROM items WHERE foundAt = %s AND colorName = %s;",
                            adbSqlTextValue(found_at), adbSqlTextValue(color_name))
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

function trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

-- DB exec functions are borrowed from aard_GMCP_mapper.xml
function adbDbCheck(code, msg, query)
  if code ~= sqlite3.OK and    -- no error
     code ~= sqlite3.ROW and   -- completed OK with another row of data
     code ~= sqlite3.DONE then -- completed OK, no more rows
        local err = msg.."\n\nCODE: "..code.."\nQUERY: "..query.."\n"
        adb_db:exec("ROLLBACK")  -- rollback any transaction to unlock the database
        error(err, 3)            -- show error in caller's context
  end -- if
end -- dbcheck

adb_db_max_retries = 10
adb_db_sleep_duration = 1
function adbDbCheckExecute(query)
  local code = adb_db:exec(query)
  local count = 0
  while ((code == sqlite3.BUSY) or (code == sqlite3.LOCKED)) and (count < adb_db_max_retries) do
    adbInfo(string.format("DB ERROR: %s. Retrying %d times: `%s`", adb_db:errmsg():upper(), adb_db_max_retries, query))
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
     adbInfo(string.format("DB ERROR: %s. Retrying %d times: `%s`", adb_db:errmsg():upper(), adb_db_max_retries, query))
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
  adbDebug("adbDbAddItem [" .. item.colorName .. "] [".. item.location.zone .. "] [" .. item.stats.foundat .. "]", 2)

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

      sql = string.format("INSERT INTO item_mobs (item_dbid, mob_dbid) VALUES (%d, %d);", item.cache.rowid, v.rowid)
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
  adbDebug("adbDbUpdateItem [" .. item.cache.rowid .. "] [".. item.colorName .. "] [".. item.location.zone .. "] [" .. item.stats.foundat .. "]", 2)
  adbDbCheckExecute("DELETE FROM items WHERE dbid = " .. item.cache.rowid .. ";")

  -- Sanity check in case cache was screwed up during development
  if adb_debug_level >= 2 then
    local dbitem = adbDbGetItem(item.colorName, item.location.zone)
    if dbitem ~= nil then
      adbDebug("Item still exists in DB " .. dbitem.cache.rowid)
      adbDbCheckExecute("DELETE FROM items WHERE dbid = " .. dbitem.cache.rowid .. ";")
    end
  end

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
  location = true,
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
  adbDebug("adbDbSave", 1)
  adbDbCheckExecute("PRAGMA wal_checkpoint(FULL);")

  adbDbSyncCache()

  if adb_db:isopen() then
    adb_db:close()
    adbDbOpen()
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
  ColourNote("white", "red", "Please don't report this to Athlau with a couple pages of screen output before this message ... unless I asked you")
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
        if not was_in_combat then adbDebug("-> in combat", 4) end
        was_in_combat = true
      elseif state == "3" and was_in_combat then
        adbDebug("-> out of combat", 4)
        was_in_combat = false       
        adbDrainStacks()
      end
    end
  end
end

function adbOnHelp()
  AnsiNote(ColoursToANSI(world.GetPluginInfo(world.GetPluginID(), 3)))
end

function OnPluginInstall()
  adbOnHelp()
  OnPluginEnable()
end

function OnPluginEnable()
  OnPluginConnect()
end

function OnPluginConnect()
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
