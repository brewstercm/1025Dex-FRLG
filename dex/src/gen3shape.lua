-- FireRed shape adapter. National Dex carries Gen 1/2-friendly source data;
-- FireRed's registry expects split Special stats and numbered species slots.
-- ROM species IDs are NOT National Dex IDs. Preserve native Gen 1-3 slots,
-- including FRLG's unused/Unown slots, and allocate additions above them.
local M = { ROM_DEX_MAX = 386 }

-- Loaded during install() through mod:read(); mod-local files are not on
-- package.path. Keeping this state on the shape module also lets the later
-- nationaldex.lua registration calls reuse the same translated evolution data.
M._evolutionCompat = nil
M._evolutionData = nil
M._evolutionMod = nil

local function gameplayEvolutions(source, numericTargets, minTargetDex)
  if not source or source.form or not M._evolutionCompat
      or not M._evolutionData or not M._evolutionMod then
    return {}
  end
  return M._evolutionCompat.rows(
    M._evolutionMod, source.id, M._evolutionData[source.id],
    M.slot, numericTargets, minTargetDex)
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
  local patch = { types = record.types }
  local generated = M._evolutionData and M._evolutionData[record.id]

  -- A native FireRed species with a trade evolution must have its full
  -- evolution list translated/replaced; otherwise the cartridge's old
  -- trade-only row would still remain active. Species without trade
  -- evolutions keep the safer append-only behavior for post-Gen-3 branches.
  if generated and M._evolutionCompat
      and M._evolutionCompat.hasTradeEvolution
      and M._evolutionCompat.hasTradeEvolution(generated) then
    local full = gameplayEvolutions(record, false, nil)
    if #full > 0 then patch.evolutions = full end
  else
    local later = gameplayEvolutions(record, false, M.ROM_DEX_MAX)
    if #later > 0 then
      patch.evolutions = { __append = later }
    end
  end

  return patch
end

function M.record(source, machines, numericEvolutionTargets)
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
    growthRate = source.growthRate or "MEDIUM_FAST",
    learnset = source.learnset or {}, tmhm = machines or {},
    evolutions = gameplayEvolutions(source, numericEvolutionTargets),
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
  local machineSource = mod:read('data/species/generated/firered_machines.lua')
  local machineChunk = machineSource and load(machineSource, 'firered_machines')
  local machineCompat = machineChunk and machineChunk() or {}

  -- Gameplay evolution compatibility is optional so a missing/partial helper
  -- never prevents the rest of the National Dex from loading.
  local evoSource = mod:read('src/gen3evolutions.lua')
  if evoSource then
    local evoChunk, evoCompileErr =
      load(evoSource, '@' .. mod.path .. '/src/gen3evolutions.lua')
    if evoChunk then
      local ok, compat = pcall(evoChunk)
      if ok and type(compat) == 'table' and type(compat.load) == 'function'
          and type(compat.rows) == 'function' then
        M._evolutionCompat = compat
        M._evolutionMod = mod
        local okData, data = pcall(compat.load, mod)
        if okData and type(data) == 'table' then
          M._evolutionData = data
        else
          mod.log:warn('FireRed gameplay evolution data failed to load (%s)',
            tostring(data))
        end
      else
        mod.log:warn('src/gen3evolutions.lua failed while loading (%s)',
          tostring(compat))
      end
    else
      mod.log:warn('src/gen3evolutions.lua failed to compile (%s)',
        tostring(evoCompileErr))
    end
  end

  -- Kanto #1-151 live in national.patch rather than national.register, so
  -- nationaldex.lua never calls romPatch() for them. Enrich those existing
  -- patches in memory with the same append-only post-Gen-3 evolution rows.
  -- This is what makes Primeape -> Annihilape, Eevee's later branches, etc.
  -- reach the normal mod registry without touching FireRed's original rows.
  if M._evolutionCompat and M._evolutionData and type(national.patch) == 'table' then
    for id, partial in pairs(national.patch) do
      local generated = M._evolutionData[id]
      if generated then
        if M._evolutionCompat.hasTradeEvolution
            and M._evolutionCompat.hasTradeEvolution(generated) then
          -- Replace the full native list so FireRed's original trade-only row
          -- disappears and the single-save level/item rule takes its place.
          local full = M._evolutionCompat.rows(
            mod, id, generated, M.slot, false, nil)
          if #full > 0 then partial.evolutions = full end
        else
          local later = M._evolutionCompat.rows(
            mod, id, generated, M.slot, false, M.ROM_DEX_MAX)
          if #later > 0 then
            partial.evolutions = { __append = later }
          end
        end
      end
    end
  end

  -- Gen 3's internal species slots diverge from National Dex numbers after
  -- Celebi. A caught Bidoof is slot 463, while National #463 is Lickilicky.
  -- Opaque party mons always carry an internal slot, so never reinterpret a
  -- slot that is registered in the active FireRed pack.
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
  for id, source in pairs(national.register or {}) do
    if not source.form and source.dex > 386 and source.dex <= 1025 then
      local row = M.record(source, machineCompat[id], true)
      row.name = source.name:upper()
      records[id], ops[id] = row, true
    end
  end
  local registry = {ops=ops, get=function(_,id) return records[id] end}
  local function apply()
    if not P._names then return end -- Wait for the actual ROM pack.
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
    mod.log:info('FireRed extended species restored: ' .. count)
  end
  P.onReload(apply, 'national_dex_firered')
  apply()
end

return M
