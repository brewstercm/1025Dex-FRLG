local Policy = {}

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
    :gsub("[^A-Z0-9]", "")
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
    for mapKey,i in pairs(self.byMap) do
      if k:find(mapKey, 1, true) or mapKey:find(k, 1, true) then
        return i, self.locations[i]
      end
    end
    local habitat = "meadow"
    if k:find("SEAFOAM",1,true) then habitat="ice"
    elseif k:find("CAVE",1,true) or k:find("TUNNEL",1,true) or k:find("VICTORYROAD",1,true) then habitat="cave"
    elseif k:find("TOWER",1,true) then habitat="ghost"
    elseif k:find("POWERPLANT",1,true) then habitat="electric"
    elseif k:find("MANSION",1,true) then habitat="volcanic"
    elseif k:find("SAFARI",1,true) then habitat="safari" end
    for i,loc in ipairs(self.locations) do
      if not loc.special and loc.habitat == habitat then return i,loc end
    end
    return 1,self.locations[1]
  end

  local function inChoice(mon, choice)
    return mon.id >= choice.first and mon.id <= choice.last
  end

  -- Each roster record owns exactly one map. The WILD GENS choice filters
  -- species; it never reshuffles their homes or pads an area's pool with
  -- Pokemon from somewhere else. Rare non-vanilla species are authored into
  -- Safari Zone maps, while legendaries and mythicals are authored into the
  -- endgame special maps.
  local function homeFor(mon)
    local wanted = tonumber(mon.location)
    local at = wanted and locations[wanted]
    if not at then return nil end
    return wanted
  end

  function self:pool(mapId, choiceIndex)
    local locIndex,loc = self:location(mapId)
    local choice,normalized = self:choice(choiceIndex)
    local cacheKey = locIndex .. ":" .. normalized
    if self.pools[cacheKey] then return self.pools[cacheKey],loc end
    local common,rare,featured,seen = {},{},{},{}
    local function add(list,mon)
      if seen[mon.id] then return false end
      seen[mon.id]=true; list[#list+1]=mon; return true
    end
    for _,mon in ipairs(self.roster) do
      if inChoice(mon, choice) and (tonumber(mon.gate) or 1) <= (tonumber(loc.hi) or 100) then
        if mon.special then
          -- Legendary and mythical Pokemon only exist at their assigned
          -- Victory Road, Seafoam, or Cerulean Cave endgame location.
          if loc.special and homeFor(mon) == locIndex then add(rare,mon) end
        elseif homeFor(mon) == locIndex and safeForEarlyArea(mon, loc) then
          add(isRare(mon) and rare or common, mon)
        end
      end
    end

    if key(loc.map) == "FRROUTE1" then
      for _, id in ipairs(ROUTE_1_FEATURED) do
        local mon = self.roster[id]
        if mon then featured[#featured+1] = mon end
      end
    end

    local result={common=common,rare=rare,featured=featured,location=loc,choice=choice}
    self.pools[cacheKey]=result
    return result,loc
  end

  function self:choose(mapId, choiceIndex, nativeLevel)
    local pool,loc = self:pool(mapId, choiceIndex)
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
