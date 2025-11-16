local core = require('openmw.core')
local util = require('openmw.util')
local world = require('openmw.world')

local shies = "safl_shies"

local interface TeleportData
   	actor: core.GameObject
   	cell: string
   	position: util.Vector3
end

local shiesObj: core.GameObject

local function teleport(data: TeleportData)
   	data.actor:teleport(data.cell, data.position, {onGround=true, rotation = util.transform.identity})
end

local function disable(actor: core.GameObject)
   	actor.enabled = false
end

local function updateMWVar(data: {string, number, core.GameObject})
	local localScript = world.mwscript.getLocalScript(data[3], nil)
	if localScript ~= nil then
		(localScript as world.MWScript).variables[data[1]] = data[2]
	end
end

local function syncMWVars(actor: core.GameObject)
	if actor ~= nil then
		local localScript: world.MWScript = world.mwscript.getLocalScript(actor, nil)
		if localScript ~= nil then
			local varTable: {string: number} = {}
			for k, v in pairs((localScript.variables as {string: number})) do
				varTable[k] = v
			end
			actor:sendEvent("fetchMWVars", varTable)
		end
	end
end

return {
   	engineHandlers = {
      	onActorActive = function(actor: core.GameObject)
         	if actor.recordId == shies then
				shiesObj = actor
				syncMWVars(shiesObj)
            	actor:addScript('scripts/safl_shies/shies.lua', nil)
         	end
      	end,
	  	onActivate = function(object: core.GameObject)
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
   	}
}