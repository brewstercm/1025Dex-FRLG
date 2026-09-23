-- FireRed gameplay-evolution adapter for 1025Dex.
--
-- The generated files under data/evolutions/generated/ are also used by the
-- Pokédex UI. This module translates the subset FireRed can execute into the
-- Gen1Recomp Gen 3 evolution row format.
--
-- It intentionally uses mod:read() rather than require()/loadfile(): 1025Dex
-- is loaded from a mod archive and its sibling files are not on package.path.

local M = {}

local overridesCache

local function compileModFile(mod, name, source)
  local chunk, err = load(source, "@" .. mod.path .. "/" .. name)
  if not chunk then return nil, err end
  local ok, result = pcall(chunk)
  if not ok then return nil, result end
  return result
end

local function readLua(mod, name, optional)
  local source = mod:read(name)
  if not source then
    if optional then return nil end
    return nil, name .. " is missing"
  end
  return compileModFile(mod, name, source)
end

local function loadOverrides(mod)
  if overridesCache ~= nil then return overridesCache end
  local data, err = readLua(mod, "data/evolutions/compat_overrides.lua", true)
  if type(data) ~= "table" then
    if err then
      mod.log:warn("evolution compatibility overrides failed to load (%s)",
        tostring(err))
    end
    data = {}
  end
  overridesCache = data
  return data
end

-- Load the existing generated evolution database. These files are unchanged
-- display/source data; no edits to the generated shards are required.
function M.load(mod)
  local result = {}
  for shard = 1, 14 do
    local name = ("data/evolutions/generated/%03d.lua"):format(shard)
    local data, err = readLua(mod, name, false)
    if type(data) == "table" then
      for id, record in pairs(data) do result[id] = record end
    else
      mod.log:warn("%s could not be loaded for gameplay evolutions (%s)",
        name, tostring(err))
    end
  end
  return result
end

local function normalizeItem(value)
  if value == nil then return nil end
  return tostring(value):upper()
    :gsub("[^A-Z0-9]+", "_")
    :gsub("^_+", "")
    :gsub("_+$", "")
end

-- FireRed already contains these six usable evolution stones.
local FIRE_RED_STONES = {
  SUN_STONE = "SUN_STONE",
  MOON_STONE = "MOON_STONE",
  FIRE_STONE = "FIRE_STONE",
  THUNDER_STONE = "THUNDERSTONE",
  WATER_STONE = "WATER_STONE",
  LEAF_STONE = "LEAF_STONE",
}

-- Trade evolutions are converted to single-save evolution rules.
--
-- Most become level evolutions. A couple of branching families use an item
-- override in compat_overrides.lua so both branches are selectable without
-- repeatedly cancelling another level evolution.
local TRADE_LEVELS = {
  SHELMET = { ACCELGOR = 36 },

  POLIWHIRL = { POLITOED = 37 },
  KADABRA = { ALAKAZAM = 36 },
  MACHOKE = { MACHAMP = 36 },
  GRAVELER = { GOLEM = 36 },
  HAUNTER = { GENGAR = 36 },

  ONIX = { STEELIX = 40 },
  SEADRA = { KINGDRA = 40 },
  SCYTHER = { SCIZOR = 40 },
  PORYGON = { PORYGON2 = 30 },

  RHYDON = { RHYPERIOR = 50 },
  ELECTABUZZ = { ELECTIVIRE = 42 },
  MAGMAR = { MAGMORTAR = 42 },
  DUSCLOPS = { DUSKNOIR = 48 },
  PORYGON2 = { PORYGON_Z = 40 },

  SPRITZEE = { AROMATISSE = 36 },
  SWIRLIX = { SLURPUFF = 36 },
  PHANTUMP = { TREVENANT = 36 },
  PUMPKABOO = { GOURGEIST = 36 },

  BOLDORE = { GIGALITH = 40 },
  GURDURR = { CONKELDURR = 40 },
  KARRABLAST = { ESCAVALIER = 36 },

  -- Feebas normally also has a Beauty evolution. If the generated data picks
  -- the trade method first, this still makes Milotic obtainable.
  FEEBAS = { MILOTIC = 35 },

  -- Clamperl has two trade-item branches. Huntail is the level branch; the
  -- Gorebyss compatibility override uses a Water Stone so both are selectable.
  CLAMPERL = { HUNTAIL = 36 },
}

local DEFAULT_TRADE_LEVEL = 40

local function tradeLevel(sourceId, targetId)
  local byTarget = TRADE_LEVELS[sourceId]
  if byTarget and byTarget[targetId] then return byTarget[targetId] end
  return DEFAULT_TRADE_LEVEL
end

local function getDefaultMethod(target)
  if type(target.methods) ~= "table" then return nil end
  for _, method in ipairs(target.methods) do
    if method.isDefault then return method end
  end
  return target.methods[1]
end

local function overrideFor(mod, sourceId, targetId)
  local all = loadOverrides(mod)
  local source = all[sourceId]
  return type(source) == "table" and source[targetId] or nil
end

local function applyOverride(mod, sourceId, targetId, targetSpecies)
  local rule = overrideFor(mod, sourceId, targetId)
  if type(rule) ~= "table" then return nil end
  local row = { species = targetSpecies }
  if rule.method ~= nil then row.method = rule.method end
  if rule.level ~= nil then row.level = rule.level end
  if rule.item ~= nil then row.item = rule.item end
  if rule.param ~= nil then row.param = rule.param end
  return row
end

local function regionalFormId(id)
  id = tostring(id or "")
  return id:match("_ALOLA$") or id:match("_GALAR$")
    or id:match("_HISUI$") or id:match("_PALDEA$")
end

-- Conditions FireRed cannot represent with a stock evolution row. Time of
-- day is intentionally NOT on this list: where it is the only extra condition
-- we use the same level/friendship rule without the clock restriction.
local function hasUnsupportedLevelCondition(method)
  return method.knownMove ~= nil
    or method.knownMoveType ~= nil
    or method.location ~= nil
    or method.needsOverworldRain ~= nil
    or method.turnUpsideDown ~= nil
    or method.minAffection ~= nil
    or method.partySpecies ~= nil
    or method.partyType ~= nil
    or method.tradeSpecies ~= nil
    or method.heldItem ~= nil
    or method.gender ~= nil
    or method.minSteps ~= nil
    or method.minMoveCount ~= nil
    or method.usedMove ~= nil
end

local function convertMethod(mod, sourceId, target, method, targetSpecies)
  local override = applyOverride(mod, sourceId, target.id, targetSpecies)
  if override then return override end

  -- FireRed-native special branches whose source data is too generic to
  -- distinguish the cartridge method.
  if sourceId == "WURMPLE" and target.id == "SILCOON" then
    return { method = "EVO_LEVEL_SILCOON", level = method.level or 7,
      species = targetSpecies }
  end
  if sourceId == "WURMPLE" and target.id == "CASCOON" then
    return { method = "EVO_LEVEL_CASCOON", level = method.level or 7,
      species = targetSpecies }
  end
  if sourceId == "NINCADA" and target.id == "NINJASK" then
    return { method = "EVO_LEVEL_NINJASK", level = method.level or 20,
      species = targetSpecies }
  end
  if sourceId == "NINCADA" and target.id == "SHEDINJA" then
    return { method = "EVO_LEVEL_SHEDINJA", level = 20,
      species = targetSpecies }
  end

  -- Tyrogue's three-way Attack/Defense split is supported directly.
  if method.trigger == "level-up" and method.relativePhysicalStats ~= nil
      and method.level then
    local rel = tonumber(method.relativePhysicalStats)
    local evoMethod = rel == 1 and "EVO_LEVEL_ATK_GT_DEF"
      or (rel == -1 and "EVO_LEVEL_ATK_LT_DEF"
      or (rel == 0 and "EVO_LEVEL_ATK_EQ_DEF" or nil))
    if evoMethod then
      return { method = evoMethod, level = method.level,
        species = targetSpecies }
    end
  end

  -- Normal level evolution. A pure day/night restriction is dropped because
  -- FireRed has no clock-driven level evolution.
  if method.trigger == "level-up" and method.level
      and not method.minHappiness and not method.minBeauty
      and method.relativePhysicalStats == nil
      and not hasUnsupportedLevelCondition(method) then
    return { method = "EVO_LEVEL", level = method.level,
      species = targetSpecies }
  end

  -- FireRed's active Gen 3 evolution scanner implements ordinary friendship,
  -- not the day/night friendship variants, so day/night is deliberately
  -- collapsed here.
  if method.trigger == "level-up" and method.minHappiness
      and not hasUnsupportedLevelCondition(method) then
    return { method = "EVO_FRIENDSHIP", species = targetSpecies }
  end

  if method.trigger == "level-up" and method.minBeauty then
    return { method = "EVO_BEAUTY", param = method.minBeauty,
      species = targetSpecies }
  end

  -- No evolution in 1025Dex should require another player/save.
  -- Normal trades, held-item trades and paired-species trades all become a
  -- deterministic single-save level evolution unless compat_overrides.lua
  -- supplied a different single-save rule first.
  if method.trigger == "trade" then
    return {
      method = "EVO_LEVEL",
      level = tradeLevel(sourceId, target.id),
      species = targetSpecies,
    }
  end

  if method.trigger == "use-item" and method.item then
    local item = FIRE_RED_STONES[normalizeItem(method.item)]
    -- Gender/region/etc. item branches are not safe to collapse automatically.
    if item and method.gender == nil and method.region == nil
        and method.timeOfDay == nil then
      return { method = "EVO_ITEM", item = item, species = targetSpecies }
    end
  end

  return nil
end

-- True when the generated evolution list contains a trade requirement.
-- Native FireRed species with one of these need their cartridge evolution
-- list replaced by the translated list; simply appending would leave the old
-- trade-only row active.
function M.hasTradeEvolution(record)
  if type(record) ~= "table" or type(record.evolvesInto) ~= "table" then
    return false
  end
  for _, target in ipairs(record.evolvesInto) do
    if not regionalFormId(target.id) and type(target.methods) == "table" then
      for _, method in ipairs(target.methods) do
        if method.trigger == "trade" then return true end
      end
    end
  end
  return false
end

-- Build FireRed gameplay rows for one generated species record.
--
-- `slotForDex` is supplied by gen3shape.lua because FireRed's native Gen 3
-- internal species slots do not equal National Dex numbers after Celebi.
--
-- When numericTargets is false, `species` remains a string id so records going
-- through mod.content.pokemon pass schema validation and forward references.
-- gen3shape's early direct-write pass uses numericTargets=true because those
-- target names have not entered FireRed's live species table yet.
--
-- `minTargetDex`, when supplied, filters the result to targets above that
-- National Dex number. Native FireRed species use 386 here so their existing
-- Gen 1-3 evolution rows remain intact and only later branches are appended.
function M.rows(mod, sourceId, record, slotForDex, numericTargets, minTargetDex)
  local rows = {}
  if type(record) ~= "table" or type(record.evolvesInto) ~= "table"
      or type(slotForDex) ~= "function" then
    return rows
  end

  for _, target in ipairs(record.evolvesInto) do
    local targetDex = tonumber(target.dex)
    -- Regional-form targets are not part of 1025Dex's base-species FireRed
    -- registration and must not replace the base target. `minTargetDex` lets
    -- native FireRed species append only NEW post-Gen-3 branches while
    -- leaving their cartridge evolution rows untouched.
    if not regionalFormId(target.id)
        and (minTargetDex == nil or (targetDex and targetDex > minTargetDex)) then
      local targetSpecies = numericTargets
        and slotForDex(targetDex) or target.id
      if targetSpecies then
        local inserted = false
        local default = getDefaultMethod(target)

        if default then
          local row = convertMethod(
            mod, sourceId, target, default, targetSpecies)
          if row then
            rows[#rows + 1] = row
            inserted = true
          end
        end

        if not inserted and type(target.methods) == "table" then
          for _, method in ipairs(target.methods) do
            if method ~= default then
              local row = convertMethod(
                mod, sourceId, target, method, targetSpecies)
              if row then
                rows[#rows + 1] = row
                inserted = true
                break
              end
            end
          end
        end
      end
    end
  end
  return rows
end

return M
