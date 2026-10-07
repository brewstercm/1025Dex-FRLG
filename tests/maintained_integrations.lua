-- Maintained behavior at the upstream 1.2.15 integration boundaries.
local checks=0
local function eq(a,b,msg) checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b)) end
local function read(p) local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local Shape=dofile('dex/src/gen3shape.lua')
local rates=dofile('dex/data/species/generated/gender_rates.lua')
Shape.genderRates=rates
for _,rate in ipairs({-1,0,1,2,4,6,7,8}) do
  eq(Shape.genderRatio(rate),rate==-1 and 255 or rate==8 and 254 or math.floor(rate*255/8),'gender threshold')
end
for id,rate in pairs(rates) do
  eq(Shape.record({id=id,name=id,dex=500}).genderRatio,Shape.genderRatio(rate),'registered gender '..id)
end
local Evo=dofile('dex/src/gen3evolutions.lua')
local national=dofile('dex/data/species/generated/national.lua')
local byId={};for id,row in pairs(national.register) do byId[id]=row.dex end
for _,mon in ipairs(dofile('encounters/roster.lua')) do byId[mon.name]=mon.id end
local items={SUN_STONE=93,MOON_STONE=94,THUNDER_STONE=96,KINGS_ROCK=187,METAL_COAT=199,DRAGON_SCALE=201,UP_GRADE=208,DEEP_SEA_TOOTH=192,DEEP_SEA_SCALE=193}
local function item(name)return items[name] end
local function rows(compat) return Evo.build(function(p)return read('dex/'..p)end,function(n)return n end,item,function()return false end,compat) end
local adapted,guards,counts=rows(true);local upstream=rows(false)
local overrides=dofile('dex/data/evolutions/compat_overrides.lua')
local function edge(graph,from,target)
  for _,e in ipairs(graph[from] or {}) do if e.target==target then return e end end
end
for id,targets in pairs(overrides) do for target,rule in pairs(targets) do
  local e=assert(edge(adapted,byId[id],byId[target]),id..' -> '..target)
  eq(e.method,rule.method=='EVO_LEVEL' and 4 or 7,'maintained evolution method')
  eq(e.param,rule.level or items[rule.item],'maintained evolution trigger')
end end
eq(edge(upstream,190,424).param,36,'Emerald upstream Ambipom fallback')
eq(edge(adapted,79,199).method,4,'held Slowking precedence')
eq(guards[281][475],nil,'maintained Gallade Sun Stone rule replaces modern guard')
eq(guards[361][478],nil,'maintained Froslass Sun Stone rule replaces modern guard')
eq(counts.compat>0,true,'maintained evolution overrides installed')
local Policy=dofile('encounters/policy.lua')
local locations=dofile('encounters/locations.lua')
for _,loc in ipairs(dofile('encounters/hoenn_locations.lua'))do locations[#locations+1]=loc end
local randomCalls=0
local policy=Policy.new(dofile('encounters/roster.lua'),locations,function(a,b)randomCalls=randomCalls+1;return b and a or 1 end)
local pool,loc=policy:eligiblePool('FR_DIGLETTS_CAVE_B1F',17,15,'land')
assert(loc and pool.residentSlots,'protected cave remains a pool')
eq(randomCalls,0,'Area lookup does not roll protected residents')
local mon,level=policy:choose('FR_DIGLETTS_CAVE_B1F',17,15,'land')
eq(mon.id,50,'protected Diglett weighted choice');eq(level,18,'protected native slot level')
eq(randomCalls,1,'choose rolls protected residents once')
package.loaded['src.core.game3.pokemon']={national=function(n)return n end}
package.loaded['src.import.gba.map_catalog']={mapIdFor=function()return 'EM_SKY_PILLAR_5F' end}
local Areas=dofile('encounters/emerald_pokedex_areas.lua')
local headers={['1:2']={mapGroup=1,mapNum=2,land={slots={{species=25,minLevel=55,maxLevel=55}}}}}
local result=Areas.build(headers,793,0,policy,17,true)
eq(result['1:2'].land.slots[1].species,793,'Emerald Area includes unlocked Ultra Beast')
eq(#Areas.build(headers,793,0,policy,17,false)['1:2'].land.slots,0,'Area follows League gate')
package.loaded['src.import.gba.map_catalog'].mapIdFor=function()return 'RU_SKY_PILLAR_5F' end
local rs=Areas.build(headers,793,0,policy,17,true,function(map)return map:gsub('^RU_','EM_')end)
eq(rs['1:2'].land.slots[1].species,793,'RSE Area uses the active cartridge policy mapping')
-- The shared API must delegate native slot conversion, including Chimecho.
for _,gen in ipairs({1,2,3})do
  local slots={[252]=277,[358]=411,[399]=463}
  local keys={[252]='TREECKO',[358]='CHIMECHO',[399]='BIDOOF'}
  local rows={TREECKO={dex=252},CHIMECHO={dex=358},BIDOOF={dex=399}}
  package.loaded['src.core.GameVersion']={generation=function()return gen end}
  package.loaded['src.core.game3.pokemon']={
    national=function(slot)for n,s in pairs(slots)do if s==slot then return n end end end,
    speciesFromNational=function(n)return slots[n]end,
    keyName=function(slot)for n,s in pairs(slots)do if s==slot then return keys[n]end end end,
    speciesFromName=function(key)for n,k in pairs(keys)do if k==key then return slots[n]end end end}
  local mod={exports={},game={data={pokemon=rows}},read=function(_,p)return read(p)end}
  dofile('compat/species_numbers.lua')(mod)
  local api=mod.exports.speciesNumbers
  for n,key in pairs(keys)do
    eq(api.nationalOfSpecies(gen==3 and slots[n] or key),n,'native to National')
    eq(api.speciesFromNational(n),gen==3 and slots[n] or key,'National to native')
    eq(api.keyFromNational(n),key,'National to key')
  end
  eq(api.speciesFromNational(0),nil,'invalid zero National')
  eq(api.speciesFromNational(1026),nil,'invalid extended National')
  eq(api.speciesFromNational(358.5),nil,'invalid fractional National')
end
-- Execute the maintained menu and gift flow under all three supported versions.
for _,version in ipairs({'firered','leafgreen','emerald'})do
  local choices,hook,gifts,flags={},nil,0,{}
  package.loaded['src.core.GameVersion']={get=function()return version end}
  package.loaded['src.ui.game3.choice']={multi=function(_,_,cb)cb(table.remove(choices,1) or 127)end}
  package.loaded['src.ui.game3.message']={show=function(_,opts)if opts.done then opts.done()end end}
  package.loaded['src.ui.game3.start_menu']={close=function()end}
  package.loaded['src.core.game3.bag']={new=function()return {}end,has=function()return false end,canAdd=function()return true end,add=function()return true end}
  package.loaded['src.core.game3.pokemon']={speciesFromNational=function(n)return n+64 end}
  package.loaded['src.core.game3.mystery_gift']={DELIVER_GIVEN=1,DELIVER_PARTY_FULL=2,deliverGift=function(_,packet)gifts=gifts+1;eq(packet.gift.species,315,'event National mapping');return 1 end,setFlag=function(_,flag)flags[flag]=true end}
  dofile('events/main.lua')({hooks={wrap=function(_,_,fn)hook=fn end},log={info=function()end}})
  local menu=hook(function()return {{id='save'},{id='mods',label='MODS'}}end,{},{})
  eq(menu[2].id,'1025dex_events','Events precedes Mods')
  local session={};choices={0,1};menu[2].onSelect(nil,session)
  eq(gifts,1,'Celebi event delivered');choices={0,1};menu[2].onSelect(nil,session);eq(gifts,1,'event is one-time')
  choices={1,0};menu[2].onSelect(nil,session)
  eq(flags[version=='emerald' and 0x8B3 or 0x84A],true,'native ticket flag')
end
print('PASS: '..checks..' maintained gender, evolution, Area, event and ticket checks')
