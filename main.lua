-- One mod identity, one options schema, three ordered internal components.
return function(mod)
  local Version = require('src.core.GameVersion')
  if Version.get() ~= 'firered' then
    mod.log:warn('1025Dex only supports FireRed; nothing installed.')
    return
  end
  local schema, seen = {}, {}
  local function component(folder)
    local child = setmetatable({path=mod.path .. '/' .. folder}, {__index=mod})
    function child:read(relative) return mod:read(folder .. '/' .. relative) end
    function child:list(relative) return mod:list(folder .. '/' .. (relative or '')) end
    function child:info(relative) return mod:info(folder .. '/' .. relative) end
    child.assets = setmetatable({}, {__index=mod.assets})
    for _,method in ipairs({'path','image','list','info'}) do
      local name=method
      child.assets[name]=function(_,relative)
        return mod.assets[name](mod.assets,folder .. '/' .. (relative or ''))
      end
    end
    child.options = {
      define=function(_,rows)
        for _,row in ipairs(rows) do
          if not seen[row.key] then
            seen[row.key]=true; schema[#schema+1]=row
          end
        end
        return mod.options:define(schema)
      end,
      get=function(_,key) return mod.options:get(key) end,
    }
    local source=assert(child:read('main.lua'),'Missing component: '..folder)
    local entry=assert(load(source,'@'..child.path..'/main.lua'))()
    assert(type(entry)=='function','Invalid component: '..folder)
    entry(child)
  end
  component('dex')
  component('cries')
  component('sprites')
  component('encounters')
  assert(load(assert(mod:read('battle_position.lua')), '@battle_position.lua'))()()
  mod.log:info('1025Dex ready: 1025 cries, 64x64 animated sprites and WILD GENS.')
end
