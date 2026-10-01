local Policy = {}

-- Aquatic bodies cannot appear on land. Water typing alone is insufficient:
-- Psyduck, Wooper, Mudkip, etc. remain valid shoreline/grass encounters.
local WATER_ONLY = {}
for _,id in ipairs({72,73,90,91,116,117,118,119,120,121,129,130,131,
  170,171,211,222,223,224,226,230,318,319,320,321,339,340,349,350,366,367,368,369,370,
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

function Policy.new(roster, locations, random)
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

  -- Random encounters belong to ordinary species only. The source roster
  -- carries legendary/mythical entries, but those cannot create one-off
  -- overworld encounters and must never duplicate the ROM's static battles.
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

  function self:pool(mapId, choiceIndex, terrain)
    terrain=terrain or "land"
    local locIndex,base = self:location(mapId)
    local loc=terrainProfile(base,terrain)
    local choice,normalized = self:choice(choiceIndex)
    if not loc then
      return {common={},rare={},featured={},choice=choice},nil
    end
    local cacheKey = locIndex .. ":" .. normalized .. ":" .. terrain
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

    local result={common=common,rare=rare,featured=featured,location=loc,choice=choice}
    self.pools[cacheKey]=result
    return result,loc
  end

  function self:choose(mapId, choiceIndex, nativeLevel, terrain)
    local pool,loc = self:pool(mapId, choiceIndex, terrain)
    if not loc then return nil end
    if loc.hoenn and (terrain=="fishing" or terrain=="rocks") then
      local ceiling=math.max(loc.lo,tonumber(nativeLevel) or loc.lo)
      local filtered={common={},rare={},featured={},choice=pool.choice}
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
    local list
    if #pool.featured > 0 and self.random(ROUTE_1_FEATURED_CHANCE) == 1 then
      list=pool.featured
    elseif #pool.rare > 0 and (#pool.common == 0 or self.random(20) == 1) then
      list=pool.rare
    else
      list=pool.common
    end
    if #list == 0 then return nil end
    local mon=list[self.random(#list)]
    local level=math.max(tonumber(nativeLevel) or loc.lo,loc.lo,mon.gate)
    return mon,math.min(level,loc.hi)
  end
  return self
end

return Policy
