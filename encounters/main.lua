return function(mod)
  local GameVersion=require("src.core.GameVersion")
  if GameVersion.generation() ~= 3 then return end
  local function data(path)
    return assert(load(assert(mod:read(path)), "@"..path))()
  end
  local Policy=data("policy.lua")
  local locations=data("locations.lua")
  for _,loc in ipairs(data("hoenn_locations.lua")) do locations[#locations+1]=loc end
  local Progress=data("progress.lua")
  local policy=Policy.new(data("roster.lua"),locations,math.random,Progress.postgame)
  local OPTION_KEY="fireredGenEncounterPool"
  local active=Policy.default

  local function optionBlock(engine)
    return require("src.core.game3.options").block(engine)
  end
  local function readSelection()
    local Runtime=require("src.core.game3.runtime")
    local session=Runtime and Runtime.getSession and Runtime.getSession()
    local engine=session and session.engineOptions
    if type(engine)=="table" then
      local _,n=policy:choice(optionBlock(engine)[OPTION_KEY]); active=n
    elseif session and type(session.options)=="table" then
      local _,n=policy:choice(session.options[OPTION_KEY]); active=n
    end
    return active
  end

  -- Keep the maintained FireRed/LeafGreen Area page aligned with both the
  -- ordinary encounter pools and the League-gated special pools.
  if GameVersion.get() ~= "emerald" then
    local Areas=data("pokedex_areas.lua")
    local okAreas,areaErr=pcall(Areas.install,mod,policy,readSelection,Progress.postgame)
    if not okAreas then
      mod.log:warn("FRLG Pokedex Area integration unavailable: "..tostring(areaErr))
    end
  end

  local okRows,Rows=pcall(require,"src.ui.game3.option_rows")
  if okRows and Rows and type(Rows.build)=="function" and not Rows.__completeDexWilds then
    Rows.__completeDexWilds=true
    local original=Rows.build
    Rows.build=function(ctx)
      local rows=original(ctx)
      for i=#rows,1,-1 do if rows[i].id==OPTION_KEY then table.remove(rows,i) end end
      local opts=optionBlock(ctx.options)
      local _,n=policy:choice(opts[OPTION_KEY]); active=n; opts[OPTION_KEY]=n
      rows[#rows+1]={id=OPTION_KEY,label="WILD GENS",
        value=function(c)
          local block=optionBlock(c.options)
          local choice,index=policy:choice(block[OPTION_KEY] or active)
          active=index; return choice.label
        end,
        step=function(c,dir)
          local block=optionBlock(c.options)
          local _,current=policy:choice(block[OPTION_KEY] or active)
          local nextIndex=current+((dir and dir<0) and -1 or 1)
          if nextIndex<1 then nextIndex=#Policy.choices elseif nextIndex>#Policy.choices then nextIndex=1 end
          block[OPTION_KEY]=nextIndex; active=nextIndex
          local Runtime=require("src.core.game3.runtime")
          local session=Runtime and Runtime.getSession and Runtime.getSession()
          if session then session.options=block; session.engineOptions=c.options end
          return true
        end}
      return rows
    end
  else mod.log:warn("Game3 OPTIONS row hook unavailable") end

  -- Carry the source of the encounter with the foe, including fishing while
  -- the player is standing on land. No global "last encounter" state.
  local Encounters=require("src.core.game3.encounters")
  if not Encounters.__completeDexTerrain then
    Encounters.__completeDexTerrain=true
    local step=Encounters.onStep
    if step then
      Encounters.onStep=function(mapId,terrain,opts)
        local enc=step(mapId,terrain,opts)
        if type(enc)=="table" then
          local actual=terrain
          if not actual and opts and opts.x and opts.y and Encounters.terrainAt then
            actual=Encounters.terrainAt(opts.x,opts.y)
          end
          enc.__completeDexTerrain=actual or "land"
          enc.__completeDexMap=mapId
        end
        return enc
      end
    end
    for _,entry in ipairs({{"rollFishing","fishing"},{"rollRocks","rocks"}}) do
      local fn,terrain=entry[1],entry[2]
      local original=Encounters[fn]
      if original then
        Encounters[fn]=function(mapId, ...)
          local enc=original(mapId, ...)
          if type(enc)=="table" then
            enc.__completeDexTerrain=terrain
            enc.__completeDexMap=mapId
          end
          return enc
        end
      end
    end
  end

  local Bridge=require("src.core.game3.battle_bridge")
  if not Bridge.__completeDexWilds then
    Bridge.__completeDexWilds=true
    local original=Bridge.start
    Bridge.start=function(owner,game,foe,opts)
      -- Only replace a rolled encounter marked by our onStep/fishing/rock
      -- hooks. Scripted and legendary battles use the exact ROM species.
      if opts and opts.wild and not opts.__completeDexExact
          and not (opts.legendary or opts.wildScripted or opts.roamer
            or opts.firstBattle or opts.oldManTutorial)
          and type(foe) == "table" and foe.__completeDexTerrain
          and not (foe.legendary or foe.wildScripted or foe.roamer
            or foe.specialWild) then
        local Runtime=require("src.core.game3.runtime")
        local session=Runtime.getSession and Runtime.getSession()
        local mapId=foe.__completeDexMap or (session and session.map) or (game and game.currentMap)
        local okCatalog,Catalog=pcall(require,"src.import.gba.map_catalog")
        if okCatalog and Catalog.resolve then mapId=Catalog.resolve(mapId) end
        local level=type(foe)=="table" and tonumber(foe.level) or nil
        local terrain=type(foe)=="table" and foe.__completeDexTerrain
        if not terrain then
          local Player=require("src.core.game3.player")
          terrain=(Player and Player.surfing) and "water" or "land"
        end
        local mon,newLevel=policy:choose(mapId,readSelection(),level,terrain)
        if mon then
          local Pokemon=require("src.core.game3.pokemon")
          local slot=Pokemon.speciesFromName(mon.name)
          if slot and Pokemon.keyName(slot) then
            foe={species=slot,speciesId=slot,level=newLevel,item=nil}
            if Pokemon._speciesMeta then
              Pokemon._speciesMeta[slot]=Pokemon._speciesMeta[slot] or {}
              Pokemon._speciesMeta[slot].catchRate=mon.catchRate
            end
          end
        end
      end
      return original(owner,game,foe,opts)
    end
  end
  -- Visible wilds must choose here instead of using a stale embedded policy.
  mod.exports.chooseWildEncounter = function(mapId, terrain, nativeLevel)
    local okCatalog,Catalog=pcall(require,"src.import.gba.map_catalog")
    if okCatalog and Catalog.resolve then mapId=Catalog.resolve(mapId) end
    local mon,level=policy:choose(mapId,readSelection(),nativeLevel,terrain)
    if not mon then return nil end
    local P=require("src.core.game3.pokemon")
    local species=P.speciesFromName(mon.name)
    if not species or not P.keyName(species) then return nil end
    return mon.id,species,level,mon.catchRate
  end
  -- Live pool API: internal species IDs and levels match the battle policy.
  mod.exports.dexnavEncounters = function(mapId)
    local okCatalog,Catalog=pcall(require,"src.import.gba.map_catalog")
    if okCatalog and Catalog.resolve then mapId=Catalog.resolve(mapId) end
    if not policy:location(mapId) then return nil end
    local native = Encounters.tableFor(mapId)
    if type(native) ~= "table" then return nil end
    local out = {}
    local P = require("src.core.game3.pokemon")
    for _, terrain in ipairs({"land", "water"}) do
      local area = native[terrain] or (terrain == "land" and native.grass)
      if area then
        local pool, loc = policy:pool(mapId, readSelection(), terrain)
        local slots, seen = {}, {}
        for _, group in ipairs({pool.common, pool.rare, pool.featured, pool.special}) do
          for _, mon in ipairs(group or {}) do
            local species = P.speciesFromName(mon.name)
            if species and not seen[species] then
              seen[species] = true
              local lo,hi=math.min(loc.hi,math.max(loc.lo,mon.gate or 1)),loc.hi
              if mon.special then lo,hi=Policy.specialLevelRange(mon) end
              slots[#slots+1]={species=species,minLevel=lo,maxLevel=hi}
            end
          end
        end
        out[terrain] = {slots=slots}
      end
    end
    return out
  end
  mod.log:info("Game3 generation selector installed: all 1025 species, immediate filtering")
end
