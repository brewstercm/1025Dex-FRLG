-- The engine uses these shared limits for capture spillover, PC navigation,
-- serialization and restore. Install before a save can be deserialized.
return function(mod)
  local Storage = require('src.core.game3.storage')
  local slots = assert(tonumber(Storage.IN_BOX_COUNT), 'Missing PC slot count')
  local required = math.max(36, math.ceil(1025 / slots))
  Storage.TOTAL_BOXES_COUNT = math.max(Storage.TOTAL_BOXES_COUNT or 0, required)
  Storage.TOTAL_BOX_MONS = Storage.TOTAL_BOXES_COUNT * slots

  -- Also upgrade an already-open session (e.g. when mods load in-game).
  -- Native ensure preserves existing boxes, names, wallpapers and PC items.
  local Runtime = require('src.core.game3.runtime')
  local session = Runtime and Runtime.getSession and Runtime.getSession()
  if session then Storage.ensure(session) end
  mod.log:info(('PC storage expanded to %d boxes / %d Pokemon')
    :format(Storage.TOTAL_BOXES_COUNT, Storage.TOTAL_BOX_MONS))
end
