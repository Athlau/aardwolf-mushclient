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
local adb_recent_cache = {}

function adbGetCacheKey(name, zone)
  return zone.."->"..name
end

function adbRecentCacheAdd(item)
  local key = adbGetCacheKey(item.colorName, item.zone)
  if adb_recent_cache[key] == nil then
    adb_recent_cache[key] = item
    adbDebug("Added to cache:", 2)
    adbDebugTprint(item, 2)
  else
    adbDebug(item.colorName.."already in cache, todo: update timestamp, rooms etc", 1)
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
  adbIdentifyItem(adb_drain_inv_item.id, adbDrainIdResultsReadyCB)
end

function adbDrainIdResultsReadyCB(item)
  if adb_drain_inv_item.id ~= item.stats.id then
    adbErr("adbDrainIdResultsReadyCB -> somethis is off expected id "..tostring(adb_drain_inv_item.id)..
           "!= "..tostring(item.stats.id))
    return
  end
  local t = copytable.deep(item)
  t.mob = adb_drain_loot_item.mob
  t.colorMob = adb_drain_loot_item.mob
  t.zone = adb_drain_loot_item.zone
  t.room = adb_drain_loot_item.room
  adbRecentCacheAdd(t)

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

  local name_start, name_end
  _, name_start = colored_line:find("^@wYou get %d+ %* ") 
  if name_start == nil then 
    _, name_start = colored_line:find("^@wYou get ")
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
  Note("got id results")
  tprint(obj)
end

function adbOnHelp()
  world.Note(world.GetPluginInfo(world.GetPluginID(), 3))
end

------ Misc ----
local adb_debug_level = 2
function adbDebug(message, level) 
  if level == nil or level <= adb_debug_level then
    Note("ADB Debug: "..message)
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
end

function OnPluginConnect()
  adbLoadOptions()
end

function OnPluginDisable()
end

function OnPluginSaveState()
  adbSaveOptions()
end
