-- Move the battle coordinates, not pixels inside the 64x64 sprite canvas.
-- Add the lift after species/form and animation offsets, in battle only.
return function()
  local Ui = require('src.core.game3.battle.ui')
  if Ui.__completeDexLift then return end
  Ui.__completeDexLift = true
  local original = assert(Ui.bounceOffset, 'Missing FireRed battle offset API')
  Ui.bounceOffset = function(kind,id)
    local offset = original(kind,id) or 0
    if kind == 'mon' then return offset - 14 end
    return offset
  end
end
