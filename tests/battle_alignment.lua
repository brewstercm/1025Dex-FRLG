-- Production battle wrapper and production bake-placement block; no LÖVE needed.
-- Run from the mod folder: texlua tests/battle_alignment.lua
local checks=0
local function eq(a,b,why)checks=checks+1;assert(a==b,why..': '..tostring(a)..' ~= '..tostring(b))end
local small,tall,medium={__completeDexBattleLift=14},{__completeDexBattleLift=0},{__completeDexBattleLift=8}
local front={[1]=small,[2]=tall,[3]=medium};local back={[1]=small,[2]=medium,[3]=tall}
local Ui={bounceOffset=function()return 3 end,_st={player={species=1},enemy={species=2},battlers={[2]={species=3},[3]={species=1}}}}
local P={frontPic=function(s)return front[s]end,backPic=function(s)return back[s]end}
package.loaded['src.core.game3.battle.ui']=Ui;package.loaded['src.core.game3.pokemon']=P
local install=dofile('battle_position.lua');install()
eq(Ui.bounceOffset('mon',0),-11,'small back retains lift')
eq(Ui.bounceOffset('mon',1),3,'tall front removes lift')
Ui._st.enemy.species=3;eq(Ui.bounceOffset('mon',1),-5,'medium front partial lift')
eq(Ui.bounceOffset('hb',1),3,'HUD bounce unchanged')
Ui._st.double=true;eq(Ui.bounceOffset('mon',2),3,'second ally own back bounds')
eq(Ui.bounceOffset('mon',3),-11,'second enemy own front bounds')
Ui._st.double=false
local observed
package.loaded['src.core.game3.battle.anim']={shownBattler=function(key,b)observed=key;return {species=2}end}
eq(Ui.bounceOffset('mon',1),3,'displayed battle species');eq(observed,'enemy','singles presentation key')
package.loaded['src.core.game3.battle.anim']=nil
Ui._st.enemy={species=1,expTransform={species=2}};eq(Ui.bounceOffset('mon',1),3,'transform uses displayed sprite')
Ui._st.enemy={mon={speciesId=3}};eq(Ui.bounceOffset('mon',1),-5,'mon fallback species')
Ui._st.enemy.species=999;eq(Ui.bounceOffset('mon',1),-11,'native/pending keeps prior behavior')
Ui.showsGhost=function()return true end;Ui._st.enemy.species=2
eq(Ui.bounceOffset('mon',1),-11,'native ghost preserved');Ui.showsGhost=nil
package.loaded['src.core.game3.battle.anim']={present=function()return {substitute=true}end}
eq(Ui.bounceOffset('mon',1),-11,'native substitute preserved')
package.loaded['src.core.game3.battle.anim']=nil
local before=Ui.bounceOffset;install();eq(Ui.bounceOffset,before,'installation idempotent')
local file=assert(io.open('sprites/main.lua'));local source=file:read('*a');file:close()
local a=assert(source:find('    local baseX = (box.w - dw) / 2',1,true))
local z=assert(source:find('    b.cloudH = cloudH',a,true))
local block=source:sub(a,z-1)
local bake=assert(load([[return function(height, lift)
 local box={w=64,h=64};local dw,dh=32,height
 local b={stem='TEST',x0=0,x1=31,y1=height-1,H=height,fw=32,back=false}
 local scale=1;local GEN=3;local GEN3_SPRITE_LIFT=0
 local ANCHOR_PACK,ANCHOR_FEET=2,1;local METRICS
 local function spriteAnchor()return ANCHOR_FEET end
 local function floatLift()return lift or 0 end
]]..block..[[
 return b
end]]))()
for height=1,64 do
 local b=bake(height,0)
 eq(b.gen3BattleLift,math.min(14,64-height),'visible headroom '..height)
 eq(b.oy-b.gen3BattleLift>=0,true,'no lift above canvas '..height)
end
local b=bake(40,10);eq(b.gen3BattleLift,14,'small floater retains lift')
b=bake(56,6);eq(b.gen3BattleLift,2,'tall floater retains baked hover, limits extra lift')
print(('PASS: %d assertions; small/tall/medium art, both sides, doubles, transform, ghost/substitute, bounce preservation, and all 64 art heights.'):format(checks))
