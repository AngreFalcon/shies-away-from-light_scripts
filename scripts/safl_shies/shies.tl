local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local anim = require('openmw.animation')
local cmn = require('scripts.safl_shies.common')

-- Credit to Grumpy and Kateri for their companion mwscripts, which were used as the foundation from which this script was built

-- Aliases
local attributes = {types.Actor.stats.dynamic.health,types.Actor.stats.dynamic.magicka,types.Actor.stats.dynamic.fatigue}
local selfObj = self as core.GameObject

-- Constants
local SCRIPT_VERSION <const> = 1 -- Increment whenever onSave is changed
local MOD_SPEED_DISTANCE_THRESHOLD <const> = 300 -- The distance threshold that determines whether follower moves at normal speed or speeds up to catch up with the player
local CATCHUP_MULT <const> = 2.25 -- The value to multiply the player's speed and athletics value by before applying it as a modifier to follower if they falls behind
local FOLLOW_MOD <const> = 15 -- The modifier to be applied to follower's speed and athletics when normally following the player
local WANDER_MOD <const> = 40 -- The modifier to be applies to follower's speed when wandering instead of followings
local DEFAULT_SPELL_TIMER <const> = 10 -- The time in seconds to wait until follower can cast another spell
local DEFAULT_POTION_TIMER <const> = 60 -- The time in seconds to wait until follower can consume another potion of the same type if the potion's actual duration couldn't be found
local SPELL_EFFECT_HANDICAP <const> = 0.75 -- When comparing the restorative effects of spells vs potions, use this multiplier as a handicap for spells to make them appear more favorable due to the fact that spell casts are less limited than potions
local POTION_WASTE_THRESHOLD <const> = 0.25 -- The percentage threshold that determines whether a restorative potion's effects are considered wasted or not. At 0.25, if follower is only missing 25 health or less, a restore health potion with an effect greater than 100 would be considered wasted
local ATTRIBUTE_PANIC_THRESHOLD <const> = 0.75 -- The percentage missing from an attribute before follower should ignore the potion waste threshold and consume a restorative potion anyway. At 0.75, if follower is missing more than 75% health, follower will use a restore health potion whether its effect would be considered wasted or not
local WARP_TIMER <const> = 6 -- Default value for the warp timer
local SHEATHE_TIMER <const> = 4.4 -- Default value for the sheathe timer
local MAINTAIN_DISTANCE_LOWER_THRESHOLD <const> = 70 -- The lower distance threshold that forces follower to wander away from the player
local MAINTAIN_DISTANCE_UPPER_THRESHOLD <const> = 100 -- The upper distance threshold that makes companion follow the player again after moving away
local WANDER_DISTANCE <const> = 300 -- The distance parameter for follower's wander package when maintaining their distance
local NUDGE_DELAY <const> = 4 -- The number of seconds follower should wander after being nudged before following the player again
local MWVAR_TRUE <const> = 1 -- MWScript does not have boolean types, so all MWVars are numbers even if they're being used as boolean flags
local MWVAR_FALSE <const> = 0 -- MWScript does not have boolean types, so all MWVars are numbers even if they're being used as boolean flags
local DELAY <const> = 0.5 * time.second -- The number of seconds to wait before executing our delayed, non-priority functions

-- Shies Constants
local FLEE_THRESHOLD <const> = 0.1 -- The health percentage at which shies should flee from combat via recall
local SHIES_FLED_FOUND_STAGE <const> = 40 -- The stage at which the player has found and spoken with shies after shies fled from combat for the first time
local RECALL_TIMEOUT <const> = 2 * time.second -- The number of seconds it will take for shies' recall to complete when initiated
local INIT_DATA <const>: cmn.SaveData = {recallLoc = {cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251)}} -- Initial recall point for shies

-- Variables
local RecallLoc: cmn.CellLoc
local player: core.GameObject
local checks: {cmn.Flag: boolean} = {}
local restoreAttr: {cmn.RestoreAttr} = {}
local timers: {cmn.Timer: number} = {}

-- Warp function variables
local posA: cmn.CellLoc
local posB: cmn.CellLoc
local posC: cmn.CellLoc
local doOnce: boolean
local doOnce2: boolean

-- MWScript variables
-- Important to note: all MWScript variables are automatically cast to all lowercase
-- If making a follower that uses this script, the follower must have the following variables declared in MWScript within their .esp plugin file
local MWVars: {string: number} = {}
--[[
Variables:
short companion -- Engine variable -- True if follower is currently following the player. If 0, companion dialogue topics don't appear
short nohello -- Engine variable -- 
short nolore -- Engine variable --
short compmove -- True if the player has asked follower to maintain their distance
short onetimemove -- True if the player has asked follower to move out of the way
short weapuse -- True if the player has asked follower to use the same weapons as the player
short addonce -- True after the mwscript has executed once, is used to initialize companion to 0

-- Shies-specific MWVars
short fled -- True if shies has teleported away during combat
]]


-- Utility functions -- Functions that may return game values or that other functions may depend on for calculations or checks
local function updateMWVar(varName: string, varData: number) -- Send an event to the global script to update a single mwscript variable with the provided value
	core.sendGlobalEvent("updateMWVar", {varName, varData, selfObj})
end

local function isFollowing(): boolean -- Simply return true or false if companion is currently following any player
	local currentPackage = ai.getActivePackage()
	return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

local function getPlayerLeader() -- Gets the player object that companion is currently following
	if isFollowing() then
		player = ai.getActiveTarget("Follow")
	end
end

local function getMaxAttr(attr: types.DynamicStat): number -- Get the maximum value of the specified dynamic stat
    return attr.base + attr.modifier
end

local function getAttrDiff(attr: types.DynamicStat): number -- Get the missing value of the specified dynamic stat
	return getMaxAttr(attr) - attr.current
end

local function getPrefHealAmount(attrDiff: number, magnitude1: number, magnitude2: number): boolean -- Returns true if the first magnitude is better, false if the second magnitude is preferable
	return (math.abs(attrDiff - magnitude1) < math.abs(attrDiff - magnitude2))
end

local function checkAttrDamaged(attr: types.DynamicStat): boolean -- Returns true if the provided attribute is not currently full
	return attr.current < getMaxAttr(attr)
end

local function fullHeal() -- Fully restore follower's health
    attributes[1](selfObj).current = getMaxAttr(attributes[1](selfObj))
end

local function checkForPotion(potionName: string): boolean -- Returns true if follower has any of the specified potions in their inventory
	local inventory = types.Actor.inventory(selfObj)
	return inventory:countOf(potionName) > 0
end

local function getPlayerCellPos(): cmn.CellLoc -- Get the cell location of the player that companion is currently following
	return {cellId = player.cell.name, cellPos = player.position}
end

local function getCoDist(vector1: util.Vector3, vector2: util.Vector3): number -- Get cosine distance between two vectors
	local tempVar1 = vector1.x - vector2.x
	local tempVar2 = vector1.y - vector2.y
	return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function setSheatheWarpTimers(dt: number) -- Sheathe weapon after combat check
	if checks["combat"] == true then
		timers["warp"] = WARP_TIMER
		timers["sheathe"] = timers["sheathe"] - dt
		if core.sound.isSoundPlaying("Weapon Swish", selfObj) == true
			or core.sound.isSoundPlaying("crossbowShoot", selfObj) == true
			or core.sound.isSoundPlaying("bowShoot", selfObj) == true
			or core.sound.isSoundPlaying("mysticism cast", selfObj) == true
			or core.sound.isSoundPlaying("restoration cast", selfObj) == true
			or core.sound.isSoundPlaying("destruction cast", selfObj) == true
			or core.sound.isSoundPlaying("illusion cast", selfObj) == true
		then
			timers["sheathe"] = SHEATHE_TIMER
		elseif timers["sheathe"] <= 0 then
			checks["combat"] = false
			if types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then
				-- cast levitation spell on player? not sure why
			else
				types.Actor.setStance(selfObj, types.Actor.STANCE.Nothing)
			end
		end
	elseif types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon
		or types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell
	then
		checks["combat"] = true
		timers["warp"] = WARP_TIMER
		timers["sheathe"] = SHEATHE_TIMER
	end
end

local function updateTimers(dt: number) -- This function updates our various timers by dt, the time passed since this script's last executions
	for i = 1, #restoreAttr do
		if restoreAttr[i].potionTimer > 0 then
			restoreAttr[i].potionTimer = restoreAttr[i].potionTimer - dt
		end
		if restoreAttr[i].spellTimer > 0 then
			restoreAttr[i].spellTimer = restoreAttr[i].spellTimer - dt
		end
	end

	if timers["warp"] > 0 then
		timers["warp"] = timers["warp"] - dt
	end

	if ((checks["fly"] == false) and (types.Actor.isOnGround(selfObj) == false)) or timers["freefall"] < 0 then
		timers["freefall"] = timers["freefall"] + dt
	elseif timers["freefall"] > 0 then -- A negative timers["freefall"] implies a slowfall potion is active and the timer should not be reset
		timers["freefall"] = 0
	end

	setSheatheWarpTimers(dt)
end

	-- Shies-specific functions
local function triggerShiesFledQuest() -- Used to trigger the shies fled quest. Should only be triggered once
	if player ~= nil then
		player:sendEvent("shiesFled", nil)
	end
end
--

-- Gameplay functions -- Functions that modify follower's gameplay behavior
local function setSneak() -- Make sure if the player is sneaking, follower sneaks as well
	if player ~= nil then
		player:sendEvent("getSneakVal", selfObj)
	end
	if (selfObj as self).controls.sneak ~= checks["playerSneak"] then
		(selfObj as self).controls.sneak = checks["playerSneak"]
	end
end

local function makeCompanionFollow() -- Helper function for setting the Follow AI package
	ai.startPackage({
		type = "Follow",
		target = player
	})
end

local function toggleEffect(flag: cmn.Flag, effectType: string) -- This function should apply the levitate effect to companion if the player is levitating, and remove it if the player isn't
	local playerEffect = types.Actor.activeEffects(player):getEffect(effectType, nil).magnitude
	if playerEffect > 0 and checks[flag] == false then
		types.Actor.activeEffects(selfObj):modify(playerEffect, effectType, nil)
		checks[flag] = true
	elseif playerEffect <= 0 and checks[flag] == true then
		local companionEffect = types.Actor.activeEffects(selfObj):getEffect(effectType, nil).magnitude
		types.Actor.activeEffects(selfObj):modify(-(companionEffect), effectType, nil)
		checks[flag] = false
	end
end

local function consumePotion(potionID: string, effectName: string): number -- Sends a global event to trigger follower to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
	local potion = types.Actor.inventory(selfObj):find(potionID)
	local potionEffects = types.Potion.record(potion).effects
	local duration: number = DEFAULT_POTION_TIMER
	if effectName ~= nil then
		for i = 1, #potionEffects do
			if potionEffects[i].effect.name == effectName then
				duration = potionEffects[i].duration
			end
		end
	end
	core.sendGlobalEvent("UseItem", {object = potion, actor = selfObj})
	return duration
end

local function castSpell(spell: core.Spell, castSound: string): number
	local duration: number = DEFAULT_SPELL_TIMER
	types.Actor.activeSpells(selfObj):add({ -- Add the spell's effect to the follower's list of spell effect that are currently applied
		id = spell.id,
		effects = {0},
		name = spell.name,
		caster = selfObj,
	})
	attributes[2](selfObj).current = attributes[2](selfObj).current - spell.cost -- Subtract the cost of the spell from the follower's current magicka
	for _, effect in pairs((spell.effects as {any: core.MagicEffectWithParams})) do -- For every effect provided by this spell, play an appropriate vfx and sound
		local vfx = effect.effect
		selfObj:sendEvent('AddVfx', {
        	model = types.Static.record(vfx.castStatic).model,
        	options = {
            	vfxId = "followerCast" .. effect.id,
            	particleTextureOverride = vfx.particle,
            	loop = false,
        	}
    	})
		print(vfx.id)
		--core.sound.playSound3d(vfx.castSound, selfObj, {}) -- Due to what appears to be a bug with the lua API, it's not actually possible to retrieve any sounds for our spell effect. For now the sound must be passed in as a string
		core.sound.playSound3d(castSound, selfObj, {})
		if duration < effect.duration then
			duration = effect.duration -- Get the longest duration of any of the effects supplied by this spell and use that as the duration of the spell itself
		end
	end
	return duration
end

--[[ Unable to make the follower cast using self.controls. This, however, would be preferable to adding a spell effect using types.Actor.activeSpells if it can be made to work
	local function castSpell1(spell: core.Spell, duration: number)
	local currentStance = types.Actor.getStance(selfObj)
	--local currentSpell = (types.Actor.getSelectedSpell(selfObj) as core.Spell)
	--local currentEnchItem = (types.Actor.getSelectedEnchantedItem(selfObj) as core.GameObject)

	print(spell.id)
	types.Actor.setSelectedSpell(selfObj, spell)
	print((types.Actor.getSelectedSpell(selfObj) as core.Spell).id)
	-- spell is properly selected

	print(currentStance)
	types.Actor.setStance(selfObj, types.Actor.STANCE.Spell)
	print(types.Actor.getStance(selfObj))
	-- stance is properly set
	
	(selfObj as self).controls.use = (selfObj as self).ATTACK_TYPE.Any
	-- spell is not cast

	timers["restorespell"] = duration

	-- Restore state from before casting restore spell
	if currentSpell ~= nil then
		types.Actor.setSelectedSpell(selfObj, currentSpell)
	elseif currentEnchItem ~= nil then
		types.Actor.setSelectedEnchantedItem(selfObj, currentEnchItem)
	end
	types.Actor.setStance(selfObj, currentStance)
end]]

local function selectRestorePotion(effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
	local inventory = types.Actor.inventory(selfObj)
	local selectedPotion: types.PotionRecord
	local selectedPotionMagnitude: number
	for _, potion in pairs(((inventory:getAll(types.Potion) as types.Potion):record()) as {any: types.PotionRecord}) do
		for _, effect in pairs(potion.effects as {any: core.MagicEffectWithParams}) do
			if effect.id == effectId then
				local potionMagnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration -- Find the average magnitude of the given effect for this potion
				if ((selectedPotion == nil) or getPrefHealAmount(attrDiff, potionMagnitude, selectedPotionMagnitude) == true) then -- Choose the potion that would be efficient for the missing amount of whichever attribute this is
					selectedPotion = potion
					selectedPotionMagnitude = potionMagnitude
				end
			end
		end
	end
	if selectedPotion ~= nil and selectedPotionMagnitude ~= nil
	and (((selectedPotionMagnitude * POTION_WASTE_THRESHOLD) < attrDiff) -- Only select potion if less than 25% of its effect will be wasted
	or (attrDiff > (attrMax * ATTRIBUTE_PANIC_THRESHOLD))) -- However, if follower is missing more than 75% of their attribute, ignore the waste threshold
	then
		return {selectedPotion.id, selectedPotionMagnitude}
	else
		return nil
	end
end

local function selectRestoreSpell(effectId: string, attrDiff: number, currentMagicka: number): {core.Spell, number} -- Selects the best restorative spell the NPC currently has (prioritizes magnitude over cost). Prefers the spell that restores closest to the missing amount of whichever attribute is being restored rather than just the spell with the greatest magnitude, currently ignores all side effects of casting the spell. Returns nil if no spell is found
	local spells = types.Actor.spells(selfObj)
	local selectedSpell: core.Spell
	local selectedSpellMagnitude: number = 0
	for _, spell in pairs((spells as {any: core.Spell})) do
		if spell.type == core.magic.SPELL_TYPE.Spell or (spell.type == core.magic.SPELL_TYPE.Power and types.Actor.activeSpells(selfObj):canUsePower(spell.id) == true) then -- Only use a spell or power, no abilities. Powers will only be cast if they are not currently on cooldown
			for _, effect in pairs((spell.effects as {any: core.MagicEffectWithParams})) do
				if effect.id == (effectId as string) and effect.range == core.magic.RANGE.Self then -- We only care if at least one of the effects of this spell restores our chosen attribute and works on self
					local spellMagnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration -- Find the average magnitude of the given effect for this spell
					if ((selectedSpell == nil) or getPrefHealAmount(attrDiff, spellMagnitude, selectedSpellMagnitude) == true) -- Choose the spell that would be efficient for the missing amount of whichever attribute this is
					and (spell.cost < currentMagicka) -- Only selects this spell if we can afford to cast it
					then
						selectedSpell = spell
						selectedSpellMagnitude = spellMagnitude
					end
				end
			end
		end
	end
	if selectedSpell ~= nil and selectedSpellMagnitude ~= nil then
		return {selectedSpell, selectedSpellMagnitude}
	else
		return nil
	end
end

local function drinkPotionOrCastSpell(iter: integer)
	local attrDiff = getAttrDiff(attributes[iter](selfObj))
	local potion: {string, number}
	local spell: {core.Spell, number}
	if restoreAttr[iter].potionTimer <= 0 then
		potion = selectRestorePotion(restoreAttr[iter].effectId, attrDiff, getMaxAttr(attributes[iter](selfObj)))
	end
	if restoreAttr[iter].spellTimer <= 0 and attributes[2](selfObj).current > 0 then
		spell = selectRestoreSpell(restoreAttr[iter].effectId, attrDiff, attributes[2](selfObj).current)
	end

	if potion == nil and spell ~= nil then -- If no applicable potions are available, use a spell
		restoreAttr[iter].spellTimer = castSpell(spell[1], "restoration cast")
	elseif spell == nil and potion ~= nil then -- If no applicable spells are available, use a potion
		restoreAttr[iter].potionTimer = consumePotion(potion[1], restoreAttr[iter].effectName)
	elseif spell ~= nil and potion ~= nil then -- Both a spell and a potion appear to be available
		if getPrefHealAmount(attrDiff, potion[2], (spell[2] * SPELL_EFFECT_HANDICAP)) == true then
			restoreAttr[iter].potionTimer = consumePotion(potion[1], restoreAttr[iter].effectName)
		else
			restoreAttr[iter].spellTimer = castSpell(spell[1], "restoration cast")
		end
	end
end

local function checkAttributes() -- Used to call various functions that affect follower's dynamic attributes like health, fatigue, and magicka
	for i = 1, #attributes do
		if checkAttrDamaged(attributes[i](selfObj)) == true then
			drinkPotionOrCastSpell(i)
		end
	end
end

local function freeFall() -- Used to call various functions that should trigger while follower is in freefall
	if timers["freefall"] > 1 and checkForPotion("p_slowfall_s") then
		timers["freefall"] = -(consumePotion("p_slowfall_s", "SlowFall"))
	end
end

	-- Shies-specific functions
local function shiesIncapacitated(getBackUp: boolean) -- This function applies and ends the knockout animation for shies. The boolean parameter must be true for the animation to end
	local animName = "knockout"
	if anim.isPlaying(selfObj, animName) == false then
		anim.clearAnimationQueue(selfObj, false) -- Empties anim queue to immediately play the knockout animation
		anim.playQueued(selfObj, animName, {})
	elseif getBackUp == true then
		I.AnimationController.addTextKeyHandler(animName, function(animGroup: string, key: string)
			anim.playQueued(selfObj, animGroup, {startkey = 'stop', stopkey = 'stop', loops = 0})
			if key.sub(key, #key - #'stop') == 'stop' then
				anim.clearAnimationQueue(selfObj, true) -- Only clear the anim queue once the knockout anim has finished its current loop
			end
		end)
		checks["incapacitated"] = false
	end
end

local function flee() -- Triggers if shies' health drops below a certain threshold. Plays the magic cast VFX and then teleports shies to a preset location while canceling shies' follow AI package
    local vfx = core.magic.effects.records["recall"] -- Trigger the Recall vfx
    selfObj:sendEvent('AddVfx', {
        model = types.Static.record(vfx.hitStatic).model,
        options = {
            vfxId = "vfxShiesFlee",
            particleTextureOverride = vfx.particle,
            loop = false,
        }
    })

    local cb = time.registerTimerCallback( -- Teleport away after RECALL_TIMEOUT seconds
        selfObj.id .. "_FleeCallback",
        function(actor: core.GameObject)
			ai.removePackages("Combat")
			ai.removePackages("Follow")
			if RecallLoc == INIT_DATA.recallLoc and (types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].started == false then
				triggerShiesFledQuest() -- The player has not changed Shies' marked location. This likely means the Shies Fled quest has not been started yet; we can further check by checking the player's journal entries
			end
            return core.sendGlobalEvent("teleport", {
				actor = actor,
				cell = RecallLoc.cellId,
				position = RecallLoc.cellPos
			})
        end,
        nil
    )
	if RecallLoc == INIT_DATA.recallLoc and (types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage < SHIES_FLED_FOUND_STAGE then -- The player has not recovered shies yet
		checks["incapacitated"] = true
	end
    time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end

local function shiesCheckAttributes() -- Calls shies-specific functions relating to attributes
	if attributes[1](selfObj).current > 0 and attributes[1](selfObj).current / getMaxAttr(attributes[1](selfObj)) < FLEE_THRESHOLD then -- Check health ratio
		updateMWVar("companion", MWVAR_FALSE)
		checks["cMove"] = false
        flee() -- Teleport Shies away from combat to whatever position he has marked
		fullHeal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
		return
	end
end
--

-- Movement functions - Functions that modify follower's movement behavior
local function forceZLevel() -- If in combat, levitating and the player Z level is different from follower's, force follower's Z level to the player's
	local playerPos: cmn.CellLoc = (getPlayerCellPos() as cmn.CellLoc)
	local followerPos = selfObj.position
	if checks["fly"] == true and types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon then
		core.sendGlobalEvent("teleport", {
			actor = selfObj,
			cell = selfObj.cell.name,
			position = util.vector3(followerPos.x, followerPos.y, playerPos.cellPos.z)
		})
	end
end

local function maintainDistance() -- Toggles follower between wandering and following the player in order to maintain a small window of distance from the player. Works only if the player activates it from dialogue by updating the "compmove" variable
	local followerPos = selfObj.position
	local playerPos: cmn.CellLoc = (getPlayerCellPos() as cmn.CellLoc)
	if playerPos == nil then
		return
	end
	if isFollowing() and MWVars["compmove"] == MWVAR_TRUE and checks["cMove"] == false
	and getCoDist(followerPos, playerPos.cellPos) < MAINTAIN_DISTANCE_LOWER_THRESHOLD
	then
		ai.removePackages("Follow")
		ai.startPackage({
			type = "Wander",
			distance = WANDER_DISTANCE
		})
		checks["cMove"] = true
	end
	if checks["cMove"] == true and getCoDist(followerPos, playerPos.cellPos) > MAINTAIN_DISTANCE_UPPER_THRESHOLD then
		ai.removePackages("Wander")
		makeCompanionFollow()
		checks["cMove"] = false
	end
end

local function nudge(timePassed: number) -- Waits 4 seconds before making companion follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make them move
	if MWVars["onetimemove"] == MWVAR_TRUE then
		timers["move"] = timers["move"] + timePassed
		if timers["move"] >= NUDGE_DELAY then
			timers["move"] = 0
			makeCompanionFollow()
			updateMWVar("onetimemove", MWVAR_FALSE)
		end
	end
end

local function warpToPlayer() -- If the player gets too far from follower, teleport follower closer to the player
	posA = getPlayerCellPos()
	if posA == nil then return end
	
	if doOnce == false then
		posB = getPlayerCellPos()
		doOnce = true
	end
	
	local coDist = getCoDist((posA as cmn.CellLoc).cellPos, posB.cellPos)
	if coDist > 360 then doOnce = false end
	
	if (coDist > 180 and doOnce2 == false) or posC == nil then
		posC = getPlayerCellPos()
		doOnce2 = true
	end

	local coDist2 = getCoDist((posA as cmn.CellLoc).cellPos, (posC as cmn.CellLoc).cellPos)
	if coDist2 > 360 then doOnce2 = false end

	if timers["warp"] <= 0 and getCoDist(selfObj.position, (getPlayerCellPos() as cmn.CellLoc).cellPos) > 680 then
		if coDist > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = (posC as cmn.CellLoc).cellId,
				position = (posC as cmn.CellLoc).cellPos
			})
			makeCompanionFollow()
		elseif coDist2 > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = posB.cellId,
				position = posB.cellPos
			})
			makeCompanionFollow()
		end
	end
end

local function setDefaultSpeed() -- Sets follower's speed modifier while not following the player
	types.Actor.stats.attributes.speed(selfObj).modifier = WANDER_MOD
end

local function modSpeedAndAthletics() -- Set follower's speed and athletics modifier to a flat value if they're within a certain distance of the player, or add a multiplier based off the player's stats if they're too far
	local followerSpeed = types.Actor.stats.attributes.speed(selfObj)
	local followerAthletics = types.NPC.stats.skills.athletics(selfObj)
	local cSpeed = types.Actor.stats.attributes.speed(player).modified * CATCHUP_MULT
	local cAthletics = types.NPC.stats.skills.athletics(player).modified * CATCHUP_MULT
	if (followerSpeed.modifier ~= FOLLOW_MOD or followerAthletics.modifier ~= FOLLOW_MOD)
		and (getCoDist(selfObj.position, getPlayerCellPos().cellPos) <= MOD_SPEED_DISTANCE_THRESHOLD)
	then
		followerSpeed.modifier = FOLLOW_MOD
		followerAthletics.modifier = FOLLOW_MOD
	elseif (followerSpeed.modifier ~= cSpeed or followerAthletics.modifier ~= cAthletics)
		and (getCoDist(selfObj.position, getPlayerCellPos().cellPos) > MOD_SPEED_DISTANCE_THRESHOLD)
	then
		followerSpeed.modifier = cSpeed
		followerAthletics.modifier = cAthletics
	end
end
--

-- Handler functions - Functions that will be called directly by OpenMW
time.runRepeatedly(
	function() 
		if isFollowing() then
			modSpeedAndAthletics()
		elseif player ~= nil then
			setDefaultSpeed()
		end
	end, DELAY, {}
)

local function onUpdate(dt: number) -- Called every frame while the script is loaded
	if core.isWorldPaused() == true then
		return
	end
	getPlayerLeader()
	
	shiesCheckAttributes()
	if checks["incapacitated"] == true then
		-- Right now there is only one instance of shies being incapacitated, and only one condition under which he gets back up
		-- However, if this mechanic is extended in the future, passing a boolean parameter as the get up condition makes this trivial
		shiesIncapacitated((types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage >= SHIES_FLED_FOUND_STAGE)
	end
    checkAttributes()

	if checks["fly"] == false and types.Actor.isOnGround(selfObj) == false then
		freeFall()
	end

	updateTimers(dt)

	if isFollowing() then
		setSneak()
		toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate as string))
		toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking as string))
		forceZLevel()
		warpToPlayer()
	elseif player ~= nil then
		maintainDistance()
		nudge(dt)
	end
end

local function onInit() -- Called when the script is created but not loaded
	RecallLoc = INIT_DATA.recallLoc
	checks["cMove"] = false
	checks["fly"] = false
	checks["ww"] = false
	checks["combat"] = false
	checks["incapacitated"] = false
	checks["playerSneak"] = false
	doOnce = false
	doOnce2 = false
	timers["move"] = 0
	timers["sheathe"] = 0
	timers["warp"] = 0
	timers["freefall"] = 0
	restoreAttr[1] = {
		potionTimer = 0,
		spellTimer = 0,
		effectName = "Restore Health",
		effectId = "restorehealth",
	}
	restoreAttr[2] = {
		potionTimer = 0,
		spellTimer = 0,
		effectName = "Restore Magicka",
		effectId = "restoremagicka",
	}
	restoreAttr[3] = {
		potionTimer = 0,
		spellTimer = 0,
		effectName = "Restore Fatigue",
		effectId = "restorefatigue",
	}
end

local function onSave(): cmn.SaveData -- Called when the game saves, even if currently in an inactive state
	for k, v in pairs(MWVars) do
		updateMWVar(k, v)
	end
	return {
		version = SCRIPT_VERSION,
		recallLoc = RecallLoc,
		player = player,
		checks = checks,
		timers = timers,
		restoreAttr = restoreAttr,
		posA = posA,
		posB = posB,
		posC = posC,
		doOnce = doOnce,
		doOnce2 = doOnce2,
	}
end

local function onLoad(data: cmn.SaveData) -- Called only when the script loads, not the saved game. will not be called if the script was not previously saved
	if (not data) or (not data.version) or (data.version < SCRIPT_VERSION) then
		print('Was saved with an old version of the script, initializing to default')
		RecallLoc = INIT_DATA.recallLoc
		return
	elseif (data.version > SCRIPT_VERSION) then
		error('Required update to a new version of the script')
	elseif (data.version == SCRIPT_VERSION) then
		RecallLoc = data.recallLoc
		player = data.player
		checks = data.checks
		timers = data.timers
		restoreAttr = data.restoreAttr
		posA = data.posA
		posB = data.posB
		posC = data.posC
		doOnce = data.doOnce
		doOnce2 = data.doOnce2
	end
end
--

return {
    engineHandlers = {
        onUpdate = onUpdate,
		onInit = onInit,
		onSave = onSave,
		onLoad = onLoad,
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
        ["Hit"] = function(attack: I.Combat.AttackInfo) -- Example of sending an event (with a message) back to the player that hit him
            local attackerObj = attack.attacker as core.GameObject
            attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
        end,
        ["hurtShies"] = function() -- For testing the "Recall away at low health" feature - this event is sent from the player script
            attributes[1](selfObj).current = 1
        end,
		["shiesActivated"] = function()
		end,
		["playerSneak"] = function(sneaking: boolean)
			if sneaking ~= nil then
				checks["playerSneak"] = sneaking
			end
		end,
    }
}