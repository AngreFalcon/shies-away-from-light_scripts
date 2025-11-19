local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local ui = require('openmw.ui')
local UI = require('openmw.interfaces').UI
local input = require('openmw.input')
local nearby = require('openmw.nearby')
local types = require('openmw.types')
local core = require('openmw.core')
local self = require('openmw.self')
local util = require('openmw.util')
local cmn = require('scripts.safl_shies.common')

local selfObj = self

local function getQuest(questName)
   return (types.Player.quests(selfObj))[questName]
end

return {
   engineHandlers = {
      onKeyPress = function(key)

         if key.symbol ~= 'x' then return end

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
      ["shiesAttacked"] = function(message)
         UI.showInteractiveMessage(message, nil)
      end,
      ["shiesFled"] = function()
         local quest = getQuest("SAFL_ShiesFled")
         if not quest.started then
            quest:addJournalEntry(10, selfObj)
         end
      end,
      ["getPos"] = function()
         if self then
            return self.object.position
         else
            return nil
         end
      end,
      ["getSneakVal"] = function(actor)
         actor:sendEvent("playerSneak", (selfObj).controls.sneak)
      end,
   },
}
