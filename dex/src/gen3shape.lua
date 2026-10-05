-- Game3 shape adapter. National Dex carries Gen 1/2-friendly source data;
-- Game3's registry expects split Special stats and numbered species slots.
-- ROM species IDs are NOT National Dex IDs. Preserve native Gen 1-3 slots,
-- including FRLG's unused/Unown slots, and allocate additions above them.
local M = { ROM_DEX_MAX = 386 }

-- PokeAPI stores the chance of being female in eighths. Gen 3 compares the
-- low personality byte with a 0-255 threshold; 254 and 255 are reserved for
-- female-only and genderless species.
function M.genderRatio(rate)
  rate = tonumber(rate)
  if rate == -1 then return 0xFF end
  if rate == 0 then return 0 end
  if rate == 8 then return 0xFE end
  if rate and rate >= 1 and rate <= 7 and rate == math.floor(rate) then
    return math.floor(rate * 255 / 8)
  end
  return nil
end

function M.slot(dex)
  if dex > 386 then return dex + 64 end
  local P = require('src.core.game3.pokemon')
  return P.speciesFromNational(dex)
end

function M.generation()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and GameVersion and GameVersion.generation and GameVersion.generation() == 3 then
    return 3
  end
  return nil
end

function M.romOwned(record)
  return type(record) == "table" and type(record.dex) == "number"
    and record.dex <= M.ROM_DEX_MAX
end

function M.romPatch(record)
  return { types = record.types }
end

function M.record(source, machines)
  local entry = source.dexEntry or {}
  local h = tonumber(entry.heightM) or 0
  local w = tonumber(entry.weightKg) or 0
  local stats = source.baseStats or {}
  return {
    id = source.id, name = source.name, dex = source.dex, index = M.slot(source.dex),
    types = source.types or { "NORMAL" },
    baseStats = { hp = stats.hp or 1, attack = stats.attack or 1,
      defense = stats.defense or 1, speed = stats.speed or 1,
      specialAttack = source.spAttack or stats.special or 1,
      specialDefense = source.spDefense or stats.special or 1 },
    catchRate = source.catchRate or 0, baseExp = source.baseExp or 0,
    genderRatio = M.genderRatio(M.genderRates and M.genderRates[source.id]),
    growthRate = source.growthRate or "MEDIUM_FAST",
    learnset = source.learnset or {}, tmhm = machines or {}, evolutions = {},
    dexEntry = { kind = entry.kind or "", height = math.floor(h * 10 + .5),
      weight = math.floor(w * 10 + .5) },
    -- .rgba references leave the base art path to the animated-sprite mod.
    -- A placeholder PNG override would mask that mod when Compat wraps last.
    spriteFront = 'data/generated/gba/pokemon/front/' .. tostring(M.slot(source.dex)) .. '.rgba',
    spriteBack = 'data/generated/gba/pokemon/back/' .. tostring(M.slot(source.dex)) .. '.rgba',
  }
end

function M.install(mod, national)
  local P = require('src.core.game3.pokemon')
  local Schemas = require('src.mods.Schemas')
  local Dex = require('src.core.game3.dex')
  local PokedexData = require('src.core.game3.pokedex_data')
  local ratesPath = 'data/species/generated/gender_rates.lua'
  M.genderRates = assert(load(assert(mod:read(ratesPath)), '@' .. mod.path .. '/' .. ratesPath))()
  if not P._moveNames and P.moveName then P.moveName(1) end
  local Starts = assert(load(assert(mod:read('src/gen3starts.lua'))))()
  local repaired, substitutions = Starts.repair(national,
    function(path) return mod:read(path) end, P._moveNames)
  mod.log:info(('Game3 learnsets rebuilt: %d species, %d Gen 3 substitutions')
    :format(repaired or 0, substitutions or 0))
  local machineSource = mod:read('data/species/generated/firered_machines.lua')
  local machineChunk = machineSource and load(machineSource, 'firered_machines')
  local machineCompat = machineChunk and machineChunk() or {}

  -- Gen 3's internal species slots diverge from National Dex numbers after
  -- Celebi. A caught Bidoof is slot 463, while National #463 is Lickilicky.
  -- Opaque party mons always carry an internal slot, so never reinterpret a
  -- slot that is registered in the active Game3 pack.
  if not P.__completeDexInternalIds then
    P.__completeDexInternalIds = true
    local originalSpeciesOf = P.speciesOf
    P.speciesOf = function(mon)
      local raw = mon and (mon.species or mon.speciesId or mon.id)
      local n = tonumber(raw)
      if n and n >= 1 and P.keyName(n) then return n end
      return originalSpeciesOf(mon)
    end
  end

  -- The National list is expressed as National numbers, but the Dex bitsets,
  -- party, battle and sprite registries are all keyed by internal slots.
  Dex.NATIONAL_MAX = 1025
  P.nationalPokedexNumber = P.national
  if not PokedexData.__completeDexNationalList then
    PokedexData.__completeDexNationalList = true
    local originalOrder = PokedexData.getOrderList
    PokedexData.getOrderList = function(orderKey, dex)
      if orderKey == 'numerical_national' then
        local list = {}
        for nat = 1, 1025 do
          local slot = P.speciesFromNational(nat)
          if slot then list[#list + 1] = slot end
        end
        return list
      end
      return originalOrder(orderKey, dex)
    end
    PokedexData.isNationalUnlocked = function() return true end

    local originalSeen, originalCaught = Dex.countSeen, Dex.countCaught
    Dex.countSeen = function(dex, mode)
      if tostring(mode or 'kanto'):lower() ~= 'national' then return originalSeen(dex, mode) end
      local count = 0
      for nat = 1, 1025 do
        local slot = P.speciesFromNational(nat)
        if slot and Dex.isSeen(dex, slot) then count = count + 1 end
      end
      return count
    end
    Dex.countCaught = function(dex, mode)
      if tostring(mode or 'kanto'):lower() ~= 'national' then return originalCaught(dex, mode) end
      local count = 0
      for nat = 1, 1025 do
        local slot = P.speciesFromNational(nat)
        if slot and Dex.isCaught(dex, slot) then count = count + 1 end
      end
      return count
    end
    Dex.countOwned = Dex.countCaught
  end
  local records, ops = {}, {}
  local addedSlots = {}
  for id, source in pairs(national.register or {}) do
    if not source.form and source.dex > 386 and source.dex <= 1025 then
      local row = M.record(source, machineCompat[id])
      row.name = source.name:upper()
      records[id], ops[id] = row, true
      addedSlots[row.index] = true
    end
  end
  local function repairSavedGender(session)
    if not session then return end
    local repaired = 0
    local function repair(mon)
      if type(mon) ~= 'table' or mon.gender ~= 'U' then return end
      local slot = tonumber(mon.species)
      if not addedSlots[slot] or tonumber(mon.personality) == nil then return end
      local gender = P.gender(slot, mon.personality)
      if gender == 'U' then return end
      mon.gender = gender
      repaired = repaired + 1
    end
    for _, mon in pairs(session.party or {}) do repair(mon) end
    local storage = session.storage
    for _, box in pairs((storage and storage.boxes) or {}) do
      for _, mon in pairs(box.mons or {}) do repair(mon) end
    end
    if repaired > 0 then
      mod.log:info(('Game3 saved Pokemon genders repaired: %d'):format(repaired))
    end
  end
  local registry = {ops=ops, get=function(_,id) return records[id] end}
  local function apply()
    if not P._names then return end -- Wait for the actual ROM pack.
    -- Schemas.lua (0.3.18) caches the species-name index.  When gen3Write
    -- allocates a previously unseen slot, it accidentally caches the ID
    -- string in place of the numeric slot.  The loader's later merge then
    -- feeds that string to vanillaSprite's %d path and aborts the whole mod
    -- load.  Give it a fresh, complete names table before its first write.
    local names = {}
    for slot, name in pairs(P._names) do names[slot] = name end
    for _, row in pairs(records) do names[row.index] = row.name end
    P._names = names
    Schemas.REGISTRIES.pokemon.gen3Write(P, registry)
    P._byName = P._byName or {}
    P._national = P._national or {}
    P._national.toSpecies = P._national.toSpecies or {}
    P._national.toNational = P._national.toNational or {}
    local count = 0
    for id,row in pairs(records) do
      local slot = row.index
      P._names[slot] = row.name
      -- Match Pokemon.speciesFromName's punctuation-insensitive key format.
      P._byName[id:upper():gsub('[^A-Z0-9]','')] = slot
      P._byName[row.name:upper():gsub('[^A-Z0-9]','')] = slot
      P._national.toSpecies[row.dex] = slot
      P._national.toNational[slot] = row.dex
      count = count + 1
    end
    mod.log:info('Game3 extended species restored: ' .. count)
    local Runtime = require('src.core.game3.runtime')
    repairSavedGender(Runtime.getSession())
  end
  P.onReload(apply, 'national_dex_firered')
  apply()
  local Evolutions = assert(load(assert(mod:read('src/gen3evolutions.lua')), '@gen3evolutions.lua'))()
  local ItemsData = require('src.core.game3.items_data')
  Evolutions.install(mod, P, M.slot, function(key) return ItemsData.toNumericId(key) end)
end

return M
