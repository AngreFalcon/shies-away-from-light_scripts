local UI = require('openmw.interfaces').UI
local input = require('openmw.input')
local nearby = require('openmw.nearby')
local types = require('openmw.types')
local core = require('openmw.core')
local self = require('openmw.self')
local util = require('openmw.util')
local cmn = require('scripts.follower.common')

local selfObj = self as core.GameObject

local function getQuest(questName: string): cmn.PlayerQuest
	return (types.Player.quests(selfObj) as {string: cmn.PlayerQuest})[questName]
end

return {
	engineHandlers = {
		onKeyPress = function(key: input.KeyboardEvent)
        	-- Ignore anything that's not an 'x' keypress
        	if key.symbol ~= 'x' then return end
        	-- Scan nearby actors - if Shies is found in the list, send an event over to him
        	for _, obj in ipairs(nearby.actors) do
            	if obj.recordId == "safl_shies" then
					obj:sendEvent("shiesJump", nil)
               		--obj:sendEvent("hurtShies", nil)
               		--ui.showMessage('Your callous behaviour has injured the poor lizard... he run away.....', nil)
               		return
            	end
         	end
      	end,
   	},
   	eventHandlers = {
		["shiesAttacked"] = function(message: string)
         	UI.showInteractiveMessage(message, nil)
      	end,
	  	["shiesFled"] = function() -- Trigger the start of the Shies Fled quest
			local quest = getQuest("SAFL_ShiesFled")
			if not quest.started then
				quest:addJournalEntry(10, selfObj)
			end
	  	end,
		["getPos"] = function(): util.Vector3 | nil -- Get the player's location as a Vector3 (x, y, z coordinates)
			if self then
				return self.object.position
			else
				return nil
			end
		end,
		["getSneakVal"] = function(actor: core.GameObject) -- Get the player's current sneak state (true or false)
			actor:sendEvent("playerSneak", (selfObj as self).controls.sneak)
		end
   	},
}