local core = require("openmw.core")
local util = require("openmw.util")

local shies = "safl_shies"

local interface TeleportData
   actor: core.GameObject
   cell: string
   position: util.Vector3
end

local function teleport(data: TeleportData)
   data.actor:teleport(data.cell, data.position, {onGround=true, rotation = util.transform.identity})
end

local function disable(actor: core.GameObject)
   actor.enabled = false
end

return {
   engineHandlers = {
      onActorActive = function(actor: core.GameObject)
         if actor.recordId == shies then
            actor:addScript('scripts/safl_shies/shies.lua', nil)
         end
      end
   },
   eventHandlers = {
      ["teleport"] = teleport,
      ["disable"] = disable,
   }
}

--[[
   ;if ( GetHealthGetRatio < 0.10 ) 
      ;Set companion to 0
      ;Set c_move to 0
      ;AiWander, 0, 0, 0, 0
      ;if ( GetCurrentAIPackage == 3 )
      ;  return
      ;endif
      ;Set tempValue1 to GetHealth
      ;Set tempValue2 to ( tempValue1 / GetHealthGetRatio )
      ;Set tempValue1 to ( tempValue2 - tempValue1 )
      ;ModCurrentHealth, tempValue1
      ;PositionCell, -5, -218, -251, 0, "Balmora, Council Club"
      ;Journal, "SAFL_ShiesFled", 5
      ;return
   ;endif
--]]