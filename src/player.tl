local ui = require("openmw.ui")
local UI = require("openmw.interfaces").UI
local input = require("openmw.input")
local nearby = require("openmw.nearby")

return {
   engineHandlers = {
      onKeyPress = function(key: input.KeyboardEvent)
         -- Ignore anything that's not an 'x' keypress
         if key.symbol ~= 'x' then return end
         -- Scan nearby actors - if Shies is found in the list, send an event over to him
         for _, obj in ipairs(nearby.actors) do
            if obj.recordId == "safl_shies" then
               obj:sendEvent("hurtShies", nil)
               ui.showMessage('Your callous behaviour has injured the poor lizard... he run away.....', nil)
               return
            end
         end
      end,
   },
   eventHandlers = {
      ["shiesAttacked"] = function(message: string)
         UI.showInteractiveMessage(message, nil)
      end
   },
}