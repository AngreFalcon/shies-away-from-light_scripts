local core = require('openmw.core')
local util = require('openmw.util')
local world = require('openmw.world')

local shies = "safl_shies"







local function teleport(data)
   data.actor:teleport(data.cell, data.position, { onGround = true, rotation = util.transform.identity })
end

local function disable(actor)
   actor.enabled = false
end

local function fetchMWVar(data)
   local localScript = world.mwscript.getLocalScript(data[2], nil)
   if localScript ~= nil then
      return (localScript).variables[data[1]]
   else
      return nil
   end
end

local function updateMWVar(data)
   local localScript = world.mwscript.getLocalScript(data[3], nil)
   if localScript ~= nil then
      (localScript).variables[data[1]] = data[2]
   end
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
      ["fetchMWVar"] = fetchMWVar,
      ["updateMWVar"] = updateMWVar,
   },
}
