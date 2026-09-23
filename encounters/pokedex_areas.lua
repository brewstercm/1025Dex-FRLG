-- Dynamic FireRed Pokédex Area integration for 1025Dex encounters.
--
-- The encounter component replaces the native wild foe at battle start rather
-- than rewriting FireRed's encounter tables. The stock Pokédex therefore has
-- no way to know which 1025Dex species can actually appear on each map.
--
-- This adapter mirrors the encounter policy and supplies the Area page with
-- the set of species that can really be encountered under the current
-- WILD GENS selection.
--
-- It also preserves native FireRed encounter locations on maps where the
-- selected 1025Dex pool can fall through to the original encounter.

local M = {}

local function addArea(byNational, national, area)
  if not national or not area then return end
  local list = byNational[national]
  if not list then
    list = {}
    byNational[national] = list
  end
  for _, existing in ipairs(list) do
    if existing == area then return end
  end
  list[#list + 1] = area
end

local function nationalFor(Pokemon, raw)
  local slot = tonumber(raw)
  if not slot and type(raw) == "string" and Pokemon.speciesFromName then
    slot = Pokemon.speciesFromName(raw)
  end
  if not slot then return nil end

  if Pokemon.national then
    local national = Pokemon.national(slot)
    if national then return national end
  end

  if Pokemon.nationalPokedexNumber then
    local national = Pokemon.nationalPokedexNumber(slot)
    if national then return national end
  end

  return slot
end

local function addPool(byNational, area, pool)
  for _, key in ipairs({ "common", "rare", "featured" }) do
    for _, mon in ipairs(pool[key] or {}) do
      addArea(byNational, tonumber(mon.id), area)
    end
  end
end

local function addNativeEncounterSpecies(byNational, area, record, Pokemon)
  if type(record) ~= "table" then return end

  -- `grass` is accepted by the Gen 3 registry as an alias while imported
  -- FireRed data normally uses `land`.
  for _, key in ipairs({ "land", "grass", "water", "rocks", "fishing" }) do
    local encounter = record[key]
    if type(encounter) == "table" and type(encounter.slots) == "table" then
      for _, slot in ipairs(encounter.slots) do
        if type(slot) == "table" then
          addArea(byNational, nationalFor(Pokemon, slot.species), area)
        end
      end
    end
  end
end

function M.install(mod, policy, readSelection)
  if type(policy) ~= "table" or type(policy.pool) ~= "function"
      or type(readSelection) ~= "function" then
    return nil, "invalid encounter policy"
  end

  local PokedexData = require("src.core.game3.pokedex_data")
  local Pokemon = require("src.core.game3.pokemon")

  if PokedexData.__completeDexEncounterAreas then
    return true
  end
  PokedexData.__completeDexEncounterAreas = true

  local original = PokedexData.getWildAreasForSpecies
  local okMapSections, MapSections =
    pcall(require, "src.import.gba.map_sections_extract")

  local cachedChoice = nil
  local cachedAreas = {}

  local function dexAreaForMap(mapId)
    PokedexData.init()

    local areaData = PokedexData._areaData or {}
    local markers = areaData.markers or {}
    local mapsecToArea = areaData.mapsecToArea or {}
    local dexArea = nil

    -- Use the exact same map-section resolver the FireRed Pokédex data layer
    -- uses. This correctly collapses floors/submaps such as MT MOON 1F/B1F/B2F
    -- into DEX_AREA_MT_MOON and handles the Sevii Islands.
    if okMapSections and MapSections and MapSections.getInfo then
      local ok, info = pcall(MapSections.getInfo, nil, mapId)
      if ok and type(info) == "table" and info.id then
        dexArea = mapsecToArea[info.id]
      end
    end

    -- Straightforward maps such as FR_ROUTE_1 also have a directly named
    -- DEX_AREA marker, so retain the engine's fallback convention.
    if not dexArea and type(mapId) == "string" then
      local normalized = "DEX_AREA_"
        .. mapId:gsub("^FR_", "")
          :gsub("^SEVII_", "")
          :gsub("([a-z])([A-Z])", "%1_%2")
          :upper()

      if markers[normalized] then
        dexArea = normalized
      end
    end

    if dexArea and markers[dexArea] then
      return dexArea
    end
    return nil
  end

  local function rebuild(choiceIndex)
    local byNational = {}
    local maps = {}

    -- Read the whole merged encounter registry rather than only locations.lua.
    -- That means the Area page follows the same fallback mapping on every
    -- FireRed map where a wild encounter can actually occur.
    for mapId, record in mod.content.encounters:each() do
      maps[#maps + 1] = { id = mapId, record = record }
    end

    table.sort(maps, function(a, b)
      return tostring(a.id) < tostring(b.id)
    end)

    local mapped = 0
    for _, row in ipairs(maps) do
      local area = dexAreaForMap(row.id)
      if area then
        local pool = policy:pool(row.id, choiceIndex)

        if type(pool) == "table" then
          addPool(byNational, area, pool)

          -- Bridge.start falls back to the untouched FireRed foe only when
          -- both of these replacement lists are empty. Route 1 can still have
          -- featured encounters in that state, so both featured AND native
          -- species are legitimately possible there.
          if #(pool.common or {}) == 0 and #(pool.rare or {}) == 0 then
            addNativeEncounterSpecies(byNational, area, row.record, Pokemon)
          end
        else
          -- Defensive fallback: if the policy cannot describe a map, FireRed's
          -- original encounter remains the real encounter.
          addNativeEncounterSpecies(byNational, area, row.record, Pokemon)
        end

        mapped = mapped + 1
      end
    end

    for _, areas in pairs(byNational) do
      table.sort(areas)
    end

    cachedChoice = choiceIndex
    cachedAreas = byNational

    local speciesCount, pairCount = 0, 0
    for _, areas in pairs(byNational) do
      speciesCount = speciesCount + 1
      pairCount = pairCount + #areas
    end

    mod.log:info(
      "FireRed Pokedex Area encounter index rebuilt: choice %d, %d maps, %d species, %d area links",
      tonumber(choiceIndex) or 0, mapped, speciesCount, pairCount
    )
  end

  PokedexData.getWildAreasForSpecies = function(speciesId)
    PokedexData.init()

    local choiceIndex = readSelection()
    if cachedChoice ~= choiceIndex then
      rebuild(choiceIndex)
    end

    local national = nationalFor(Pokemon, speciesId)
    if national and national >= 1 and national <= 1025 then
      return cachedAreas[national] or {}
    end

    return original(speciesId)
  end

  return true
end

return M
