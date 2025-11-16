local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local core = require('openmw.core')
local util = require('openmw.util')
local world = require('openmw.world')

local shies = "safl_shies"







local shiesObj

local function teleport(data)
   data.actor:teleport(data.cell, data.position, { onGround = true, rotation = util.transform.identity })
end

local function disable(actor)
   actor.enabled = false
end

local function updateMWVar(data)
   local localScript = world.mwscript.getLocalScript(data[3], nil)
   if localScript ~= nil then
      (localScript).variables[data[1]] = data[2]
   end
end

local function syncMWVars(actor)
   if actor ~= nil then
      local localScript = world.mwscript.getLocalScript(actor, nil)
      if localScript ~= nil then
         local varTable = {}
         for k, v in pairs((localScript.variables)) do
            varTable[k] = v
         end
         actor:sendEvent("fetchMWVars", varTable)
      end
   end
end

return {
   engineHandlers = {
      onActorActive = function(actor)
         if actor.recordId == shies then
            shiesObj = actor
            syncMWVars(shiesObj)
            actor:addScript('scripts/safl_shies/shies.lua', nil)
         end
      end,
      onActivate = function(object)
         if object.recordId == shies then
            object:sendEvent("shiesActivated", nil)
         end
      end,
      onUpdate = function()
         if shiesObj ~= nil and shiesObj.recordId == shies then
            syncMWVars(shiesObj)
         end
      end,
   },
   eventHandlers = {
      ["teleport"] = teleport,
      ["disable"] = disable,
      ["updateMWVar"] = updateMWVar,
   },
}
