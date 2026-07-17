local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local core = require("openmw.core")
local world = require("openmw.world")
local storage = require("openmw.storage")

local function syncMWVars(actor)
   if actor ~= nil then
      local localScript = world.mwscript.getLocalScript(actor, nil)
      if localScript ~= nil then
         local varTable = storage.globalSection(actor.id)
         varTable:setLifeTime(storage.LIFE_TIME.GameSession)
         varTable:set("skree", "skree")
         for k, v in pairs((localScript.variables)) do
            varTable:set(k, v)
         end
      end
   end
end

return {
   engineHandlers = {
      onActorActive = function(actor)
         syncMWVars(actor)
      end,
      onUpdate = function()
         for i = 1, #world.activeActors do
            syncMWVars(world.activeActors[i])
         end
      end,
   },
}
