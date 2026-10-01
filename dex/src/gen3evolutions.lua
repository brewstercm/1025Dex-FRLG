-- Install the shipped evolution graph in FireRed's numeric species registry.
-- Species from National #387 onward have no ROM evolution rows of their own.
local M = {}

-- Branches where a held trade item should take priority over a normal
-- level-up evolution.  Keeping this data-driven lets later trade-item
-- branches use the same native evolution.check / pokemon.evolved path.
local LEVEL_HELD_PRIORITY = {
  {
    sourceDex = 79,          -- Slowpoke
    targetDex = 199,         -- Slowking
    normalTargetDex = 80,    -- Slowbro
    minLevel = 37,
    itemKeys = {"KINGS_ROCK", "KING'S_ROCK", "KING'S ROCK", "KINGSROCK"},
    consume = true,
  },
  {
    sourceDex = 61,          -- Poliwhirl
    targetDex = 186,         -- Politoed
    minLevel = 1,
    itemKeys = {"KINGS_ROCK", "KING'S_ROCK", "KING'S ROCK", "KINGSROCK"},
    consume = true,
  },
  {
    sourceDex = 95,          -- Onix
    targetDex = 208,         -- Steelix
    minLevel = 1,
    itemKeys = {"METAL_COAT", "METAL COAT", "METALCOAT"},
    consume = true,
  },
  {
    sourceDex = 123,         -- Scyther
    targetDex = 212,         -- Scizor
    minLevel = 1,
    itemKeys = {"METAL_COAT", "METAL COAT", "METALCOAT"},
    consume = true,
  },
  {
    sourceDex = 117,         -- Seadra
    targetDex = 230,         -- Kingdra
    minLevel = 1,
    itemKeys = {"DRAGON_SCALE", "DRAGON SCALE", "DRAGONSCALE"},
    consume = true,
  },
  {
    sourceDex = 137,         -- Porygon
    targetDex = 233,         -- Porygon2
    minLevel = 1,
    itemKeys = {"UP_GRADE", "UP-GRADE", "UP GRADE", "UPGRADE"},
    consume = true,
  },
  {
    sourceDex = 366,         -- Clamperl
    targetDex = 367,         -- Huntail
    minLevel = 1,
    itemKeys = {"DEEP_SEA_TOOTH", "DEEP SEA TOOTH", "DEEPSEATOOTH"},
    consume = true,
  },
  {
    sourceDex = 366,         -- Clamperl
    targetDex = 368,         -- Gorebyss
    minLevel = 1,
    itemKeys = {"DEEP_SEA_SCALE", "DEEP SEA SCALE", "DEEPSEASCALE"},
    consume = true,
  },
}

local function decode(read, path)
  local source = assert(read(path), 'Missing evolution data: ' .. path)
  return assert(load(source, '@' .. path))()
end

local function resolveItem(itemId, keys)
  if type(itemId) ~= 'function' then return nil end
  for _, key in ipairs(keys or {}) do
    local ok, value = pcall(itemId, key)
    value = ok and tonumber(value) or nil
    if value and value > 0 then return value end
  end
  return nil
end

local function heldItemId(mon, itemId)
  local raw = mon and mon.item
  if raw == nil or tonumber(raw) == 0 then raw = mon and mon.heldItem end
  local numeric = tonumber(raw)
  if numeric then return numeric end
  if raw ~= nil and type(itemId) == 'function' then
    local ok, value = pcall(itemId, raw)
    if ok then return tonumber(value) end
  end
  return nil
end

function M.build(read, slot, itemId, useCompat)
  local index = decode(read, 'data/evolutions/generated/index.lua')
  local shards, rows, conditions, counts = {}, {}, {},
    {level=0, trade=0, item=0, fallback=0, held=0, compat=0}
  local function record(id)
    local shard = index[id]
    if not shard then return end
    if not shards[shard] then
      shards[shard] = decode(read, ('data/evolutions/generated/%03d.lua'):format(shard))
    end
    return shards[shard][id]
  end
  for id in pairs(index) do
    local source = record(id)
    if source and not source.form and type(source.dex) == 'number' and source.dex <= 1025 then
      local from = slot(source.dex)
      if from then
        local fallback = {}
        for _, edge in ipairs(source.evolvesInto or {}) do
          local destination = record(edge.id)
          if destination and not destination.form and destination.dex == edge.dex then
            local target = slot(edge.dex)
            local chosen
            for _, method in ipairs(edge.methods or {}) do
              if method.isDefault then chosen = method; break end
            end
            chosen = chosen or (edge.methods or {})[1]
            if target and chosen then
              local method, param, guard
              if chosen.trigger == 'trade' then
                method, param = 4, 36
                counts.trade = counts.trade + 1
              elseif chosen.trigger == 'level-up' then
                param = tonumber(chosen.level)
                if param then
                  method = 4
                  if chosen.relativePhysicalStats then
                    method = ({[1]=8, [0]=9, [-1]=10})[chosen.relativePhysicalStats] or 4
                  elseif id == 'WURMPLE' then
                    method = edge.id == 'SILCOON' and 11 or 12
                  elseif id == 'NINCADA' and edge.id == 'NINJASK' then
                    method = 13
                  end
                elseif chosen.minHappiness or chosen.knownMove or chosen.minBeauty then
                  method, param, guard = 4, 1, chosen
                end
                -- A conditional level must never evolve to the wrong branch.
                if method and (chosen.timeOfDay or chosen.gender or chosen.knownMove
                    or chosen.partySpecies or chosen.partyType or chosen.minHappiness
                    or chosen.minBeauty or chosen.heldItem or chosen.knownMoveType
                    or chosen.location or chosen.minSteps or chosen.usedMove) then
                  if chosen.heldItem or chosen.knownMoveType or chosen.location
                      or chosen.minSteps or chosen.usedMove then
                    method = nil -- This action is handled by the level 36 fallback below.
                  else
                    guard = chosen
                  end
                end
                if method then counts.level = counts.level + 1 end
              elseif chosen.trigger == 'shed' then
                method, param = 14, 20
                counts.level = counts.level + 1
              elseif chosen.trigger == 'use-item' and chosen.item then
                local key = chosen.item:upper():gsub('[^A-Z0-9]+', '_')
                param = itemId and itemId(key)
                if param then method = 7; counts.item = counts.item + 1 end
              end
              if method then
                rows[from] = rows[from] or {}
                rows[from][#rows[from]+1] = {method=method,param=param,target=target}
                if guard then
                  conditions[from] = conditions[from] or {}
                  conditions[from][target] = guard
                end
              else
                fallback[#fallback+1] = {method=4,param=36,target=target}
              end
            end
          end
        end
        if #fallback > 0 then
          rows[from] = rows[from] or {}
          -- Each level-up has one result. When two or three special evolutions
          -- share a parent, use the ROM's attack/defense split so every
          -- destination remains reachable at level 36.
          local split = #fallback == 2 and {8,4}
            or #fallback == 3 and {8,9,10}
          for i, entry in ipairs(fallback) do
            if split then entry.method = split[i] end
            if i <= 3 or #fallback == 1 then
              table.insert(rows[from], 1, entry)
              counts.fallback = counts.fallback + 1
            end
          end
        end
      end
    end
  end

  -- Replace only the explicitly listed trade-item branch with a normal
  -- level row guarded by its held item. It is appended after the ordinary
  -- branch so the engine's last-matching-row behavior gives it priority.
  for _, spec in ipairs(LEVEL_HELD_PRIORITY) do
    local from = slot(spec.sourceDex)
    local target = slot(spec.targetDex)
    local normalTarget = spec.normalTargetDex and slot(spec.normalTargetDex) or nil
    local requiredItem = resolveItem(itemId, spec.itemKeys)
    if from and target and requiredItem then
      rows[from] = rows[from] or {}
      for i = #rows[from], 1, -1 do
        if rows[from][i].target == target then
          table.remove(rows[from], i)
          counts.trade = math.max(0, counts.trade - 1)
        end
      end
      rows[from][#rows[from]+1] = {
        method=4, param=spec.minLevel, target=target,
      }
      conditions[from] = conditions[from] or {}
      conditions[from][target] = {
        minLevel=spec.minLevel,
        heldItemId=requiredItem,
        consumeHeldItem=spec.consume == true,
      }
      if normalTarget then
        local normalRule = conditions[from][normalTarget] or {}
        normalRule.unlessHeldItemId = requiredItem
        conditions[from][normalTarget] = normalRule
      end
      counts.held = counts.held + 1
    end
  end

  -- Keep maintained FRLG compatibility choices for evolutions whose modern
  -- trigger is unavailable in Gen 3. The new held trade-item rules above
  -- take precedence for their targets; Emerald keeps the shipped rules.
  local overridePath = 'data/evolutions/compat_overrides.lua'
  local overrideSource = useCompat and read(overridePath)
  if overrideSource then
    local overrides = assert(load(overrideSource, '@' .. overridePath))()
    local heldTargets = {}
    for _, spec in ipairs(LEVEL_HELD_PRIORITY) do
      heldTargets[spec.targetDex] = true
    end
    for sourceId, targets in pairs(overrides) do
      local source = record(sourceId)
      local from = source and slot(source.dex)
      if from then
        for targetId, rule in pairs(targets) do
          local destination = record(targetId)
          local target = destination and slot(destination.dex)
          if target and not heldTargets[destination.dex] then
            local method, param
            if rule.method == 'EVO_LEVEL' then
              method, param = 4, tonumber(rule.level)
            elseif rule.method == 'EVO_ITEM' then
              method, param = 7, resolveItem(itemId, {rule.item})
            end
            if method and param then
              local list = rows[from] or {}
              local replacement = {method=method, param=param, target=target}
              local replaced = false
              for i, entry in ipairs(list) do
                if entry.target == target then
                  list[i], replaced = replacement, true
                  break
                end
              end
              if not replaced then list[#list+1] = replacement end
              rows[from] = list
              if conditions[from] then conditions[from][target] = nil end
              counts.compat = counts.compat + 1
            end
          end
        end
      end
    end
  end
  return rows, conditions, counts
end

function M.install(mod, pokemon, slot, itemId)
  local conditions = {}
  local function apply()
    if not pokemon._names or not pokemon._evolutions then return end
    local game = require('src.core.GameVersion').get()
    local generated, guards, counts = M.build(
      function(path) return mod:read(path) end, slot, itemId,
      game == 'firered' or game == 'leafgreen')
    conditions = guards
    for from, additions in pairs(generated) do
      local original = pokemon._evolutions[from] or {}
      local merged, targets = {}, {}
      for _, entry in ipairs(additions) do
        merged[#merged+1] = entry
        targets[entry.target] = true
      end
      for _, entry in ipairs(original) do
        if not targets[entry.target] then
          -- FRLG's own traded species obey the same level 36 rule.
          if entry.method == 5 or entry.method == 6 then
            merged[#merged+1] = {method=4,param=36,target=entry.target}
          else
            merged[#merged+1] = entry
          end
        end
      end
      pokemon._evolutions[from] = merged
    end
    -- Some ROM trade rows have no default edge in the generated graph.
    for from, original in pairs(pokemon._evolutions) do
      if not generated[from] then
        for _, entry in ipairs(original) do
          if entry.method == 5 or entry.method == 6 then
            entry.method, entry.param = 4, 36
          end
        end
      end
    end
    mod.log:info(('Game3 evolutions: %d level, %d trade at 36, %d item; %d special evolutions at 36; %d held-item level branches; %d FRLG compatibility rules')
      :format(counts.level, counts.trade, counts.item, counts.fallback, counts.held, counts.compat))
  end
  pokemon.onReload(apply, '1025dex_firered_evolutions')
  apply()
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap('evolution.check', function(nextCheck, game, mon, view, ctx)
      local from = pokemon.speciesOf and pokemon.speciesOf(mon)
        or tonumber(mon and (mon.species or mon.speciesId))
      local rules = conditions[from]
      if rules and ctx and ctx.kind == 'levelup' then
        -- The engine evaluates one evolution row at a time; prohibit a
        -- conditional row unless its own requirement is satisfied.
        local target = tonumber(view and view.speciesId)
          or (view.evolution and tonumber(view.evolution.target))
        local rule = target and rules[target]
        if rule then
          local held = heldItemId(mon, itemId)
          if rule.minLevel and (tonumber(mon.level) or 1) < rule.minLevel then return false end
          if rule.heldItemId and held ~= rule.heldItemId then return false end
          if rule.unlessHeldItemId and held == rule.unlessHeldItemId then return false end
          local friendship = pokemon.friendshipOf and pokemon.friendshipOf(mon)
          if rule.minHappiness and (not friendship or friendship < rule.minHappiness) then return false end
          if rule.minBeauty and (not mon.beauty or mon.beauty < rule.minBeauty) then return false end
          if rule.gender and pokemon.gender(from, mon.personality) ~= rule.gender:upper():sub(1,1) then return false end
          if rule.knownMove then
            local wanted = rule.knownMove:upper():gsub('[^A-Z0-9]', '')
            local found = false
            for i=1,4 do
              local move = pokemon.moveIdAt(mon,i)
              local name = move and pokemon.moveName(move)
              if name and name:upper():gsub('[^A-Z0-9]', '') == wanted then found=true; break end
            end
            if not found then return false end
          end
          if rule.timeOfDay then
            local hour = game and game.world and game.world.hour and game.world:hour()
            if not hour then hour = tonumber(os.date('%H')) end
            if rule.timeOfDay == 'day' and (hour < 6 or hour >= 18) then return false end
            if rule.timeOfDay == 'night' and (hour >= 6 and hour < 18) then return false end
          end
          if rule.partySpecies or rule.partyType then return false end
        end
      end
      return nextCheck(game,mon,view,ctx)
    end)
  end
  if mod.events and mod.events.on then
    mod.events:on('pokemon.evolved', function(event)
      if type(event) ~= 'table' or type(event.mon) ~= 'table' then return end
      local from = tonumber(event.fromSpeciesId)
      local target = tonumber(event.toSpeciesId)
      local rule = from and target and conditions[from] and conditions[from][target]
      if not (rule and rule.consumeHeldItem and rule.heldItemId) then return end
      if heldItemId(event.mon, itemId) ~= rule.heldItemId then return end
      event.mon.item = 0
      event.mon.heldItem = 0
    end)
  end
end
return M
