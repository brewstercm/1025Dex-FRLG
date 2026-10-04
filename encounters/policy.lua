local Policy = {}

-- Aquatic bodies cannot appear on land. Water typing alone is insufficient:
-- Psyduck, Wooper, Mudkip, etc. remain valid shoreline/grass encounters.
local WATER_ONLY = {}
for _,id in ipairs({72,73,90,91,116,117,118,119,120,121,129,130,131,
  382,170,171,211,222,223,224,226,230,318,319,320,321,339,340,349,350,366,367,368,369,370,
  456,457,458,489,490,594,602,603,604,535,550,690,691,692,693,746,779,
  846,847,902,960,961,962,963,964,977,978}) do WATER_ONLY[id]=true end
function Policy.allows(mon, terrain)
  if terrain=='water' or terrain=='fishing' then
    return mon.habitat=='freshwater' or mon.habitat=='sea' or WATER_ONLY[mon.id]==true
  end
  return not WATER_ONLY[mon.id]
end

Policy.choices = {
  {label="GEN 1",first=1,last=151}, {label="GEN 2",first=152,last=251},
  {label="GEN 3",first=252,last=386}, {label="GEN 4",first=387,last=493},
  {label="GEN 5",first=494,last=649}, {label="GEN 6",first=650,last=721},
  {label="GEN 7",first=722,last=809}, {label="GEN 8",first=810,last=905},
  {label="GEN 9",first=906,last=1025}, {label="GEN 1-2",first=1,last=251},
  {label="GEN 1-3",first=1,last=386}, {label="GEN 1-4",first=1,last=493},
  {label="GEN 1-5",first=1,last=649}, {label="GEN 1-6",first=1,last=721},
  {label="GEN 1-7",first=1,last=809}, {label="GEN 1-8",first=1,last=905},
  {label="GEN 1-9",first=1,last=1025},
}
Policy.default = 17

-- Route 1 is deliberately a small beginner pool. These four featured
-- encounters are permanent Route 1 residents, regardless of the selected
-- National Dex generation range.
local ROUTE_1_FEATURED = { 1, 4, 7, 25 }
local ROUTE_1_FEATURED_CHANCE = 10 -- 10% total, shared equally
local ROUTE_1_RESIDENTS = { [1]=true, [4]=true, [7]=true, [25]=true }

-- Fossils were generated as ordinary entries in the original roster, which
-- made Omanyte/Omastar as common as route Pokemon. Treat them as rarities.
local FOSSIL_RARITIES = { [138]=true,[139]=true,[140]=true,[141]=true,[142]=true }

local function isRare(mon)
  if mon.special or FOSSIL_RARITIES[mon.id] then return true end
  return (tonumber(mon.stage) or 1) >= 2 and (tonumber(mon.catchRate) or 255) <= 45
end

local function earlyArea(loc)
  return (tonumber(loc and loc.hi) or 100) <= 9
end

local function safeForEarlyArea(mon, loc)
  if not earlyArea(loc) then return true end
  if ROUTE_1_RESIDENTS[mon.id] then return true end
  -- Nothing rare, evolved, fossil, legendary, or mythical before Brock.
  return not isRare(mon) and (tonumber(mon.stage) or 1) == 1
end

local function key(s)
  return tostring(s or ""):upper():gsub("UNKNOWN_DUNGEON", "CERULEAN_CAVE")
    :gsub("^SEVII_", ""):gsub("^FR_", ""):gsub("^LG_", "")
    :gsub("[^A-Z0-9]", "")
end

local function terrainProfile(loc, terrain)
  if not loc or not loc.hoenn then return loc end
  local area=loc[terrain or "land"]
  if not area then return nil end
  local out={};for k,v in pairs(loc) do out[k]=v end
  for k,v in pairs(area) do out[k]=v end
  return out
end
local function hoennHabitat(mon,loc,terrain)
  if loc.any then return true end
  if terrain=="water" or terrain=="fishing" then
    return mon.habitat==loc.habitat or (WATER_ONLY[mon.id]
      and mon.habitat~="sea" and mon.habitat~="freshwater")
  end
  return mon.habitat==loc.habitat
end

-- These additions are unlocked only after the native League-clear flag.
-- FR/LG's birds and Mewtwo stay native; Mew gains League-gated wild homes.
-- Emerald and the remaining FR/LG specials keep their existing assignments.
local SPECIAL_HOMES = {
  frlg={
    water={"FR_FIVE_ISLAND_WATER_LABYRINTH","FR_SIX_ISLAND_WATER_PATH"},
    land={
      electric={"FR_CERULEAN_CAVE_1F","FR_CERULEAN_CAVE_2F"},
      ice={"FR_FOUR_ISLAND_ICEFALL_CAVE_B1F","FR_CERULEAN_CAVE_2F"},
      ghost={"FR_FIVE_ISLAND_LOST_CAVE_ROOM1","FR_FIVE_ISLAND_LOST_CAVE_ROOM10"},
      forest={"FR_SIX_ISLAND_PATTERN_BUSH","FR_THREE_ISLAND_BERRY_FOREST"},
      volcanic={"FR_MT_EMBER_RUBY_PATH_B3F","FR_MT_EMBER_SUMMIT_PATH_3F"},
      sea={"FR_SEAFOAM_ISLANDS_B4F","FR_FOUR_ISLAND_ICEFALL_CAVE_B1F"},
      freshwater={"FR_CERULEAN_CAVE_1F","FR_CERULEAN_CAVE_B1F"},
      cave={"FR_CERULEAN_CAVE_B1F","FR_MT_EMBER_RUBY_PATH_B3F"},
      meadow={"FR_CERULEAN_CAVE_2F","FR_SEVEN_ISLAND_SEVAULT_CANYON"},
      safari={"FR_CERULEAN_CAVE_2F","FR_SEVEN_ISLAND_SEVAULT_CANYON"},
    },
  },
  emerald={
    water={"EM_UNDERWATER_ROUTE124","EM_UNDERWATER_ROUTE126"},
    land={
      electric={"EM_NEW_MAUVILLE_INSIDE","EM_ARTISAN_CAVE_1F"},
      ice={"EM_SHOAL_CAVE_LOW_TIDE_ICE_ROOM","EM_ARTISAN_CAVE_B1F"},
      ghost={"EM_MT_PYRE_6F","EM_MT_PYRE_SUMMIT"},
      forest={"EM_ROUTE120","EM_SAFARI_ZONE_NORTHEAST"},
      volcanic={"EM_FIERY_PATH","EM_SEAFLOOR_CAVERN_ROOM8"},
      sea={"EM_SEAFLOOR_CAVERN_ROOM8","EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM"},
      freshwater={"EM_ROUTE120","EM_ARTISAN_CAVE_1F"},
      cave={"EM_METEOR_FALLS_STEVENS_CAVE","EM_SKY_PILLAR_5F"},
      meadow={"EM_ARTISAN_CAVE_1F","EM_SKY_PILLAR_5F"},
      safari={"EM_ARTISAN_CAVE_B1F","EM_SKY_PILLAR_3F"},
    },
  },
}
-- Species without a native FR/LG encounter can have explicit homes without
-- duplicating the birds/Mewtwo or changing existing habitat assignments.
local EXTRA_SPECIAL_HOMES = {
  frlg = {
    [151] = {land={"FR_CERULEAN_CAVE_1F", "FR_SEVEN_ISLAND_SEVAULT_CANYON"}},
  },
}
Policy.extraSpecialHomes=EXTRA_SPECIAL_HOMES
Policy.specialHomes=SPECIAL_HOMES
Policy.specialChance=100 -- one shared 1% roll when ordinary candidates exist
function Policy.specialLevelRange(mon)
  local lo=math.max(55,tonumber(mon.gate) or 1)
  return lo,math.max(lo,70)
end
local function specialAt(mon,mapId,terrain)
  if not mon.special or not Policy.allows(mon,terrain) then return false end
  local emerald=tostring(mapId):match("^EM_")~=nil
  local extra=EXTRA_SPECIAL_HOMES[emerald and "emerald" or "frlg"]
  local explicit=extra and extra[mon.id]
  if explicit then
    for _,name in ipairs(explicit[terrain] or {}) do
      if key(name)==key(mapId) then return true end
    end
    return false
  end
  if not emerald and (tonumber(mon.gen) or 1)<=1 then return false end
  local homes=SPECIAL_HOMES[emerald and "emerald" or "frlg"]
  local names=terrain=="water" and homes.water
    or terrain=="land" and homes.land[mon.habitat] or nil
  for _,name in ipairs(names or {}) do if key(name)==key(mapId) then return true end end
  return false
end

function Policy.new(roster, locations, random, progress)
  local self = {roster=roster, locations=locations, random=random or math.random, pools={}}
  self.byMap = {}
  for i,loc in ipairs(locations) do self.byMap[key(loc.map)] = i end

  function self:choice(index)
    index = tonumber(index)
    if not index or index < 1 or index > #Policy.choices or index ~= math.floor(index) then
      index = Policy.default
    end
    return Policy.choices[index], index
  end

  function self:location(mapId)
    local k = key(mapId)
    local exact = self.byMap[k]
    if exact then return exact, self.locations[exact] end
    -- Only declared dungeon families inherit a parent, longest match first.
    -- Never let Route 1 match Route 10/11 or an unknown map inherit Route 1.
    local best, length
    for i,loc in ipairs(self.locations) do
      local parent = key(loc.map)
      if loc.children and k:sub(1, #parent) == parent
          and (not length or #parent > length) then
        best, length = i, #parent
      end
    end
    if best then return best, self.locations[best] end
    return nil, nil
  end

  local function inChoice(mon, choice)
    return mon.id >= choice.first and mon.id <= choice.last
  end

  -- Ordinary homes remain unchanged. Specials have explicit separate homes
  -- and never enter early-area, fishing, Rock Smash or generic fallback pools.
  local function homeFor(mon)
    local wanted = tonumber(mon.location)
    return wanted and locations[wanted] and wanted or nil
  end

  local hoennHomes={}
  for _,mon in ipairs(roster) do
    if not mon.special then
      hoennHomes[mon.id]={}
      for _,terrain in ipairs({"land","water","fishing","rocks"}) do
        local eligible={}
        for i,base in ipairs(locations) do
          if base.hoenn then
            local loc=terrainProfile(base,terrain)
            if loc and Policy.allows(mon,terrain) and (mon.gate or 1)<=loc.hi
                and safeForEarlyArea(mon,loc) and hoennHabitat(mon,loc,terrain) then
              eligible[#eligible+1]=i
            end
          end
        end
        if #eligible>0 then
          local first=(mon.id*17+(mon.stage or 1)*7)%#eligible+1
          hoennHomes[mon.id][terrain]={[eligible[first]]=true,
            [eligible[(first-1+math.floor(#eligible/2))%#eligible+1]]=true}
        end
      end
    end
  end

  function self:pool(mapId, choiceIndex, terrain, context)
    terrain=terrain or "land"
    local locIndex,base = self:location(mapId)
    local loc=terrainProfile(base,terrain)
    local choice,normalized = self:choice(choiceIndex)
    local postgame=context and context.postgame
    if postgame==nil and progress then postgame=progress() end
    postgame=postgame==true
    if not loc then
      return {common={},rare={},featured={},special={},choice=choice},nil
    end
    local cacheKey = key(mapId) .. ":" .. locIndex .. ":" .. normalized .. ":" .. terrain .. ":" .. (postgame and 1 or 0)
    if self.pools[cacheKey] then return self.pools[cacheKey],loc end
    local common,rare,featured,seen = {},{},{},{}
    local function add(list,mon)
      if seen[mon.id] then return false end
      seen[mon.id]=true; list[#list+1]=mon; return true
    end
    for _,mon in ipairs(self.roster) do
      if Policy.allows(mon, terrain) and inChoice(mon, choice) and (tonumber(mon.gate) or 1) <= (tonumber(loc.hi) or 100) then
        local belongs = homeFor(mon) == locIndex
        if loc.hoenn then
          local homes=hoennHomes[mon.id] and hoennHomes[mon.id][terrain]
          belongs=(loc.native and loc.native[mon.id]) or (homes and homes[locIndex])
        elseif loc.sevii then
          -- Additional island homes leave the original Kanto distribution intact.
          -- Aquatic pools are separate even on forest/volcano/cave maps.
          if terrain == "water" or terrain == "fishing" then
            belongs = true -- Policy.allows above already selected aquatic species.
          else
            belongs = mon.habitat == loc.habitat
          end
        end
        if not mon.special and belongs
            and safeForEarlyArea(mon, loc) then
          add(isRare(mon) and rare or common, mon)
        end
      end
    end

    if loc.hoenn and #common==0 and #rare==0 then
      -- A restricted generation still gets a legal ordinary pool on every
      -- native encounter terrain. Prefer that terrain's habitat first.
      for pass=1,2 do
        for _,mon in ipairs(self.roster) do
          if not mon.special and Policy.allows(mon,terrain) and inChoice(mon,choice)
              and (mon.gate or 1)<=loc.hi and safeForEarlyArea(mon,loc)
              and (pass==2 or hoennHabitat(mon,loc,terrain)) then
            add(isRare(mon) and rare or common,mon)
          end
        end
        if #common+#rare>0 then break end
      end
    end
    if loc.hoenn and terrain=="land" and loc.featured then
      for _,id in ipairs(loc.featured) do
        local mon=self.roster[id]
        if mon and inChoice(mon,choice) then featured[#featured+1]=mon end
      end
    end
    if terrain=="land" and key(loc.map) == "ROUTE1" then
      for _, id in ipairs(ROUTE_1_FEATURED) do
        local mon = self.roster[id]
        if mon then featured[#featured+1] = mon end
      end
    end

    local special={}
    if postgame then
      for _,mon in ipairs(self.roster) do
        if inChoice(mon,choice) and specialAt(mon,mapId,terrain) then special[#special+1]=mon end
      end
    end
    local result={common=common,rare=rare,featured=featured,special=special,location=loc,choice=choice}
    self.pools[cacheKey]=result
    return result,loc
  end

  function self:eligiblePool(mapId, choiceIndex, nativeLevel, terrain, context)
    local pool,loc = self:pool(mapId, choiceIndex, terrain, context)
    if not loc then return pool, nil end
    if loc.hoenn and (terrain=="fishing" or terrain=="rocks") then
      local ceiling=math.max(loc.lo,tonumber(nativeLevel) or loc.lo)
      local filtered={common={},rare={},featured={},special={},choice=pool.choice}
      for _,kind in ipairs({"common","rare","featured"}) do
        for _,mon in ipairs(pool[kind]) do
          if (mon.gate or 1)<=ceiling then filtered[kind][#filtered[kind]+1]=mon end
        end
      end
      if #filtered.common+#filtered.rare+#filtered.featured==0 then
        for _,mon in ipairs(self.roster) do
          if not mon.special and Policy.allows(mon,terrain) and inChoice(mon,pool.choice)
              and (mon.gate or 1)<=ceiling and safeForEarlyArea(mon,loc) then
            filtered.common[#filtered.common+1]=mon
          end
        end
      end
      pool=filtered
    end
    return pool,loc
  end

  function self:choose(mapId, choiceIndex, nativeLevel, terrain, context)
    local pool,loc = self:eligiblePool(mapId, choiceIndex, nativeLevel, terrain, context)
    if not loc then return nil end
    local list
    if #pool.special>0 and (#pool.common+#pool.rare+#pool.featured==0 or self.random(Policy.specialChance)==1) then
      list=pool.special
    elseif #pool.featured > 0 and self.random(ROUTE_1_FEATURED_CHANCE) == 1 then
      list=pool.featured
    elseif #pool.rare > 0 and (#pool.common == 0 or self.random(20) == 1) then
      list=pool.rare
    else
      list=pool.common
    end
    if #list == 0 then return nil end
    local mon=list[self.random(#list)]
    if mon.special then
      local lo,hi=Policy.specialLevelRange(mon)
      return mon,self.random(lo,hi)
    end
    local level=math.max(tonumber(nativeLevel) or loc.lo,loc.lo,mon.gate)
    return mon,math.min(level,loc.hi)
  end
  return self
end

return Policy
