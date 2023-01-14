require "tprint"
require "var"
require "serialize"
require "gmcphelper"
require "wait"
require "gmcphelper"
dofile(GetPluginInfo(GetPluginID(), 20).."adb_id.lua")

local adb_options = {}

function adbGetDefaultOptions()
  local default_options = {
    auto_id_received_items = true
  }
  return default_options
end

function adbCheckOptions()
end

function adbLoadOptions()
  adb_options = loadstring(string.format("return %s", var.config or serialize.save_simple(adbGetDefaultOptions())))()
  --TEMP
  adb_options = loadstring(string.format("return %s", serialize.save_simple(adbGetDefaultOptions())))()
  adbCheckOptions()
  adbSaveOptions()
end

function adbSaveOptions()
  var.config = serialize.save_simple(adb_options)
end

------ recent cache ------
local adb_recent_cache = {version = 1.0}

function adbCacheSave()
  var.recent_cache = serialize.save_simple(adb_recent_cache)
end

function adbCacheLoad()
  if var.recent_cache ~= nil then
    adb_recent_cache = loadstring("return " .. var.recent_cache)()
    adbDebug("Loaded cache version " .. adb_recent_cache.version, 2)
  end
end

function adbCacheGetKey(name, zone)
  return zone.."->"..name
end

function adbCacheGetItem(color_name, zone)
  return adb_recent_cache[adbCacheGetKey(color_name, zone)]
end

function adbCacheAdd(item)
  local key = adbCacheGetKey(item.colorName, item.location.zone)
  local cache_item = adbCacheGetItem(item.colorName, item.location.zone)
  if cache_item == nil then
    adb_recent_cache[key] = item
    adbDebug("Added to cache:", 3)
    adbDebugTprint(item, 3)
    AnsiNote(ColoursToANSI("\nADB added to cache:\n" .. adbIdReportGetItemString(item)))   
  else
    adbDebug(item.colorName.." already in cache, todo: update timestamp", 3)
    AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo("\nADB updated cache item " .. cache_item.colorName .. " :", cache_item.location)))
  end
end
------ invitem and looted items stacks ------
local adb_invitem_stack = {}
local adb_looted_stack = {}

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

local adb_drain_inv_item, adb_drain_loot_item
function adbDrainOne()
  if #adb_invitem_stack == 0 and #adb_looted_stack > 0 then
    adbErr("adbDrainOne -> invitem stack is empty while looted stack is not!?")
    adbOnAdbDebugDump()
    return
  elseif #adb_looted_stack == 0 then
    adb_draining = false
    return
  end

  adb_drain_inv_item = table.remove(adb_invitem_stack, 1)
  adb_drain_loot_item = table.remove(adb_looted_stack, 1)

  if adb_drain_inv_item.name ~= adb_drain_loot_item.name then
    adbErr("adbDrainOne -> inv.name "..adb_drain_inv_item.name.." != "..adb_drain_loot_item.name)
    adb_draining = false
    return
  end

  if adbGetBlootLevel(adb_drain_loot_item.name) > 0 then
    -- TODO option do identify and show bloot diff or something like that here
    adbDebug("Ignoring bloot " .. adb_drain_loot_item.name, 4)
    adbDrainOne()
    return
  end

  cache_item = adbCacheGetItem(adb_drain_loot_item.colorName, adb_drain_loot_item.zone)
  if cache_item ~= nil then
    adbDebug(adb_drain_loot_item.colorName.." already in cache, updating mobs/rooms info", 4)
    adbItemLocationAddMob(cache_item, adbCreateMobFromLootItem(adb_drain_loot_item))
    -- TODO update timestamp
    adbDebugTprint(cache_item, 4)
    AnsiNote(ColoursToANSI(adbIdReportAddLocationInfo("\nADB updated cache item " .. cache_item.colorName .. " :", cache_item.location)))
    adbDrainOne()
    return
  end

  adbIdentifyItem(adb_drain_inv_item.id, adbDrainIdResultsReadyCB)
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

function adbDrainIdResultsReadyCB(item)
  if adb_drain_inv_item.id ~= item.stats.id then
    adbErr("adbDrainIdResultsReadyCB -> something is off expected id "..tostring(adb_drain_inv_item.id)..
           "!= "..tostring(item.stats.id))
    adbDrainOne()
    return
  end

  --if adbGetBlootLevel(item.name)

  -- TODO: not sure if "same" items could be carried by mobs in different zones
  -- for now going to have location.zone which is set to first mob's zone
  local t = copytable.deep(item)
  t.location = {
    zone = adb_drain_loot_item.zone, 
    mobs = {},
  }
  adbItemLocationAddMob(t, adbCreateMobFromLootItem(adb_drain_loot_item))
  adbCacheAdd(t)
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
  adbDebug("invitem "..line, 5)
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
  tprint(adb_recent_cache)
  Note("-------------------------------------")
end

function adbOnIdentifyCommand(name, line, wildcards)
  adbIdentifyItem(wildcards.id, adbOnIdentifyCommandIdResultsReadyCB)
end

function adbOnIdentifyCommandIdResultsReadyCB(obj)
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

  AnsiNote(ColoursToANSI(adbIdReportGetItemString(obj)))
  --SendNoEcho("echo " .. str)
end

function adbOnHelp()
  world.Note(world.GetPluginInfo(world.GetPluginID(), 3))
end

------ Identify results reporting ------
local adb_id_colors = {
  default = "@D",
  value = "@W",
  score = "@Y",
  good = "@G",
  bad = "@R",
  flags = "@C",
  weapon = "@M",
  level = "@C",
  looted = "@B",
}

function adbGetStatNumberSafe(stat)
  return stat ~= nil and stat or 0
end

function adbGetStatStringSafe(stat)
  return stat ~= nil and stat or ""
end

local adb_stat_groups = {
  basics = {
    ["str"] = "str",
    ["int"] = "int",
    ["wis"] = "wis",
    ["dex"] = "dex",
    ["con"] = "con",
    ["luck"] = "luk",
  },
  hrdr = {
    ["hit"] = "hr",
    ["dam"] = "dr",
  },
  vitals = {
    ["hp"] = "hp",
    ["mana"] = "mn",
    ["moves"] = "mv",
  },
  resists = {
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

function adbGetStatsGroupString(stats, group)
  local result = ""
  for k, v in pairs(group) do
    local stat = adbGetStatNumberSafe(stats[k])
    if stat ~= 0 then
      result = result .. (result:len() > 0 and " " or "")
               .. (stat < 0 and adb_id_colors.bad or adb_id_colors.good) .. tostring(stat)
               .. adb_id_colors.default .. v
    end
  end
  return result
end

function adbGetWeaponString(item)
  return adb_id_colors.weapon .. adbGetStatStringSafe(item.stats.avedam) .. adb_id_colors.default .. "avg "
         .. adb_id_colors.value .. adbGetStatStringSafe(item.stats.weapontype) .. " "
         .. adb_id_colors.value .. adbGetStatStringSafe(item.stats.material) .. " "
         .. adb_id_colors.value .. adbGetStatStringSafe(item.stats.damtype) .. " "
         .. adb_id_colors.value .. adbGetStatStringSafe(item.stats.specials)
end

function adbIdReportAddValue(report, value, label, color)
  if value == nil or value == 0 or value == "" then
    return report
  end
  if report:len() > 0 then report = report .. " " end

  report = report .. adb_id_colors.default .. "[" .. color .. tostring(value) 
           .. adb_id_colors.default .. label .. "]"
  return report
end

function adbIdReportAddLocationInfo(report, location)
  if location == nil then
    return report
  end

  if #location.mobs then
    report = report .. adb_id_colors.looted .. "\n Looted from:"
  end

  for k, v in pairs(location.mobs) do
    report = report .. "\n " .. adb_id_colors.value .. v.colorName
             .. adb_id_colors.default .. " [" .. adb_id_colors.value .. v.zone .. adb_id_colors.default .. "] "
             .. "Room(s) [" .. adb_id_colors.value .. v.rooms .. adb_id_colors.default .. "]"
  end

  return report
end

function adbIdReportGetItemString(item)
  local res = ""
  res = res .. item.colorName
  res = adbIdReportAddValue(res, item.stats.level, " lvl", adb_id_colors.level)
  res = adbIdReportAddValue(res, item.stats.wearable, "", adb_id_colors.value)

  if (item.stats.type == "Weapon") then
    res = adbIdReportAddValue(res, adbGetWeaponString(item), "", adb_id_colors.value)
  end

  res = adbIdReportAddValue(res, item.stats.score, "score", adb_id_colors.score)
  res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.hrdr), "", adb_id_colors.default)
  res = adbIdReportAddValue(res, adbGetStatsGroupTotal(item.stats, adb_stat_groups.basics), "stats", adb_id_colors.score)
  res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.basics), "", adb_id_colors.default)
  res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.vitals), "", adb_id_colors.default)
  res = adbIdReportAddValue(res, adbGetStatsGroupString(item.stats, adb_stat_groups.resists), "", adb_id_colors.default)

  res = adbIdReportAddValue(res, item.stats.weight, "wgt", adb_id_colors.value)
  res = adbIdReportAddValue(res, item.stats.worth, "g", adb_id_colors.value)

  res = res .. "\n"
  res = adbIdReportAddValue(res, item.stats.flags, "", adb_id_colors.value)
  res = adbIdReportAddValue(res, item.stats.foundat, "", adb_id_colors.value)

  res = adbIdReportAddLocationInfo(res, item.location)

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
  return color_name:gsub("^@[%a%d]+%(@[%a%d]+%a+@[%a%d]+%)@[%a%d]+ ", "")
end

------ Debug ------
local adb_debug_level = 2
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
  ColourNote("white", "red", "ADB ERROR: "..message)
  ColourNote("white", "red", "Please report this to Athlau with a couple pages of screen output before this message")
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

function tcOnHelp()
  world.Note(world.GetPluginInfo(world.GetPluginID(), 3))
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
