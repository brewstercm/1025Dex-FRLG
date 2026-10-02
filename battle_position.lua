-- Keep small sprites at their existing height. Limit the blanket lift for
-- taller art using stable bounds supplied by the sprite provider's bake.
-- This changes battle coordinates only: all 64x64 pixels remain intact.
return function()
  local Ui = require('src.core.game3.battle.ui')
  if Ui.__completeDexLift then return end
  Ui.__completeDexLift = true
  local original = assert(Ui.bounceOffset, 'Missing FireRed battle offset API')
  local Pokemon = require('src.core.game3.pokemon')
  local function liftFor(id)
    local Battle = package.loaded['src.core.game3.battle']
    local st = Ui._st or (Battle and Battle._st)
    if not st then return 14 end
    local numeric = tonumber(id)
    local back = id == 'player' or (numeric and numeric % 2 == 0)
    local side = back and 'player' or 'enemy'
    local b = numeric and ((numeric == 0 and st.player) or
      (numeric == 1 and st.enemy) or (st.battlers and st.battlers[numeric])) or st[side]
    local Anim = package.loaded['src.core.game3.battle.anim']
    local key = st.double and (numeric or id) or side
    if Anim and Anim.shownBattler then b = Anim.shownBattler(key, b) or b end
    if not b then return 14 end
    local pres = Anim and Anim.present and Anim.present(key)
    -- These are native substitute/ghost pictures, not the replaced mon art.
    if (pres and pres.substitute) or (Ui.showsGhost and Ui.showsGhost(side, st)) then return 14 end
    local mon = b.mon
    local species = b.species or (mon and Pokemon.speciesOf and Pokemon.speciesOf(mon))
      or (mon and (mon.species or mon.speciesId))
    if b.expTransform then
      local transformed = pres and pres.transformSpecies
      if not transformed and not (pres and pres.pendingTransform) then transformed = b.expTransform.species end
      species = transformed or species
    end
    if not species then return 14 end
    local form = Ui.castformForm and Ui.castformForm(side, b) or 0
    local picSpecies, shiny, personality = species, false, mon and mon.personality
    if Ui.picArgs then picSpecies, shiny, personality = Ui.picArgs(b, species) end
    local provider = back and Pokemon.backPic or Pokemon.frontPic
    local pic = provider and provider(picSpecies, form, shiny, personality)
    local lift = pic and tonumber(pic.__completeDexBattleLift)
    return lift and math.min(14, math.max(0, lift)) or 14
  end
  Ui.bounceOffset = function(kind,id)
    local offset = original(kind,id) or 0
    if kind ~= 'mon' then return offset end
    local ok, lift = pcall(liftFor, id)
    return offset - (ok and lift or 14)
  end
end
