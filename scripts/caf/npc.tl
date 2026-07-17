local core = require('openmw.core')
local types = require('openmw.types')
local anim = require('openmw.animation')
local this = require('openmw.self')
local storage = require('openmw.storage')

local interface Range 
	min: number
	max: number
	percent: boolean
	maxValue: number
end

local MWVars: {string: number}

local DYNAMIC_STATS <const>: {string: function(core.GameObject): types.DynamicStat} = {
	["health"] = types.Actor.stats.dynamic.health,
	["fatigue"] = types.Actor.stats.dynamic.fatigue,
	["magicka"] = types.Actor.stats.dynamic.magicka,
}

local argonianTaper = {
	conditions = {
		{
			race = { "argonian" }, --
			isMale = true, --
			werewolf = false, --
			dead = false, --
			mwvars = {
				companion = { min = 1, max = 1, },
				--arousal = { min = 100, max = 100, }, -- this range is only true if arousal is 100 exactly
				--stinky = { min = 0, max = 100, }, -- this range is only true is stinky is between 0 and 100 (inclusive)
			},
			dynStats = {
				health = { min = 0.5, max = 1, percent = true },
				--fatigue = { min = 100, max = 10, percent = false }, -- this range excludes all values between 10 and 100, meaning the condition is only true if fatigue is greater than 99 or less then 11
			},
			equipmentslot = {
				["Ammunition"] = true,
				["Amulet"] = false,
				"Belt",
				"Boots",
				"CarriedLeft",
				"CarriedRight",
				"Cuirass",
				"Greaves",
				"Helmet",
				"LeftGauntlet",
				"LeftPauldron",
				"LeftRing",
				"Pants",
				"RightGauntlet",
				"RightPauldron",
				"RightRing",
				"Robe",
				"Shirt",
				"Skirt",
			}
		},
	},
	mesh = 'Meshes/bat/shiestaper.nif',
	node = "groin",
	duration = -1,
}

local function compareRange(value: number, r: Range, valueMax?: number): boolean
	if not r.percent then
		if ((r.min > r.max) and (value < r.min) and (value > r.max)) or ((value < r.min) or (value > r.max)) then
			return false
		end
	elseif valueMax ~= nil and valueMax ~= 0 then
		local ratio = value / valueMax
		if ((r.min > r.max) and (ratio < r.min) and (ratio > r.max)) or ((ratio < r.min) or (ratio > r.max)) then
			return false
		end
	else
		return false
	end
	return true
end

local function applyCosmetic(effectID: string, node: string, mesh: string)
	anim.addVfx(this as core.GameObject, mesh, {
    	loop = true,
    	boneName = node,
		vfxId = effectID,
		useAmbientLight = false,
  	})
end

local function removeCosmetic(effectID: string)
	anim.removeVfx(this as core.GameObject, effectID)
end

local function checkEquipmentSlots()

end

local function checkDynStats(attributes: { string: Range }): boolean
	for k, range in pairs(attributes) do
		local getStat = DYNAMIC_STATS[k];
		local dynStat = getStat and getStat(this.object)
		if dynStat and compareRange(dynStat.current, range, dynStat.base + dynStat.modifier) == false then
			return false
		end
	end
	return true
end

local function checkMWVars(mwvars: { string: Range }): boolean
	local varTable = storage.globalSection(this.object.id)
	if varTable == nil then
		return false
	end
	for k, range in pairs(mwvars) do
		local value = varTable:get(k)
		if value == nil or compareRange(value as integer, range, range.maxValue) == false then
			return false
		end
	end
	return true
end

local function checkDead(actorDead: boolean, condDead: boolean): boolean
	return actorDead == condDead
end

local function checkWerewolf(actorWerewolf: boolean, condWerewolf: boolean): boolean
	return actorWerewolf == condWerewolf
end

local function checkSex(actorSex: boolean, condSex: boolean): boolean
	return actorSex == condSex
end

local function checkRace(actorRace: string, condRace: {string}): boolean
	for i = 1, #condRace do
		if actorRace == condRace[i] then
			return true
		end
	end
	return false
end

local function checkEffectConditions()
	local conditions = argonianTaper.conditions
	local effectID = "taper"

	for i = 1, #conditions do
		if conditions[i].race ~= nil and checkRace(types.NPC.record(this.object as types.Actor).race, conditions[i].race) == false then
			--print("race")
			--print(types.NPC.record(this.object).id)
			removeCosmetic(effectID)
			return
		end
		if conditions[i].isMale ~= nil and checkSex(types.NPC.record(this.object as types.Actor).isMale, conditions[i].isMale) == false then
			--print("sex")
			--print(types.NPC.record(this.object).id)
			removeCosmetic(effectID)
			return
		end
		if conditions[i].werewolf ~= nil and checkWerewolf(types.NPC.isWerewolf(this.object), conditions[i].werewolf) == false then
			--print("werewolf")
			--print(types.NPC.record(this.object).id)
			removeCosmetic(effectID)
			return
		end
		if conditions[i].dead ~= nil and checkDead(types.Actor.isDead(this.object), conditions[i].dead) == false then
			--print("dead")
			--print(types.NPC.record(this.object).id)
			removeCosmetic(effectID)
			return
		end
		if conditions[i].mwvars ~= nil and checkMWVars(conditions[i].mwvars) == false then
			--print("mwvars")
			--print(types.NPC.record(this.object).id)
			removeCosmetic(effectID)
			return
		end
		if conditions[i].dynStats ~= nil and checkDynStats(conditions[i].dynStats) == false then
			--print("dynamic stats")
			--print(types.NPC.record(this.object).id)
			removeCosmetic(effectID)
			return
		end
		--if conditions[i].equipmentslot ~= nil and checkEquipmentSlots(types.Actor.isDead(this.object), conditions[i].equipmentslot) == false then
		--	print("equipment slots")
		--	print(types.NPC.record(this.object).id)
		--	removeCosmetic(effectID)
		--	return
		--end
	end
	applyCosmetic(effectID, argonianTaper.node, argonianTaper.mesh)
end

return {
   	engineHandlers = {
      	onActive = function()
			checkEffectConditions()
		end,
		onUpdate = checkEffectConditions,
   	},
	eventHandlers = {
		["fetchMWVars"] = function(data: {string: number})
			MWVars = data
			for k, v in pairs(data) do
				if MWVars[k] ~= v then
					MWVars[k] = v
				end
			end
		end,
	}
}
