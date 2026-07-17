local core = require('openmw.core')
local util = require('openmw.util')
local world = require('openmw.world')
local types = require('openmw.types')

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

local function updateMWVar(data: {{string: number}, core.GameObject}) -- Updates the value of the specified mwscript variable
	local localScript = world.mwscript.getLocalScript(data[2], nil)
	if localScript ~= nil then
		for k, v in pairs(data[1]) do
			(localScript as world.MWScript).variables[k] = v
		end
	end
end

local function syncMWVars(actor: core.GameObject) -- Get the current state of all local mwscript variables associated with the provided actor
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

local function changeEnchCharge(data: {core.GameObject, number}) -- Modify the current charge of the specified enchanted item
	local itemData = types.Item.itemData(data[1])
	itemData.enchantmentCharge = itemData.enchantmentCharge - data[2]
end

return {
   	engineHandlers = {
      	onActorActive = function(actor: core.GameObject)
         	if actor.recordId == shies then
				shiesObj = actor
				syncMWVars(shiesObj)
            	actor:addScript('scripts/follower/shies.lua', nil)
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
		["changeEnchCharge"] = changeEnchCharge,
   	}
}