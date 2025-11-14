local core = require("openmw.core")
local util = require("openmw.util")

local shies = "safl_shies"







local function teleport(data)
   data.actor:teleport(data.cell, data.position, { onGround = true, rotation = util.transform.identity })
end

local function disable(actor)
   actor.enabled = false
end

return {
   engineHandlers = {
      onActorActive = function(actor)
         if actor.recordId == shies then
            actor:addScript('scripts/safl_shies/shies.lua', nil)
         end
      end,
   },
   eventHandlers = {
      ["teleport"] = teleport,
      ["disable"] = disable,
   },
}
