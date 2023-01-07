require "check"
require "copytable"
dofile(GetInfo(60) .. "aardwolf_colors.lua")

-- This is mostly a copy-paste from dinv plugin identification code

idObject = {stats={}}
idReadyCallback = nil
initialized = false

function adbIdentifyItem(id, ready_callback)
  adbIdentifyInit()
  idReadyCallback = ready_callback

  local objId = ""
-- Clear out fields that may be left over from a previous identification.  Otherwise, we may
-- be left with incorrect values if a temper or envenom added stats to the item previously.
  idObject.stats = {}

  EnableTrigger(inv.items.trigger.itemIdStartName, true)
  SendNoEcho("id "..id.."\necho {adbIdentifyEnd}")
end

inv = {}
inv.items = {}
inv.items.trigger = {}
inv.items.trigger.itemIdStartName = "adrlInvItemsTriggerIdStart"
inv.items.trigger.itemIdStatsName = "adrlInvItemsTriggerIdStats"
inv.items.trigger.itemIdEndName   = "adrlInvItemsTriggerIdEnd"

drlTriggerFlagsBaseline = trigger_flag.Enabled + trigger_flag.RegularExpression +
                          trigger_flag.Replace + trigger_flag.KeepEvaluating

function adbIdentifyInit()
  if initialized then
    return
  end

  initialized = true
  -- Trigger on the start of an identify-ish command (lore, identify, object read, bid, lbid, etc.)
  check (AddTriggerEx(inv.items.trigger.itemIdStartName,
                      "^(" ..
                         ".-----------------------------------------------------------------.*|" ..
                         "Current bid on this item is.*|"              ..
                         "You do not have that item.*|"                ..
                         "You dream about being able to identify.*|"   ..
                         ".*does not have that item for sale.*|"       ..
                         "There is no auction item with that id.*|"    ..
                         ".*currently holds no inventory.*|"           ..
                         ".* is closed.|"                              ..
                         "There is no marketplace item with that id.*" ..
                      ")$",
                      "inv.items.trigger.itemIdStart(\"%1\")",
                      drlTriggerFlagsBaseline + trigger_flag.OmitFromOutput,
                      custom_colour.Custom11, 0, "", "", sendto.script, 0))
  check (EnableTrigger(inv.items.trigger.itemIdStartName, false)) -- default to off

  -- Trigger on one of the detail/stat lines of an item's id report (lore, identify, bid, etc.)
  check (AddTriggerEx(inv.items.trigger.itemIdStatsName,
                      "^(" ..
                         "\\| .*\\||" ..
                         ".*A full appraisal will reveal further information on this item.|" ..
                         "\\+-*\\+|"..
                      ")$",
                      "",
                      drlTriggerFlagsBaseline + trigger_flag.OmitFromOutput,
                      custom_colour.NoChange, 0, "", "adbOnItemIdStatsLine", sendto.script, 0))
  check (EnableTrigger(inv.items.trigger.itemIdStatsName, false)) -- default to off
end

function adbOnItemIdStatsLine(name, line, wildcards, styles)
  -- call dinv original processing function
  inv.items.trigger.itemIdStats(line)

  -- get the colored item name
  if line:find("Name%s+:%s+(.-)%s*|$") then
    local colored_line = StylesToColours(styles)
    local name_start, name_end
    _, name_start = colored_line:find("Name@w%s+:%s+")
    name_end = colored_line:find("@w%s*|$") or colored_line:find("%s*|$")
    idObject.colorName = colored_line:sub(name_start + 1, name_end - 1)
  end
end

function inv.items.trigger.itemIdStart(line)
  if (line == "You do not have that item.") or
    string.find(line, "currently holds no inventory") or
    string.find(line, "There is no auction item with that id") or
    string.find(line, "There is no marketplace item with that id") or
    string.find(line, "does not have that item for sale") then
    inv.items.trigger.itemIdEnd()
    return
  end -- if

  EnableTrigger(inv.items.trigger.itemIdStartName, false)
  -- Start watching for stat lines in the item description
  EnableTrigger(inv.items.trigger.itemIdStatsName, true)

  -- Watch for the end of the item description so that we can stop scanning
  AddTriggerEx(inv.items.trigger.itemIdEndName,
               "^{adbIdentifyEnd}$",
               "inv.items.trigger.itemIdEnd()",
               drlTriggerFlagsBaseline + trigger_flag.OmitFromOutput + trigger_flag.OneShot,
               custom_colour.Custom11,
               0, "", "", sendto.script, 0)
end

function inv.items.trigger.itemIdEnd()
  EnableTrigger(inv.items.trigger.itemIdStatsName, false)
  idReadyCallback(copytable.deep(idObject))
end

dbot = {}
function dbot.debug(message)
  --Note(message)
end

function dbot.tonumber(numString)
  noCommas = string.gsub(numString, ",", "")
  return tonumber(noCommas)
end -- dbot.tonumber

function inv.items.setStatField(objId, field, value) 
  assert(objId ~= nil, "inv.items.setStatField: nil objId parameter")
  assert(field ~= nil, "inv.items.setStatField: nil field parameter for item " .. objId)
  assert(value ~= nil, "inv.items.setStatField: nil value parameter for item " .. objId)

  idObject.stats[field] = value
end -- inv.items.setStatField

function inv.items.getStatField()
  return idObject.stats[field]
end

inv.items.identifyPkg = {}
inv.items.identifyPkg.objId = ""
----------------------------------------------------------------------------------------
-- Try to not modify anything below this line. It's an exact copy-pase of dinv functions
-- This way it should be easier to keep up to date with dinv code.
----------------------------------------------------------------------------------------

function dbot.isWordInString(word, field)
  if (word == nil) or (word == "") or (field == nil) or (field == "") then
    return false
  end -- if

  for element in field:gmatch("%S+") do
    if (string.lower(word) == string.lower(element)) then
      return true
    end -- if
  end -- for

  return false
end -- dbot.isWordInString

function dbot.mergeFields(field1, field2)
  local mergedField = field1 or ""

  if (field2 ~= nil) and (field2 ~= "") then
    for word in field2:gmatch("%S+") do
      if (not dbot.isWordInString(word, field1)) then
        mergedField = mergedField .. " " .. word
      end -- if
    end -- for
  end -- if

  return mergedField
end -- dbot.mergeFields

----------------------------------------------------------------------------------------------------
-- Definitions for fields in identified items
----------------------------------------------------------------------------------------------------

inv.stats                 = {}
inv.stats.id              = { name = "id",
                              desc = "Unique identifier for the item" }
inv.stats.name            = { name = "name",
                              desc = "List of words in the name of the item" }
inv.stats.level           = { name = "level",
                              desc = "Level at which you may use the item (doesn't account for tier bonuses)" }
inv.stats.weight          = { name = "weight",
                              desc = "Base weight of the item" }
inv.stats.wearable        = { name = "wearable",
                              desc = "The item is wearable.  Run \"@Gwearable@W\" to see a list of locations." }
inv.stats.score           = { name = "score",
                              desc = "Item's score based on aard's priorities: see \"@Gcompare set@W\"" }
inv.stats.keywords        = { name = "keywords",
                              desc = "List of keywords representing the item" }
inv.stats.type            = { name = "type",
                              desc = "Type of item: see \"@Ghelp eqdata@W\" to see available types" }
inv.stats.worth           = { name = "worth",
                              desc = "How much gold this item is worth" }
inv.stats.flags           = { name = "flags",
                              desc = "List of flags assigned to the item" }
inv.stats.affectMods      = { name = "affectMods",
                              desc = "List of effects given by the item" }
inv.stats.material        = { name = "material",
                              desc = "Specifies what the item is made of" }
inv.stats.foundAt         = { name = "foundAt",
                              desc = "The item was found at this area" }
inv.stats.ownedBy         = { name = "ownedBy",
                              desc = "Character who owns this item" }
inv.stats.clan            = { name = "clan",
                              desc = "If this is a clan item, this indicates which clan made it" }
inv.stats.spells          = { name = "spells",
                              desc = "Spells that this item can cast" }
inv.stats.leadsTo         = { name = "leadsTo",
                              desc = "Target destination of a portal" }

inv.stats.capacity        = { name = "capacity",
                              desc = "How much weight the container can hold" }
inv.stats.holding         = { name = "holding",
                              desc = "Number of items held by the container" }
inv.stats.heaviestItem    = { name = "heaviestItem",
                              desc = "Weight of the heaviest item in the container" }
inv.stats.itemsInside     = { name = "itemsInside",
                              desc = "Number of items currently inside the container" }
inv.stats.totWeight       = { name = "totWeight",
                              desc = "Total weight of the container and its contents" }
inv.stats.itemBurden      = { name = "itemBurden",
                              desc = "Number of items in the container + 1 (for the container itself)" }
inv.stats.weightReduction = { name = "weightReduction",
                              desc = "Container reduces an item's weight to this % of the original weight" }

inv.stats.int             = { name = "int",
                              desc = "Intelligence points provided by the item" }
inv.stats.wis             = { name = "wis",
                              desc = "Wisdom points provided by the item" }
inv.stats.luck            = { name = "luck",
                              desc = "Luck points provided by the item" }
inv.stats.str             = { name = "str",
                              desc = "Strength points provided by the item" }
inv.stats.dex             = { name = "dex",
                              desc = "Dexterity points provided by the item" }
inv.stats.con             = { name = "con",
                              desc = "Constitution points provided by the item" }

inv.stats.hp              = { name = "hp",
                              desc = "Hit points provided by the item" }
inv.stats.mana            = { name = "mana",
                              desc = "Mana points provided by the item" }
inv.stats.moves           = { name = "moves",
                              desc = "Movement points provided by the item" }

inv.stats.hit             = { name = "hit",
                              desc = "Hit roll bonus due to the item" }
inv.stats.dam             = { name = "dam",
                              desc = "Damage roll bonus due to the item " }

inv.stats.allPhys         = { name = "allPhys",
                              desc = "Resistance provided against each of the physical resistance types" }
inv.stats.allMagic        = { name = "allMagic",
                              desc = "Resistance provided against each of the magical resistance types" }

inv.stats.acid            = { name = "acid",
                              desc = "Resistance provided against magical attacks of type \"acid\"" }
inv.stats.cold            = { name = "cold",
                              desc = "Resistance provided against magical attacks of type \"cold\"" }
inv.stats.energy          = { name = "energy",
                              desc = "Resistance provided against magical attacks of type \"energy\"" }
inv.stats.holy            = { name = "holy",
                              desc = "Resistance provided against magical attacks of type \"holy\"" }
inv.stats.electric        = { name = "electric",
                              desc = "Resistance provided against magical attacks of type \"electric\"" }
inv.stats.negative        = { name = "negative",
                              desc = "Resistance provided against magical attacks of type \"negative\"" }
inv.stats.shadow          = { name = "shadow",
                              desc = "Resistance provided against magical attacks of type \"shadow\"" }
inv.stats.magic           = { name = "magic",
                              desc = "Resistance provided against magical attacks of type \"magic\"" }
inv.stats.air             = { name = "air",
                              desc = "Resistance provided against magical attacks of type \"air\"" }
inv.stats.earth           = { name = "earth",
                              desc = "Resistance provided against magical attacks of type \"earth\"" }
inv.stats.fire            = { name = "fire",
                              desc = "Resistance provided against magical attacks of type \"fire\"" }
inv.stats.light           = { name = "light",
                              desc = "Resistance provided against magical attacks of type \"light\"" }
inv.stats.mental          = { name = "mental",
                              desc = "Resistance provided against magical attacks of type \"mental\"" }
inv.stats.sonic           = { name = "sonic",
                              desc = "Resistance provided against magical attacks of type \"sonic\"" }
inv.stats.water           = { name = "water",
                              desc = "Resistance provided against magical attacks of type \"water\"" }
inv.stats.poison          = { name = "poison",
                              desc = "Resistance provided against magical attacks of type \"poison\"" }
inv.stats.disease         = { name = "disease",
                              desc = "Resistance provided against magical attacks of type \"disease\"" }

inv.stats.slash           = { name = "slash",
                              desc = "Resistance provided against physical attacks of type \"slash\"" }
inv.stats.pierce          = { name = "pierce",
                              desc = "Resistance provided against physical attacks of type \"pierce\"" }
inv.stats.bash            = { name = "bash",
                              desc = "Resistance provided against physical attacks of type \"bash\"" }

inv.stats.aveDam          = { name = "aveDam",
                              desc = "Average damage from the weapon" }
inv.stats.inflicts        = { name = "inflicts",
                              desc = "Wound type from item: see Wset column in \"@Ghelp damage types@W\"" }
inv.stats.damType         = { name = "damType",
                              desc = "Damage type of item: see Damtype column in \"@Ghelp damage types@W\"" }
inv.stats.weaponType      = { name = "weaponType",
                              desc = "Type of weapon: see \"@Ghelp weapons@W\" for a list" }
inv.stats.specials        = { name = "specials",
                              desc = "See \"@Ghelp weapon flags@W\" for an explanation of special behaviors" }

inv.stats.location        = { name = "location",
                              desc = "Item ID for the container holding this item" }
inv.stats.rlocation       = { name = "rlocation",
                              desc = "Relative name (e.g., \"3.bag\") for the container holding this item" }
inv.stats.rname           = { name = "rname",
                              desc = "Relative name (e.g., \"2.dagger\") for the item" }
inv.stats.organize        = { name = "organize",
                              desc = "Queries assigned to a container by \"@Gdinv organize ...@W\"" }
inv.stats.loc             = { name = "loc",
                              desc = "Shorthand for the \"@G" .. inv.stats.location.name .. "@W\" search key" }
inv.stats.rloc            = { name = "rloc",
                              desc = "Shorthand for the \"@G" .. inv.stats.rlocation.name .. "@W\" search key" }
inv.stats.key             = { name = "key",
                              desc = "Shorthand for the \"@G" .. inv.stats.keywords.name .. "@W\" search key" }
inv.stats.keyword         = { name = "keyword",
                              desc = "Shorthand for the \"@G" .. inv.stats.keywords.name .. "@W\" search key" }
inv.stats.flag            = { name = "flag",
                              desc = "Shorthand for the \"@G" .. inv.stats.flags.name .. "@W\" search key" }

invStatFieldId              = string.lower(inv.stats.id.name)
invStatFieldName            = string.lower(inv.stats.name.name)
invStatFieldLevel           = string.lower(inv.stats.level.name)
invStatFieldWeight          = string.lower(inv.stats.weight.name)
invStatFieldWearable        = string.lower(inv.stats.wearable.name)
invStatFieldScore           = string.lower(inv.stats.score.name)
invStatFieldKeywords        = string.lower(inv.stats.keywords.name)
invStatFieldType            = string.lower(inv.stats.type.name)
invStatFieldWorth           = string.lower(inv.stats.worth.name)
invStatFieldFlags           = string.lower(inv.stats.flags.name)
invStatFieldAffectMods      = string.lower(inv.stats.affectMods.name)
invStatFieldMaterial        = string.lower(inv.stats.material.name)
invStatFieldFoundAt         = string.lower(inv.stats.foundAt.name)
invStatFieldOwnedBy         = string.lower(inv.stats.ownedBy.name)
invStatFieldClan            = string.lower(inv.stats.clan.name)
invStatFieldSpells          = string.lower(inv.stats.spells.name)
invStatFieldLeadsTo         = string.lower(inv.stats.leadsTo.name)

invStatFieldCapacity        = string.lower(inv.stats.capacity.name)
invStatFieldHolding         = string.lower(inv.stats.holding.name)
invStatFieldHeaviestItem    = string.lower(inv.stats.heaviestItem.name)
invStatFieldItemsInside     = string.lower(inv.stats.itemsInside.name)
invStatFieldTotWeight       = string.lower(inv.stats.totWeight.name)
invStatFieldItemBurden      = string.lower(inv.stats.itemBurden.name)
invStatFieldWeightReduction = string.lower(inv.stats.weightReduction.name)

invStatFieldInt             = string.lower(inv.stats.int.name)
invStatFieldWis             = string.lower(inv.stats.wis.name)
invStatFieldLuck            = string.lower(inv.stats.luck.name)
invStatFieldStr             = string.lower(inv.stats.str.name)
invStatFieldDex             = string.lower(inv.stats.dex.name)
invStatFieldCon             = string.lower(inv.stats.con.name)

invStatFieldHP              = string.lower(inv.stats.hp.name)
invStatFieldMana            = string.lower(inv.stats.mana.name)
invStatFieldMoves           = string.lower(inv.stats.moves.name)

invStatFieldHit             = string.lower(inv.stats.hit.name)
invStatFieldDam             = string.lower(inv.stats.dam.name)

invStatFieldAllPhys         = string.lower(inv.stats.allPhys.name)
invStatFieldAllMagic        = string.lower(inv.stats.allMagic.name)

invStatFieldAcid            = string.lower(inv.stats.acid.name)
invStatFieldCold            = string.lower(inv.stats.cold.name)
invStatFieldEnergy          = string.lower(inv.stats.energy.name)
invStatFieldHoly            = string.lower(inv.stats.holy.name)
invStatFieldElectric        = string.lower(inv.stats.electric.name)
invStatFieldNegative        = string.lower(inv.stats.negative.name)
invStatFieldShadow          = string.lower(inv.stats.shadow.name)
invStatFieldMagic           = string.lower(inv.stats.magic.name)
invStatFieldAir             = string.lower(inv.stats.air.name)
invStatFieldEarth           = string.lower(inv.stats.earth.name)
invStatFieldFire            = string.lower(inv.stats.fire.name)
invStatFieldLight           = string.lower(inv.stats.light.name)
invStatFieldMental          = string.lower(inv.stats.mental.name)
invStatFieldSonic           = string.lower(inv.stats.sonic.name)
invStatFieldWater           = string.lower(inv.stats.water.name)
invStatFieldPoison          = string.lower(inv.stats.poison.name)
invStatFieldDisease         = string.lower(inv.stats.disease.name)

invStatFieldSlash           = string.lower(inv.stats.slash.name)
invStatFieldPierce          = string.lower(inv.stats.pierce.name)
invStatFieldBash            = string.lower(inv.stats.bash.name)

invStatFieldAveDam          = string.lower(inv.stats.aveDam.name)
invStatFieldInflicts        = string.lower(inv.stats.inflicts.name)
invStatFieldDamType         = string.lower(inv.stats.damType.name)
invStatFieldWeaponType      = string.lower(inv.stats.weaponType.name)
invStatFieldSpecials        = string.lower(inv.stats.specials.name)


flagsContinuation      = false
affectModsContinuation = false
keywordsContinuation   = false
nameContinuation       = false
function inv.items.trigger.itemIdStats(line)
  dbot.debug("stats for item " .. inv.items.identifyPkg.objId .. ":\"" .. line .. "\"")

  local isPartialId, id, name, level, weight, wearable, score, keywords, itemType, worth, flags,
        affectMods, continuation, material, foundAt, ownedBy, clan, rawMaterial

  isPartialId = string.find(line, "A full appraisal will reveal further information on this item")

  _, _, id = string.find(line, "Id%s+:%s+(%d+)%s+")
  _, _, name = string.find(line, "Name%s+:%s+(.-)%s*|$")
  _, _, level = string.find(line, "Level%s+:%s+(%d+)%s+")
  _, _, weight = string.find(line, "Weight%s+:%s+([0-9,-]+)%s+")
  _, _, wearable = string.find(line, "Wearable%s+:%s+(.*) %s+")
  _, _, score = string.find(line, "Score%s+:%s([0-9,]+)%s+")
  _, _, keywords = string.find(line, "Keywords%s+:%s+(.-)%s*|")
  _, _, itemType = string.find(line, "| Type%s+:%s+(%a+)%s+")
  _, _, rawMaterial = string.find(line, "| Type%s+:%s+(Raw material:%a+)")

  _, _, worth = string.find(line, "Worth%s+:%s+([0-9,]+)%s+")
  _, _, flags = string.find(line, "Flags%s+:%s+(.-)%s*|")
  _, _, affectMods = string.find(line, "Affect Mods:%s+(.-)%s*|")
  _, _, continuation = string.find(line, "|%s+:%s+(.-)%s*|")
  _, _, material = string.find(line, "Material%s+:%s+(.*)%s+")
  _, _, foundAt = string.find(line, "Found at%s+:%s+(.-)%s*|")
  _, _, ownedBy = string.find(line, "Owned By%s+:%s+(.-)%s*|")
  _, _, clan = string.find(line, "Clan Item%s+:%s+(.-)%s*|")

  -- Potions, pills, wands, and staves
  local spellUses, spellLevel, spellName
  _, _, spellUses, spellLevel, spellName = string.find(line, "([0-9]+) uses? of level ([0-9]+) '(.*)'")

  -- Portal-only fields
  local leadsTo
  _, _, leadsTo = string.find(line, "Leads to%s+:%s+(.*)%s+")

  -- Container-only fields
  local capacity, holding, heaviestItem, itemsInside, totWeight, itemBurden, weightReduction
  _, _, capacity = string.find(line, "Capacity%s+:%s+([0-9,]+)%s+")
  _, _, holding = string.find(line, "Holding%s+:%s+([0-9,]+)%s+")
  _, _, heaviestItem = string.find(line, "Heaviest Item:%s+([0-9,]+)%s+")
  _, _, itemsInside = string.find(line, "Items Inside%s+:%s+([0-9,]+)%s+")
  _, _, totWeight = string.find(line, "Tot Weight%s+:%s+([0-9,-]+)%s+")
  _, _, itemBurden = string.find(line, "Item Burden%s+:%s+([0-9,]+)%s+")
  _, _, weightReduction = string.find(line, "Items inside weigh (%d+). of their usual weight%s+")

  local int, wis, luck, str, dex, con
  _, _, int = string.find(line, "Intelligence%s+:%s+([+-]?%d+)%s+")
  _, _, wis = string.find(line, "Wisdom%s+:%s+([+-]?%d+)%s+")
  _, _, luck = string.find(line, "Luck%s+:%s+([+-]?%d+)%s+")
  _, _, str = string.find(line, "Strength%s+:%s+([+-]?%d+)%s+")
  _, _, dex = string.find(line, "Dexterity%s+:%s+([+-]?%d+)%s+")
  _, _, con = string.find(line, "Constitution%s+:%s+([+-]?%d+)%s+")

  local hp, mana, moves
  _, _, hp = string.find(line, "Hit points%s+:%s+([+-]?%d+)%s+")
  _, _, mana = string.find(line, "Mana%s+:%s+([+-]?%d+)%s+")
  _, _, moves = string.find(line, "Moves%s+:%s+([+-]?%d+)%s+")

  local hit, dam
  _, _, hit = string.find(line, "Hit roll%s+:%s+([+-]?%d+)%s+")
  _, _, dam = string.find(line, "Damage roll%s+:%s+([+-]?%d+)%s+")

  local allphys, allmagic
  _, _, allphys = string.find(line, "All physical%s+:%s+([+-]?%d+)%s+")
  _, _, allmagic = string.find(line, "All magic%s+:%s+([+-]?%d+)%s+")

  local acid, cold, energy, holy, electric, negative, shadow, magic, air, earth, fire, light, mental,
        sonic, water, poison, disease
  _, _, acid = string.find(line, "Acid%s+:%s+([+-]?%d+)%s+")
  _, _, cold = string.find(line, "Cold%s+:%s+([+-]?%d+)%s+")
  _, _, energy = string.find(line, "Energy%s+:%s+([+-]?%d+)%s+")
  _, _, holy = string.find(line, "Holy%s+:%s+([+-]?%d+)%s+")
  _, _, electric = string.find(line, "Electric%s+:%s+([+-]?%d+)%s+")
  _, _, negative = string.find(line, "Negative%s+:%s+([+-]?%d+)%s+")
  _, _, shadow = string.find(line, "Shadow%s+:%s+([+-]?%d+)%s+")
  _, _, magic = string.find(line, "Magic%s+:%s+([+-]?%d+)%s+")
  _, _, air = string.find(line, "Air%s+:%s+([+-]?%d+)%s+")
  _, _, earth = string.find(line, "Earth%s+:%s+([+-]?%d+)%s+")
  _, _, fire = string.find(line, "Fire%s+:%s+([+-]?%d+)%s+")
  _, _, light = string.find(line, "Light%s+:%s+([+-]?%d+)%s+")
  _, _, mental = string.find(line, "Mental%s+:%s+([+-]?%d+)%s+")
  _, _, sonic = string.find(line, "Sonic%s+:%s+([+-]?%d+)%s+")
  _, _, water = string.find(line, "Water%s+:%s+([+-]?%d+)%s+")
  _, _, poison = string.find(line, "Poison%s+:%s+([+-]?%d+)%s+")
  _, _, disease = string.find(line, "Disease%s+:%s+([+-]?%d+)%s+")

  local slash, pierce, bash
  _, _, slash = string.find(line, "Slash%s+:%s+([+-]?%d+)%s+")
  _, _, pierce = string.find(line, "Pierce%s+:%s+([+-]?%d+)%s+")
  _, _, bash = string.find(line, "Bash%s+:%s+([+-]?%d+)%s+")

  local avedam, inflicts, damtype, weaponType, specials
  _, _, avedam = string.find(line, "Average Dam%s+:%s+(%d+)%s+")
  _, _, inflicts = string.find(line, "Inflicts%s+:%s+(%a+)%s+")
  _, _, damtype = string.find(line, "Damage Type%s+:%s+(%a+)%s+")
  _, _, weaponType = string.find(line, "Weapon Type:%s+(%a+)%s+")
  _, _, specials = string.find(line, "Specials%s+:%s+(%a+)%s+")

  local tmpAvedam, tmpHR, tmpDR, tmpInt, tmpWis, tmpLuck, tmpStr, tmpDex, tmpCon
  _, _, tmpAvedam = string.find(line, ":%s+adds [+-](%d+) average damage%s+")
  _, _, tmpHR = string.find(line, ":%s+hit roll [+-](%d+)")
  _, _, tmpDR = string.find(line, ":%s+damage roll [+-](%d+)")
  _, _, tmpInt = string.find(line, ":%s+intelligence [+-](%d+)")
  _, _, tmpWis = string.find(line, ":%s+wisdom [+-](%d+)")
  _, _, tmpLuck = string.find(line, ":%s+luck [+-](%d+)")
  _, _, tmpStr = string.find(line, ":%s+strength [+-](%d+)")
  _, _, tmpDex = string.find(line, ":%s+dexterity [+-](%d+)")
  _, _, tmpCon = string.find(line, ":%s+constitution [+-](%d+)")

  if (id ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldId, dbot.tonumber(id or ""))
    dbot.debug("Id = \"" .. id .. "\"")

    -- If we hit the id field, we know that there aren't any more name continuation lines
    nameContinuation = false
  end -- if

  if (name ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldName, name)
    dbot.debug("Name = \"" .. name .. "\"")

    -- If we hit the name field, we know that there aren't any more keyword continuation lines.
    -- Instead we assume the name will continue until we hit the Id field.
    keywordsContinuation = false
    nameContinuation = true
  end -- if

  if (level ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldLevel, dbot.tonumber(level or ""))
    dbot.debug("Level = \"" .. level .. "\"")
  end -- if

  if (weight ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWeight, dbot.tonumber(weight or ""))
    dbot.debug("Weight = \"" .. weight .. "\"")
  end -- if

  if (wearable ~= nil) then
    -- Strip out spaces and commas for items that can have more than one wearable location (e.g., "hold, light")
    wearable = string.gsub(Trim(wearable), ",", "")

    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWearable, wearable)
    dbot.debug("Wearable = \"" .. wearable .. "\"")
  end -- if

  if (score ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldScore, dbot.tonumber(score or ""))
    dbot.debug("Score = \"" .. score .. "\"")
  end -- if

  if (keywords ~= nil) then
    -- Merge this with any previous keywords.  Someone may have added custom keywords to the
    -- item and then re-identified it for some reason.  For example, someone may have toggled the
    -- keep flag which would cause invitem to flag the item to be re-identified.
    local oldKeywords = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldKeywords) or ""
    local mergedKeywords = dbot.mergeFields(keywords, oldKeywords) or keywords

    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldKeywords, mergedKeywords)
    dbot.debug("Keywords = \"" .. mergedKeywords .. "\"")

    -- Assume that the keywords keep continuing on additional lines until we finally hit the name
    -- field.  At that point we know that there are no more keyword lines.
    keywordsContinuation = true
  end -- if

  if (itemType ~= nil) or (rawMaterial ~= nil) then
    -- All item types, with the exception of "Raw material:[whatever]" are a single word.  As a
    -- result, we treat "Raw material" as a one-off and strip out the space for our internal use.
    if (rawMaterial ~= nil) then
      itemType = string.gsub(rawMaterial, "Raw material", "RawMaterial")
    end -- if

    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldType, itemType)
    dbot.debug("Type = \"" .. itemType .. "\"")
  end -- if

  if (worth ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWorth, dbot.tonumber(worth))
    dbot.debug("Worth = \"" .. worth .. "\"")
  end -- if

  if (isPartialId ~= nil) then
    inv.items.setField(inv.items.identifyPkg.objId, invFieldIdentifyLevel, invIdLevelPartial)
    dbot.debug("Id level = \"" .. invIdLevelPartial .. "\"")
  end -- if

  if (flags ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldFlags, flags)
    dbot.debug("Flags = \"" .. flags .. "\"")

    -- If the flags are continued (they end in a ",") watch for the continuation
    if (string.find(flags, ",$")) then
      flagsContinuation = true
    else
      flagsContinuation = false
    end -- if
  end -- if

  if (affectMods ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAffectMods, affectMods)
    dbot.debug("AffectMods = \"" .. affectMods .. "\"")

    -- If the affectMods are continued (they end in a ",") watch for the continuation
    if (string.find(affectMods, ",$")) then
      affectModsContinuation = true
    else
      affectModsContinuation = false
    end -- if
  end -- if

  if (continuation ~= nil) then
    dbot.debug("Continuation = \"" .. continuation .. "\"")
    if (flagsContinuation) then
      -- Add the continuation to the existing flags
      inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldFlags,
                             (inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldFlags) or "") ..
                             " " .. continuation)

      -- If the continued flags end in a comma, keep the continuation going; otherwise stop it
      if not (string.find(continuation, ",$")) then
        flagsContinuation = false
      end -- if

    elseif (affectModsContinuation) then
      -- Add the continuation to the existing affectMods
      inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAffectMods,
                            (inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldAffectMods) 
                             or "") .. " " .. continuation)

      -- If the continued affectMods end in a comma, keep the continuation going; otherwise stop it
      if not (string.find(continuation, ",$")) then
        affectModsContinuation = false
      end -- if

    elseif (keywordsContinuation) then
      -- Add the continuation to the existing keywords
      inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldKeywords,
                            (inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldKeywords) 
                             or "") .. " " .. continuation)

    elseif (nameContinuation) then
      -- Add the continuation to the existing name
      inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldName,
                            (inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldName) 
                             or "") .. " " .. continuation)

    else
      -- Placeholder to add continuation support for other things (notes? others?)
    end -- if
  end -- if

  if (material ~= nil) then
    material = Trim(material)
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldMaterial, material)
    dbot.debug("Material = \"" .. material .. "\"")
  end -- if

  if (foundAt ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldFoundAt, foundAt)
    dbot.debug("Found at = \"" .. foundAt .. "\"")
  end -- if

  if (ownedBy ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldOwnedBy, ownedBy)
    dbot.debug("Found at = \"" .. ownedBy .. "\"")
  end -- if

  if (clan ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldClan, clan)
    dbot.debug("From clan \"" .. clan .. "\"")
  end -- if

  if (spellUses ~= nil) and (spellLevel ~= nil) and (spellName ~= nil) then
    local spellArray = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldSpells) or {}
    spellUses = tonumber(spellUses) or 0

    -- If we already have an entry for this spell, update the count
    local foundSpellMatch = false
    for _, v in ipairs(spellArray) do
      if (v.level == spellLevel) and (v.name == spellName) then
        v.count = v.count + spellUses
        foundSpellMatch = true
        break
      end -- if
    end -- if

    -- If we don't have an entry yet for this spell, add one 
    if (foundSpellMatch == false) then
      table.insert(spellArray, { level=spellLevel, name=spellName, count=spellUses }) 
    end -- if

    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldSpells, spellArray)
  end -- if

  if (leadsTo ~= nil) then
    leadsTo = Trim(leadsTo)
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldLeadsTo, leadsTo)
    dbot.debug("Leads to = \"" .. leadsTo .. "\"")
  end -- if

  -- Container stats
  if (capacity ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldCapacity, dbot.tonumber(capacity))
    dbot.debug("Capacity = \"" .. capacity .. "\"")
  end -- if

  if (holding ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldHolding, dbot.tonumber(holding))
    dbot.debug("Holding = \"" .. holding .. "\"")
  end -- if

  if (heaviestItem ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldHeaviestItem, dbot.tonumber(heaviestItem))
    dbot.debug("Container heaviest item = \"" .. heaviestItem .. "\"")
  end -- if

  if (itemsInside ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldItemsInside, dbot.tonumber(itemsInside))
    dbot.debug("Container items inside = \"" .. itemsInside .. "\"")
  end -- if

  if (totWeight ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldTotWeight, dbot.tonumber(totWeight))
    dbot.debug("Container total weight = \"" .. totWeight .. "\"")
  end -- if

  if (itemBurden ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldItemBurden, dbot.tonumber(itemBurden))
    dbot.debug("Container item burden = \"" .. itemBurden .. "\"")
  end -- if

  if (weightReduction ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWeightReduction,
                           dbot.tonumber(weightReduction))
    dbot.debug("Container weight reduction = \"" .. weightReduction .. "\"")
  end -- if


  if (int ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldInt, dbot.tonumber(int))
    dbot.debug("int = \"" .. int .. "\"")
  end -- if

  if (wis ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWis, dbot.tonumber(wis))
    dbot.debug("wis = \"" .. wis .. "\"")
  end -- if

  if (luck ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldLuck, dbot.tonumber(luck))
    dbot.debug("luck = \"" .. luck .. "\"")
  end -- if

  if (str ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldStr, dbot.tonumber(str))
    dbot.debug("str = \"" .. str .. "\"")
  end -- if

  if (dex ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldDex, dbot.tonumber(dex))
    dbot.debug("dex = \"" .. dex .. "\"")
  end -- if

  if (con ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldCon, dbot.tonumber(con))
    dbot.debug("con = \"" .. con .. "\"")
  end -- if

  if (hp ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldHP, dbot.tonumber(hp))
    dbot.debug("hp = \"" .. hp .. "\"")
  end -- if

  if (mana ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldMana, dbot.tonumber(mana))
    dbot.debug("mana = \"" .. mana .. "\"")
  end -- if

  if (moves ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldMoves, dbot.tonumber(moves))
    dbot.debug("moves = \"" .. moves .. "\"")
  end -- if

  if (hit ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldHit, dbot.tonumber(hit))
    dbot.debug("hit = \"" .. hit .. "\"")
  end -- if

  if (dam ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldDam, dbot.tonumber(dam))
    dbot.debug("dam = \"" .. dam .. "\"")
  end -- if

  if (allphys ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAllPhys, dbot.tonumber(allphys))
    dbot.debug("allphys = \"" .. allphys .. "\"")
  end -- if

  if (allmagic ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAllMagic, dbot.tonumber(allmagic))
    dbot.debug("allmagic = \"" .. allmagic .. "\"")
  end -- if


  if (acid ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAcid, dbot.tonumber(acid))
    dbot.debug("acid = \"" .. acid .. "\"")
  end -- if

  if (cold ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldCold, dbot.tonumber(cold))
    dbot.debug("cold = \"" .. cold .. "\"")
  end -- if

  if (energy ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldEnergy, dbot.tonumber(energy))
    dbot.debug("energy = \"" .. energy .. "\"")
  end -- if

  if (holy ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldHoly, dbot.tonumber(holy))
    dbot.debug("holy = \"" .. holy .. "\"")
  end -- if

  if (electric ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldElectric, dbot.tonumber(electric))
    dbot.debug("electric = \"" .. electric .. "\"")
  end -- if

  if (negative ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldNegative, dbot.tonumber(negative))
    dbot.debug("negative = \"" .. negative .. "\"")
  end -- if

  if (shadow ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldShadow, dbot.tonumber(shadow))
    dbot.debug("shadow = \"" .. shadow .. "\"")
  end -- if

  if (magic ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldMagic, dbot.tonumber(magic))
    dbot.debug("magic = \"" .. magic .. "\"")
  end -- if

  if (air ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAir, dbot.tonumber(air))
    dbot.debug("air = \"" .. air .. "\"")
  end -- if

  if (earth ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldEarth, dbot.tonumber(earth))
    dbot.debug("earth = \"" .. earth .. "\"")
  end -- if

  if (fire ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldFire, dbot.tonumber(fire))
    dbot.debug("fire = \"" .. fire .. "\"")
  end -- if

  if (light ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldLight, dbot.tonumber(light))
    dbot.debug("light = \"" .. light .. "\"")
  end -- if

  if (mental ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldMental, dbot.tonumber(mental))
    dbot.debug("mental = \"" .. mental .. "\"")
  end -- if

  if (sonic ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldSonic, dbot.tonumber(sonic))
    dbot.debug("sonic = \"" .. sonic .. "\"")
  end -- if

  if (water ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWater, dbot.tonumber(water))
    dbot.debug("water = \"" .. water .. "\"")
  end -- if

  if (poison ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldPoison, dbot.tonumber(poison))
    dbot.debug("poison = \"" .. poison .. "\"")
  end -- if

  if (disease ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldDisease, dbot.tonumber(disease))
    dbot.debug("disease = \"" .. disease .. "\"")
  end -- if

  if (slash ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldSlash, dbot.tonumber(slash))
    dbot.debug("slash = \"" .. slash .. "\"")
  end -- if

  if (pierce ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldPierce, dbot.tonumber(pierce))
    dbot.debug("pierce = \"" .. pierce .. "\"")
  end -- if

  if (bash ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldBash, dbot.tonumber(bash))
    dbot.debug("bash = \"" .. bash .. "\"")
  end -- if


  if (avedam ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAveDam, dbot.tonumber(avedam))
    dbot.debug("avedam = \"" .. avedam .. "\"")
  end -- if

  if (tmpAvedam ~= nil) then
    local currentAvedam = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldAveDam) or 0
    local newAvedam = dbot.tonumber(tmpAvedam) + currentAvedam
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldAveDam, newAvedam)
    dbot.debug("tmpAvedam = \"" .. tmpAvedam .. "\"")
  end -- if

  if (tmpHR ~= nil) then
    local currentHR = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldHit) or 0
    local newHR = dbot.tonumber(tmpHR) + currentHR
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldHit, newHR)
    dbot.debug("tmpHR = \"" .. tmpHR .. "\"")
  end -- if

  if (tmpDR ~= nil) then
    local currentDR = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldDam) or 0
    local newDR = dbot.tonumber(tmpDR) + currentDR
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldDam, newDR)
    dbot.debug("tmpDR = \"" .. tmpDR .. "\"")
  end -- if

  if (tmpInt ~= nil) then
    local currentInt = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldInt) or 0
    local newInt = dbot.tonumber(tmpInt) + currentInt
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldInt, newInt)
    dbot.debug("tmpInt = \"" .. tmpInt .. "\"")
  end -- if

  if (tmpWis ~= nil) then
    local currentWis = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldWis) or 0
    local newWis = dbot.tonumber(tmpWis) + currentWis
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWis, newWis)
    dbot.debug("tmpWis = \"" .. tmpWis .. "\"")
  end -- if

  if (tmpLuck ~= nil) then
    local currentLuck = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldLuck) or 0
    local newLuck = dbot.tonumber(tmpLuck) + currentLuck
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldLuck, newLuck)
    dbot.debug("tmpLuck = \"" .. tmpLuck .. "\"")
  end -- if

  if (tmpStr ~= nil) then
    local currentStr = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldStr) or 0
    local newStr = dbot.tonumber(tmpStr) + currentStr
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldStr, newStr)
    dbot.debug("tmpStr = \"" .. tmpStr .. "\"")
  end -- if

  if (tmpDex ~= nil) then
    local currentDex = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldDex) or 0
    local newDex = dbot.tonumber(tmpDex) + currentDex
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldDex, newDex)
    dbot.debug("tmpDex = \"" .. tmpDex .. "\"")
  end -- if

  if (tmpCon ~= nil) then
    local currentCon = inv.items.getStatField(inv.items.identifyPkg.objId, invStatFieldCon) or 0
    local newCon = dbot.tonumber(tmpCon) + currentCon
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldCon, newCon)
    dbot.debug("tmpCon = \"" .. tmpCon .. "\"")
  end -- if

  if (inflicts ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldInflicts, inflicts)
    dbot.debug("inflicts = \"" .. inflicts .. "\"")
  end -- if

  if (damtype ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldDamType, damtype)
    dbot.debug("damtype = \"" .. damtype .. "\"")
  end -- if

  if (weaponType ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldWeaponType, weaponType)
    dbot.debug("weaponType = \"" .. weaponType .. "\"")
  end -- if

  if (specials ~= nil) then
    inv.items.setStatField(inv.items.identifyPkg.objId, invStatFieldSpecials, specials)
    dbot.debug("specials = \"" .. specials .. "\"")
  end -- if

end -- inv.items.trigger.itemIdStats
