return function(mod)
  local GameVersion=require("src.core.GameVersion")
  if GameVersion.generation() ~= 3 then return end
  local function data(path)
    return assert(load(assert(mod:read(path)), "@"..path))()
  end
  local Policy=data("policy.lua")
  local policy=Policy.new(data("roster.lua"),data("locations.lua"),math.random)
  local OPTION_KEY="fireredGenEncounterPool"
  local active=Policy.default

  local function optionBlock(engine)
    return require("src.core.game3.options").block(engine)
  end
  local function readSelection()
    local Runtime=package.loaded["src.core.game3.runtime"]
    local session=Runtime and Runtime.getSession and Runtime.getSession()
    local engine=session and session.engineOptions
    if type(engine)=="table" then
      local _,n=policy:choice(optionBlock(engine)[OPTION_KEY]); active=n
    elseif session and type(session.options)=="table" then
      local _,n=policy:choice(session.options[OPTION_KEY]); active=n
    end
    return active
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
          local Runtime=package.loaded["src.core.game3.runtime"]
          local session=Runtime and Runtime.getSession and Runtime.getSession()
          if session then session.options=block; session.engineOptions=c.options end
          return true
        end}
      return rows
    end
  else mod.log:warn("FireRed OPTIONS row hook unavailable") end

  local Bridge=require("src.core.game3.battle_bridge")
  if not Bridge.__completeDexWilds then
    Bridge.__completeDexWilds=true
    local original=Bridge.start
    Bridge.start=function(owner,game,foe,opts)
      if opts and opts.wild and not opts.__completeDexExact then
        local Runtime=require("src.core.game3.runtime")
        local session=Runtime.getSession and Runtime.getSession()
        local mapId=(session and session.map) or (game and game.currentMap)
        local level=type(foe)=="table" and tonumber(foe.level) or nil
        local mon,newLevel=policy:choose(mapId,readSelection(),level)
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
  mod.log:info("FireRed generation selector installed: all 1025 species, immediate filtering")
end
