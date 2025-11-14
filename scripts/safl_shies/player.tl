local ui = require("openmw.ui")
local UI = require("openmw.interfaces").UI
local input = require("openmw.input")
local nearby = require("openmw.nearby")
local types = require("openmw.types")
local core = require("openmw.core")
local self = require("openmw.self")
local util = require("openmw.util")

local selfObj = self as core.GameObject

local interface PlayerQuest is types.PlayerQuest, types.PLAYERQuest end

local function getQuest(questName: string): PlayerQuest
	return (types.Player.quests(selfObj) as {string: PlayerQuest})[questName]
end

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
      	end,
	  	["shiesFled"] = function()
			local quest = getQuest("SAFL_ShiesFled")
			if not quest.started then
				quest:addJournalEntry(10, selfObj)
			end
	  	end,
		["getPos"] = function(): util.Vector3 | nil
			if self then
				return self.object.position
			else
				return nil
			end
		end
   	},
}