-- Present the same wild species to Emerald's Area screen that the encounter
-- replacement can produce. The native screen only checks 5-12 ROM slots per
-- terrain, so each header is reduced to the species currently being queried.
local M = {}

local TERRAINS = { "land", "water", "fishing", "rocks" }
local GROUPS = { "common", "rare", "featured", "special" }

local function hasCandidate(pool, national)
  for _, group in ipairs(GROUPS) do
    for _, mon in ipairs(pool[group] or {}) do
      if mon.id == national then return true end
    end
  end
  return false
end

local function hasNative(source, species)
  for _, slot in ipairs(source.slots or {}) do
    if slot.species == species then return true end
  end
  return false
end

function M.build(headers, species, alteringCaveId, policy, choice, postgame)
  local Pokemon = require("src.core.game3.pokemon")
  local MapCatalog = require("src.import.gba.map_catalog")
  local national = Pokemon.national(species)
  local out = {}
  for key, header in pairs(headers) do
    if type(key) == "string" and key:match("^%d+:%d+$") and type(header) == "table" then
      local g, n = tonumber(header.mapGroup), tonumber(header.mapNum)
      local mapId = g and n and MapCatalog.mapIdFor(g, n)
      if mapId then
        local active = header.variants and header.variants[(alteringCaveId or 0) + 1] or header
        local row = { mapGroup = g, mapNum = n }
        for _, terrain in ipairs(TERRAINS) do
          local source = active[terrain] or (terrain == "rocks" and active.rockSmash)
          if source and source.slots then
            local found, nativePossible = false, false
            local levels = {}
            for _, slot in ipairs(source.slots) do
              local lo = tonumber(slot.minLevel) or tonumber(slot.maxLevel)
              local hi = tonumber(slot.maxLevel) or lo
              if lo then levels[lo] = true end
              if hi then levels[hi] = true end
            end
            for level in pairs(levels) do
              local pool, loc = policy:eligiblePool(mapId, choice, level, terrain,
                { postgame = postgame })
              if not loc then
                nativePossible = true
              else
                if national and hasCandidate(pool, national) then found = true end
                -- With only featured encounters, the normal roll can still
                -- fall through to the ROM species.
                if #(pool.common or {}) == 0 and #(pool.rare or {}) == 0
                    and (#(pool.special or {}) == 0 or #(pool.featured or {}) > 0) then
                  nativePossible = true
                end
              end
            end
            if nativePossible and hasNative(source, species) then found = true end
            row[terrain] = { slots = found and { { species = species } } or {} }
          end
        end
        out[key] = row
      else
        out[key] = header
      end
    else
      out[key] = header
    end
  end
  return out
end

return M
