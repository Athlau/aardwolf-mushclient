require "tprint"
require "var"
require "serialize"
require "gmcphelper"
require "wait"
dofile(GetPluginInfo(GetPluginID(), 20).."adb_id.lua")

local adb_options = {}

function adbGetDefaultOptions()
  local default_options = {
    version = 1,
    auto_actions = {
      on_bloot_looted_cmd = "gtell just looted;aid %item gtell;aid %item",
      on_bloot_looted_lua = "if %bloot>5 then SendNoEcho(\"say Looted good bloot \" .. tostring(%bloot) .. \" \" .. %name) end",
      on_normal_looted_cmd = "echo could have done \"put %item bag\" here",
      on_normal_looted_lua = "if %gpp<200 and (%type==\"Armor\" or %type==\"Weapon\" or %type==\"Trash\" or %type==\"Treasure\") then SendNoEcho(\"drop %item\") else SendNoEcho(\"put %item 2785187925\") end",
    },
    cockpit = {
      update_db_on_loot = true,
      show_db_updates = true,
      show_db_cache_hits = true,
      show_bloot_level = true,
      enable_auto_actions = true,
      identify_command = "id",
      identify_format = "format.full",
      identify_channel_format = "format.brief",
      cache_added_format = "format.full",
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
      bloot_diffs = true
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
      bloot_diffs = false
    },
  }
  return default_options
end

function adbCheckOptions()
  if adb_options.version ~= adbGetDefaultOptions().version then
    adbInfo("ADB options stored are too old, resetting to defaults!")
    adb_options = copytable.deep(adbGetDefaultOptions())
  end

  EnableTrigger("adbBlootNameTrigger", adb_options.cockpit.show_bloot_level)
  EnableTriggerGroup("adbLootTriggerGroup", adb_options.cockpit.update_db_on_loot or adb_options.cockpit.enable_auto_actions)
end

function adbLoadOptions()
  adb_options = loadstring(string.format("return %s", var.config or serialize.save_simple(adbGetDefaultOptions())))()
  adbCheckOptions()
  adbSaveOptions()
end

function adbSaveOptions()
  var.config = serialize.save_simple(adb_options)
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

------ recent cache ------
local adb_recent_cache = {version = 1.0}

function adbCacheSave()
  var.recent_cache = serialize.save_simple(adb_recent_cache)
end

function adbCacheLoad()
  if var.recent_cache ~= nil then
    adb_recent_cache = loadstring("return " .. var.recent_cache)()
    adbInfo("Loaded cache version " .. adb_recent_cache.version)
    adbDebug(function()
      local count = 0
      for _, _ in pairs(adb_recent_cache) do
        count = count + 1
      end
      Note(tostring(count - 1) .. " items in cache.")
    end, 1)
  end
end

function adbCacheGetKey(name, zone)
  return zone.."->"..name
end

function adbCacheGetItem(color_name, zone)
  return adb_recent_cache[adbCacheGetKey(color_name, zone)]
end

function adbCacheGetItemByName(color_name)
  for k, v in pairs(adb_recent_cache) do
    if type(v) ~= "table" then
      -- skip version field
    elseif v.colorName == color_name then
      return v
    end
  end
  return nil
end

function adbCacheAdd(item)
  local key = adbCacheGetKey(item.colorName, item.location.zone)
  local cache_item = adbCacheGetItem(item.colorName, item.location.zone)
  if cache_item == nil then
    --TODO: limit cache size, evict oldest etc
    adb_recent_cache[key] = item
    adbDebug("Added to cache:", 3)
    adbDebugTprint(item, 3)
    if adb_options.cockpit.show_db_updates then
      AnsiNote(ColoursToANSI("@CADB added to cache:\n" .. adbIdReportGetItemString(item, adb_options[adb_options.cockpit.cache_added_format])))
    end
  else
    adbDebug(item.colorName.." already in cache, todo: update timestamp", 3)
    --TODO update timestamp etc
    if adb_options.cockpit.show_db_updates then
      AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo("@CADB updated cache item " .. cache_item.colorName .. "@C :", cache_item.location)))
    end
  end
end
------ invitem and looted items stacks ------
local adb_invitem_stack = {}
local adb_looted_stack = {}

function adbReplacePatterns(cmd, id, bloot, base_item, lua)
  adbDebug("adbReplacePatterns:" .. cmd, 2)
  for k, v in pairs(base_item.stats) do
    -- we might be getting stats from chached item, so don't use it's id
    if k ~= "id" then
      local value = v
      if lua and type(value) == "string" then
        value = value:gsub("[\"\\]", "\\%1")
        value = "\"" .. value .. "\""
      end
      cmd = cmd:gsub("%%%f[%a]" .. k .. "%f[%A]", value)
    end
  end
  cmd = cmd:gsub("%%%f[%a]" .. "item" .. "%f[%A]", id)
  cmd = cmd:gsub("%%%f[%a]" .."bloot" .. "%f[%A]", bloot)

  local gpp = base_item.stats.worth == 0 and 99999999 or (base_item.stats.worth / base_item.stats.weight)
  cmd = cmd:gsub("%%%f[%a]" .."gpp" .. "%f[%A]", gpp)

  adbDebug("replaced cmd:" .. cmd, 2)
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
  end

  if not adb_options.cockpit.enable_auto_actions then
    return
  end

  local cmd
  cmd = adb_options.auto_actions.on_normal_looted_lua
  if cmd ~= "" then
    cmd = adbReplacePatterns(cmd, id, bloot, item, true)
    local lua = loadstring(cmd)
    if lua ~= nil then
      lua()
    else
      adbInfo("Failed to compile lua " .. cmd)
    end
  end
  cmd = adb_options.auto_actions.on_normal_looted_cmd
  if cmd ~= "" then
    cmd = adbReplacePatterns(cmd, id, bloot, item)
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
  if base_item == nil then
    adbDebug("base item not found, ignoring bloot scripts", 1)
    return
  end

  local cmd
  cmd = adb_options.auto_actions.on_bloot_looted_lua
  if cmd ~= "" then
    cmd = adbReplacePatterns(cmd, id, bloot, base_item, true)
    local lua = loadstring(cmd)
    if lua ~= nil then
      lua()
    else
      adbInfo("Failed to compile lua " .. cmd)
    end
  end
  cmd = adb_options.auto_actions.on_bloot_looted_cmd
  if cmd ~= "" then
    cmd = adbReplacePatterns(cmd, id, bloot, base_item)
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

  cache_item = adbCacheGetItem(adb_drain_loot_item.colorName, adb_drain_loot_item.zone)
  if cache_item ~= nil then
    adbDebug(adb_drain_loot_item.colorName.." already in cache, updating mobs/rooms info", 4)
    local old_location = adbIdReportAddLocationInfo("", cache_item.location)
    adbItemLocationAddMob(cache_item, adbCreateMobFromLootItem(adb_drain_loot_item))
    local new_location = adbIdReportAddLocationInfo("", cache_item.location)
    -- TODO update timestamp?
    adbDebugTprint(cache_item, 4)
    if old_location ~= new_location then
      if adb_options.cockpit.show_db_updates then
        AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo("@CADB updated cache item @w[" .. cache_item.colorName .. "@w] @C:", cache_item.location)))
      end
    elseif adb_options.cockpit.show_db_cache_hits then
      AnsiNote(ColoursToANSI("@CADB item already in cache: @w[" .. cache_item.colorName .. "@w]"))
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
  if ctx.drain_inv_item.id ~= item.stats.id then
    adbErr("adbDrainIdResultsReadyCB -> something is off expected id "..tostring(ctx.drain_inv_item.id)..
           "!= "..tostring(item.stats.id))
    adbDrainOne()
    return
  end

  -- TODO: not sure if "same" items could be carried by mobs in different zones
  -- for now going to have location.zone which is set to first mob's zone
  local t = copytable.deep(item)
  t.location = {
    zone = ctx.drain_loot_item.zone,
    mobs = {},
  }
  adbItemLocationAddMob(t, adbCreateMobFromLootItem(ctx.drain_loot_item))
  adbCacheAdd(t)
  adbOnItemLooted(item.stats.id, item)
  adbDrainOne()
end

function adbLootedStackRemoveLast(name)
  adbDebug("adbLootedStackRemoveLast "..name, 5)
  if adb_looted_stack[#adb_looted_stack].name == name then
    table.remove(adb_looted_stack)
   else
    adbErr("Looted stack last ["..adb_looted_stack[#adb_looted_stack].name.."] doesn't match provided name ["..
           name.."]")
  end
end

function adbLootedStackPush(item)
  adbDebug("adbLootedStackPush "..item.colorName, 5)
  -- {invitem} messages comes before the actual loot message,
  -- so there should be an item with same name in invitem stack already.
  if adb_invitem_stack[#adb_looted_stack + 1] ~= nil and 
     adb_invitem_stack[#adb_looted_stack + 1].name == item.name then
    table.insert(adb_looted_stack, item)
  else
    -- invmon events happen when we receive items from any source and not just looting from corpse
    -- let's try to see if we can find a match down the stack
    -- another alternative would be to write triggers to all those buy/auction/give etc messages, but i'm lazy
    for i = #adb_looted_stack + 2, #adb_invitem_stack, 1 do
      if adb_invitem_stack[i].name == item.name then
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
    Note("pushing:")
    tprint(item)
    adbOnAdbDebugDump()
    adbErr("Sync is broken between invitem/looted stacks.")
    
    adb_invitem_stack = {}
    adb_looted_stack = {}
  end
end

function adbInvitemStackRemoveLast(name)
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
    return
  end

  local color_name, color_mob
  local colored_line = StylesToColours(styles)
  adbDebug("adbOnItemLootedTrigger colored_line: "..colored_line, 5)

  -- it seems that sometimes there's leftover color code from previous line
  -- at least I saw "@x248You get @Rminotaur clan @x069markings@w..."
  local name_start, name_end
  _, name_start = colored_line:find("^@[%a%d]+You get %d+ %* ") 
  if name_start == nil then 
    _, name_start = colored_line:find("^@[%a%d]+You get ")
    if name_start == nil then
      adbErr("Can't parse name start: ["..colored_line.."]")
      return
    end
  end
  name_end = colored_line:find("@w from the %a+ corpse of ") or colored_line:find(" from the %a+ corpse of ")
  if name_end == nil then
    adbErr("Can't parse name end: ["..colored_line.."]")
    return
  end
  color_name = colored_line:sub(name_start + 1, name_end - 1)

  local mob_start, mob_end
  _, mob_start = colored_line:find("@w from the %a+ corpse of ")
  if mob_start == nil then
    _, mob_start = colored_line:find(" from the %a+ corpse of ")
    if mob_start == nil then
      adbErr("Can't parse mob start: ["..colored_line.."]")
      return
    end
  end
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
end

function adbOnItemLootedCrumblesTrigger(name, line, wildcards)
  adbDebug("adbOnItemLootedCrumblesTrigger "..name, 5)
  adbInvitemStackRemoveLast(wildcards.item)
  adbLootedStackRemoveLast(wildcards.item) 
end

function adbOnInvitemTrigger(name, line, wildcards)
  adbDebug("invitem " .. line, 5)
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
  --Note("recent cache:")
  --tprint(adb_recent_cache)
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

  local message = adbIdReportGetItemString(obj, ctx.format)

  --TODO: add to cache?

  if ctx.format.location or ctx.format.bloot_diffs then
    local bloot = adbGetBlootLevel(obj.stats.name)
    local base_name = adbGetBaseColorName(obj.colorName)
    local base_item = adbCacheGetItemByName(base_name)
    if base_item ~= nil then
      if ctx.format.bloot_diffs and bloot > 0 then
        local diff = adbDiffItems(base_item, obj, true)
        message = adbIdReportAddDiffString(message, diff, ctx.format)
      end
      if ctx.format.location then
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
end

------ Identify results reporting ------
function adbGetStatNumberSafe(stat)
  return stat ~= nil and stat or 0
end

function adbGetStatStringSafe(stat)
  return stat ~= nil and stat or ""
end

local adb_stat_groups = {
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

function adbIdReportAddDiffString(report, diff, format)
  report = report .. "\n" .. adb_options.colors.section .. " Bloot changes:\n"

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
  res = res .. (adb_options.cockpit.show_bloot_level and adbAddBlootLevel(item.colorName) or item.colorName)
  if format.level then
    res = adbIdReportAddValue(res, item.stats.level, " lvl", adb_options.colors.level)
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

  if format.weight then
    res = adbIdReportAddValue(res, item.stats.weight, "wgt", adb_options.colors.value)
  end
  if format.worth then
    res = adbIdReportAddValue(res, item.stats.worth, "g", adb_options.colors.value)
  end
  if format.enchants_sir then
    res = adbIdReportAddValue(res, adbGetEnchantsShortString(item), "", adb_options.colors.enchants)
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

  if format.location then
    res = adbIdReportAddLocationInfo(res, item.location)
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

local adb_diff_fields = {"score", "weight", "worth", "avedam"}
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
  color_line = colored_line:gsub("%((@[%a%d]+)" .. wildcards.bloot, "%(%1" .. bloot, 1)
  AnsiNote(ColoursToANSI(color_line))
end

------ Debug ------
local adb_debug_level = 1
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
local was_in_combat = false
function OnPluginBroadcast(msg, id, name, text)
  if (id == '3e7dedbe37e44942dd46d264') then   
    if (text == "char.status") then
      -- 3 - Player fully active and able to receive MUD commands
      -- 8 - Player in combat
      state = gmcp("char.status.state")
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
  adbLoadOptions()
  adbCacheLoad()
end

function OnPluginConnect()
  adbLoadOptions()
  adbCacheLoad()
end

function OnPluginDisable()
end

function OnPluginSaveState()
  adbSaveOptions()
  adbCacheSave()
end
