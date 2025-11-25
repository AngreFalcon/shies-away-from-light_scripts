local types = require('openmw.types')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local cmn = require('scripts.follower.common')

-- Credit to Grumpy and Kateri for their companion mwscripts, which were used as the foundation from which this script was built
local SCRIPT_VERSION <const> = 1 -- Increment whenever onSave is changed

local interface OMW_SELF_CONTROLS
	sneak: boolean
end

local interface OMW_SELF_PACKAGE
    controls: OMW_SELF_CONTROLS
end

local interface OMW_AI_PACKAGE
    type: string
    target: core.GameObject
    distance: number
end

local interface OMW_AI
	getActiveTarget: function(string): core.GameObject
	getActivePackage: function(): OMW_AI_PACKAGE
    removePackages: function(string)
	startPackage: function(OMW_AI_PACKAGE)
end

local record Follower
    selfObj: core.GameObject
    record attributes is {attributes}
		health: function(core.GameObject): types.DynamicStat
		magicka: function(core.GameObject): types.DynamicStat
		fatigue: function(core.GameObject): types.DynamicStat
	end
    ai: OMW_AI
    record STAT_MOD
        CATCHUP_MULT: number
        FOLLOW: number
        WANDER: number
	end
	record DEFAULT_CD
		RESTORE: number
		ENCHANTMENT: number
		SPELL: number
		POTION: number
		SCROLL: number
		WARP: number
		SHEATHE: number
	end
	record RESTORE_WEIGHTS
		ENCHANTMENT: number
		SPELL: number
		POTION: number
		SCROLL: number
	end
    ATTRIBUTE_PANIC_THRESHOLD: number
	record WASTE_THRESHOLD
		POTION: number
		SCROLL: number
	end
	record DISTANCE_THRESHOLD
		MOD_SPEED: number
		MAINTAIN_LOWER: number
		MAINTAIN_UPPER: number
		WANDER: number
	end
	record BOOL
		TRUE: integer
		FALSE: integer
	end
	NUDGE_DELAY: number
	DELAY1: number
	DELAY2: number
	player: core.GameObject
    checks: {cmn.Flag: boolean}
    restoreAttr: {cmn.RestoreAttr}
	timers: {cmn.Timer: number}
    posA: cmn.CellLoc
    posB: cmn.CellLoc
    posC: cmn.CellLoc
    doOnce: boolean
    doOnce2: boolean
	MWVars: {string: number}
end

local function defaultFollower(): Follower
	local follower = {
		-- Aliases
	    selfObj: core.GameObject = nil,
	    attributes = {types.Actor.stats.dynamic.health, types.Actor.stats.dynamic.magicka, types.Actor.stats.dynamic.fatigue},
	    ai: OMW_AI = nil,
		
	    -- Constants
	    --SKILL_LEVEL_MULT <const> = 1.5 -- The multiplier to apply to all skill increases
	    STAT_MOD = {
	        CATCHUP_MULT = 2.25, -- Multiplier that is applied to the player's athletics and speed, the product of which is then added to the follower's athletics and speed as a modifier
	        FOLLOW = 15, -- Flat modifier to be applied to follower's speed and athletics when normally following the player
	        WANDER = 40, -- Flat modifier to be applies to follower's speed when wandering instead of followings
	    },
		DEFAULT_CD = { -- Default cooldowns in seconds
			RESTORE = 10, -- The general cooldown to wait before using any other restore effects, regardless of individual method cooldown
			ENCHANTMENT = 10, -- The default cooldown for a restorative enchantment if the actual duration couldn't be found
			SPELL = 10, -- The default cooldown for a restorative spell if the actual duration couldn't be found
			POTION = 60, -- The default cooldown for a restorative potion if the actual duration couldn't be found
			SCROLL = 60, -- The default cooldown for a restorative scroll if the actual duration couldn't be found
			WARP = 6, -- Default value for the warp timer
			SHEATHE = 4.4, -- Default value for the sheathe timer
		},
		RESTORE_WEIGHTS = { -- Multipliers to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
			ENCHANTMENT = 0.75,
			SPELL = 1,
			POTION = 1.25,
			SCROLL = 1.5,
		},
	    ATTRIBUTE_PANIC_THRESHOLD = 0.75, -- The percentage missing from an attribute before follower should ignore the waste threshold and consume a restorative consumable anyway. At 0.75, if follower is missing more than 75% health, follower will use a restore health consumable whether its effect would be considered wasted or not
		WASTE_THRESHOLD = { -- The percentage threshold that determines whether a restorative effect is considered wasted or not
			POTION = 0.25, -- At 0.25, if follower is only missing 25 health or less, a restorative effect with magnitude greater than 100 would be considered wasted
			SCROLL = 0.50, -- At 0.50, if follower is only missing 50 health or less, a restorative effect with magnitude greater than 100 would be considered wasted
		},
		DISTANCE_THRESHOLD = {
			MOD_SPEED = 300, -- The distance threshold that determines whether follower moves at normal speed or speeds up to catch up with the player
			MAINTAIN_LOWER = 70, -- The lower distance threshold that forces follower to wander away from the player
			MAINTAIN_UPPER = 100, -- The upper distance threshold that makes companion follow the player again after moving away
			WANDER = 300, -- The distance parameter for follower's wander package when maintaining their distance
		},
		BOOL = { -- MWScript does not have boolean types, so all MWVars are numbers even if they're being used as boolean flags
			TRUE = 1,
			FALSE = 0,
		},
		NUDGE_DELAY = 4, -- The number of seconds follower should wander after being nudged before following the player again
		DELAY1 = 0.5 * time.second, -- The number of seconds to wait before executing our delayed, non-priority functions
		DELAY2 = 5 * time.second, -- The number of seconds to wait before executing our delayed, non-priority functions
	
		-- Variables
	    player: core.GameObject = nil,
	    checks: {cmn.Flag: boolean} = {},
	    restoreAttr: {cmn.RestoreAttr} = {},
	    timers: {cmn.Timer: number} = {},
	
		-- Warp function variables - Must persist between function calls
	    posA: cmn.CellLoc = nil,
	    posB: cmn.CellLoc = nil,
	    posC: cmn.CellLoc = nil,
	    doOnce: boolean = nil,
	    doOnce2: boolean = nil,
	
		-- MWScript variables
		-- Important to note: all MWScript variables are automatically cast to all lowercase
		-- If making a follower that uses this script, the follower must have the following variables declared in MWScript within their .esp plugin file
		MWVars: {string: number} = {},
		--[[ MWVars:
			short companion -- Engine variable -- True if follower is currently following the player. If 0, companion dialogue topics don't appear
			short nohello -- Engine variable -- 
			short nolore -- Engine variable --
			short compmove -- True if the player has asked follower to maintain their distance
			short onetimemove -- True if the player has asked follower to move out of the way
			short weapuse -- True if the player has asked follower to use the same weapons as the player
			short addonce -- True after the mwscript has executed once, is used to initialize companion to 0
		]]
	}
	return follower as Follower
end

-- Utility functions -- Functions that may return game values or that other functions may depend on for calculations or checks
function Follower:updateMWVar(varName: string, varData: number) -- Send an event to the global script to update a single mwscript variable with the provided value
     core.sendGlobalEvent("updateMWVar", {varName, varData, self.selfObj})
 end

function Follower:isFollowing(): boolean -- Simply return true or false if companion is currently following any player
	local currentPackage = ai.getActivePackage()
	return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

function Follower:getPlayerLeader() -- Gets the player object that companion is currently following
	if self:isFollowing() then
		self.player = ai.getActiveTarget("Follow")
	end
end

function Follower:getMaxAttr(attr: types.DynamicStat): number -- Get the maximum value of the specified dynamic stat
    return attr.base + attr.modifier
end

function Follower:getAttrDiff(attr: types.DynamicStat): number -- Get the missing value of the specified dynamic stat
	return self:getMaxAttr(attr) - attr.current
end

function Follower:checkAttrDamaged(attr: types.DynamicStat): boolean -- Returns true if the provided attribute is not currently full
	return attr.current < self:getMaxAttr(attr)
end

function Follower:fullHeal() -- Fully restore follower's health
    self.attributes[1](self.selfObj).current = self:getMaxAttr(self.attributes[1](self.selfObj))
end

function Follower:checkForPotion(potionName: string): boolean -- Returns true if follower has any of the specified potions in their inventory
	local inventory = types.Actor.inventory(self.selfObj)
	return inventory:countOf(potionName) > 0
end

function Follower:getPlayerCellPos(): cmn.CellLoc -- Get the cell location of the player that companion is currently following
	return {cellId = self.player.cell.name, cellPos = self.player.position}
end

function Follower:getCoDist(vector1: util.Vector3, vector2: util.Vector3): number -- Get cosine distance between two vectors
	local tempVar1 = vector1.x - vector2.x
	local tempVar2 = vector1.y - vector2.y
	return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

function Follower:setSheatheWarpTimers(dt: number) -- Sheathe weapon after combat check
	if self.checks["combat"] == true then
		self.timers["warp"] = self.DEFAULT_CD.WARP
		self.timers["sheathe"] = self.timers["sheathe"] - dt
		if core.sound.isSoundPlaying("Weapon Swish", self.selfObj) == true
			or core.sound.isSoundPlaying("crossbowShoot", self.selfObj) == true
			or core.sound.isSoundPlaying("bowShoot", self.selfObj) == true
			or core.sound.isSoundPlaying("mysticism cast", self.selfObj) == true
			or core.sound.isSoundPlaying("restoration cast", self.selfObj) == true
			or core.sound.isSoundPlaying("destruction cast", self.selfObj) == true
			or core.sound.isSoundPlaying("illusion cast", self.selfObj) == true
		then
			self.timers["sheathe"] = self.DEFAULT_CD.SHEATHE
		elseif self.timers["sheathe"] <= 0 then
			self.checks["combat"] = false
			if types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Spell then
				-- cast levitation spell on player? not sure why
			else
				types.Actor.setStance(self.selfObj, types.Actor.STANCE.Nothing)
			end
		end
	elseif types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Weapon
		or types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Spell
	then
		self.checks["combat"] = true
		self.timers["warp"] = self.DEFAULT_CD.WARP
		self.timers["sheathe"] = self.DEFAULT_CD.SHEATHE
	end
end

function Follower:updateTimers(dt: number) -- This function updates our various timers by dt, the time passed since this script's last executions
	for i = 1, #self.restoreAttr do
		if self.restoreAttr[i].spellTimer > 0 then
			self.restoreAttr[i].spellTimer = self.restoreAttr[i].spellTimer - dt
		end
		if self.restoreAttr[i].enchantmentTimer > 0 then
			self.restoreAttr[i].enchantmentTimer = self.restoreAttr[i].enchantmentTimer - dt
		end
		if self.restoreAttr[i].potionTimer > 0 then
			self.restoreAttr[i].potionTimer = self.restoreAttr[i].potionTimer - dt
		end
		if self.restoreAttr[i].scrollTimer > 0 then
			self.restoreAttr[i].scrollTimer = self.restoreAttr[i].scrollTimer - dt
		end
	end
	
	if self.timers["restorecooldown"] > 0 then
		self.timers["restorecooldown"] = self.timers["restorecooldown"] - dt
	end

	if self.timers["warp"] > 0 then
		self.timers["warp"] = self.timers["warp"] - dt
	end

	if ((self.checks["fly"] == false) and (types.Actor.isOnGround(self.selfObj) == false)) or self.timers["freefall"] < 0 then
		self.timers["freefall"] = self.timers["freefall"] + dt
	elseif self.timers["freefall"] > 0 then -- A negative self.timers["freefall"] implies a slowfall potion is active and the timer should not be reset
		self.timers["freefall"] = 0
	end

	self:setSheatheWarpTimers(dt)
end
--

-- Gameplay functions -- Functions that modify follower's gameplay behavior
function Follower:setSneak() -- Make sure if the player is sneaking, follower sneaks as well
	if self.player ~= nil then
		self.player:sendEvent("getSneakVal", self.selfObj)
	end
	if (self.selfObj as OMW_SELF_PACKAGE).controls.sneak ~= self.checks["playerSneak"] then
		(self.selfObj as OMW_SELF_PACKAGE).controls.sneak = self.checks["playerSneak"]
	end
end

function Follower:makeCompanionFollow() -- Helper function for setting the Follow AI package
	ai.startPackage({
		type = "Follow",
		target = self.player
	})
end

function Follower:toggleEffect(flag: cmn.Flag, effectType: string) -- This function should apply the levitate effect to companion if the player is levitating, and remove it if the player isn't
	local playerEffect = types.Actor.activeEffects(self.player):getEffect(effectType, nil).magnitude
	if playerEffect > 0 and self.checks[flag] == false then
		types.Actor.activeEffects(self.selfObj):modify(playerEffect, effectType, nil)
		self.checks[flag] = true
	elseif playerEffect <= 0 and self.checks[flag] == true then
		local companionEffect = types.Actor.activeEffects(self.selfObj):getEffect(effectType, nil).magnitude
		types.Actor.activeEffects(self.selfObj):modify(-(companionEffect), effectType, nil)
		self.checks[flag] = false
	end
end

function Follower:castSpell(spell: core.Spell, castSound: string): number -- Applies the effect of the specified spell to the follower, including vfx and sound, and then consumes follower's magicka equal to the cost of the spell. 
	local duration: number = self.DEFAULT_CD.SPELL
	-- This should be the correct way to do this. However, it appears this event does not work properly, possibly a feature that's not present in openmw 0.50?
	-- selfObj:sendEvent('ModifyStat', {name = 'magicka', amount = -10}) -- Subtract the cost of the spell from the follower's current magicka
	self.attributes[2](self.selfObj).current = self.attributes[2](self.selfObj).current - spell.cost -- Subtract the cost of the spell from the follower's current magicka
	if false then
		return 0
	end
	types.Actor.activeSpells(self.selfObj):add({ -- Add the spell's effect to the follower's list of spell effect that are currently applied
		id = spell.id,
		effects = {0},
		name = spell.name,
		caster = self.selfObj,
	})
	for _, effect in pairs((spell.effects as {any: core.MagicEffectWithParams})) do -- For every effect provided by this spell, play an appropriate vfx and sound
		local vfx = effect.effect
		self.selfObj:sendEvent('AddVfx', {
        	model = types.Static.record(vfx.castStatic).model,
        	options = {
            	vfxId = "followerCast" .. effect.id,
            	particleTextureOverride = vfx.particle,
            	loop = false,
        	}
    	})
		--core.sound.playSound3d(vfx.castSound, selfObj, {}) -- Due to what appears to be a bug with the lua API, it's not actually possible to retrieve any sounds for our spell effect. For now the sound must be passed in as a string
		core.sound.playSound3d(castSound, self.selfObj, {})
		if duration < effect.duration then
			duration = effect.duration -- Get the longest duration of any of the effects supplied by this spell and use that as the duration of the spell itself
		end
	end
	return duration
end

function Follower:useEnchantment(itemRecord: cmn.EnchRecord, effectName: string, castSound: string): number -- Makes follower use the specified enchanted item, applying its magic effect and consuming some of the item's charge
	local item = types.Actor.inventory(self.selfObj):find(itemRecord.id)
	local enchantment = (core.magic.enchantments.records as {string: core.Enchantment})[itemRecord.enchant]
	local duration: number = self.DEFAULT_CD.SCROLL
	if effectName ~= nil then
		for _, effect in pairs((enchantment.effects as {any: core.MagicEffectWithParams})) do -- For every effect provided by this spell, play an appropriate vfx and sound
			local vfx = effect.effect
			self.selfObj:sendEvent('AddVfx', {
        		model = types.Static.record(vfx.castStatic).model,
        		options = {
            		vfxId = "followerCast" .. effect.id,
            		particleTextureOverride = vfx.particle,
            		loop = false,
        		}
    		})
			--core.sound.playSound3d(vfx.castSound, selfObj, {}) -- Due to what appears to be a bug with the lua API, it's not actually possible to retrieve any sounds for our spell effect. For now the sound must be passed in as a string
			core.sound.playSound3d(castSound, self.selfObj, {})
			if vfx.name == effectName then
				duration = effect.duration -- We only use the relevant magic effect's duration as our cooldown. Any side effects the enchantment might have aren't considered when deciding whether we can use another enchantment again or not
			end
		end
	end
	types.Actor.activeSpells(self.selfObj):add({
		id = itemRecord.id,
		effects = {0},
		name = itemRecord.name,
		caster = self.selfObj,
	})
	core.sendGlobalEvent("changeEnchCharge", {item, enchantment.cost}) -- Subtract the cost of the enchantment from the current charge of the enchanted item
	return duration
end

function Follower:consumePotion(potionID: string, effectName: string): number -- Sends a global event to trigger follower to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
	local potion = types.Actor.inventory(self.selfObj):find(potionID)
	local potionEffects = types.Potion.record(potion).effects
	local duration: number = self.DEFAULT_CD.POTION
	if effectName ~= nil then
		for i = 1, #potionEffects do
			if potionEffects[i].effect.name == effectName then
				duration = potionEffects[i].duration
				break
			end
		end
	end
	core.sendGlobalEvent("UseItem", {object = potion, actor = self.selfObj})
	return duration
end

function Follower:useScroll(scrollId: string, effectName: string, castSound: string): number -- Sends a global event to trigger follower to use the specified scroll. Returns the duration of whatever effect is specified, or 60 if the scroll does not have that effect
	local scroll = types.Actor.inventory(self.selfObj):find(scrollId)
	local scrollRecord = types.Book.record(scroll)
	local scrollEffects: {core.MagicEffectWithParams} = (core.magic.enchantments.records as {string: core.Enchantment})[scrollRecord.enchant].effects
	local duration: number = self.DEFAULT_CD.SCROLL
	if effectName ~= nil then
		for _, effect in pairs((scrollEffects as {any: core.MagicEffectWithParams})) do -- For every effect provided by this spell, play an appropriate vfx and sound
			local vfx = effect.effect
			self.selfObj:sendEvent('AddVfx', {
        		model = types.Static.record(vfx.castStatic).model,
        		options = {
            		vfxId = "followerCast" .. effect.id,
            		particleTextureOverride = vfx.particle,
            		loop = false,
        		}
    		})
			--core.sound.playSound3d(vfx.castSound, selfObj, {}) -- Due to what appears to be a bug with the lua API, it's not actually possible to retrieve any sounds for our spell effect. For now the sound must be passed in as a string
			core.sound.playSound3d(castSound, self.selfObj, {})
			if vfx.name == effectName then
				duration = effect.duration -- We only use the relevant magic effect's duration as our cooldown. Any side effects the enchantment might have aren't considered when deciding whether we can use another enchantment again or not
			end
		end
	end
	types.Actor.activeSpells(self.selfObj):add({
		id = scrollId,
		effects = {0},
		name = scrollRecord.name,
		caster = self.selfObj,
	})
	core.sendGlobalEvent('ConsumeItem', {item = scroll, amount = 1}) -- Since applying the scroll's effect does not actually consume the scroll, we need to do so by sending a global event
	--core.sendGlobalEvent("UseItem", {object = scroll, actor = selfObj}) -- This doesn't actually cast the scroll's spell or consume the scroll
	return duration
end

function Follower:selectRestoreEnch(effectId: string, attrDiff: number, itemType: cmn.EnchType): {cmn.EnchRecord, number} -- Scans through the follower's inventory, finding the enchanted item that has the most applicable restorative effect
	local inventory = types.Actor.inventory(self.selfObj)
	local selectedItem: cmn.EnchRecord
	local selectedHealQuality: number
	for _, item in pairs(inventory:getAll(itemType) as {any: cmn.EnchType}) do
		local itemRecord = (itemType.record(item) as cmn.EnchRecord)
		if itemRecord.enchant ~= nil then
			local enchant = (core.magic.enchantments.records as {string: core.Enchantment})[itemRecord.enchant]
			if enchant.type == core.magic.ENCHANTMENT_TYPE.CastOnUse then
				for _, effect in pairs(enchant.effects as {any: core.MagicEffectWithParams}) do
					if effect.id == effectId then
						local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration
						local healQuality = math.abs(attrDiff - magnitude)
						if (selectedItem == nil) or healQuality < selectedHealQuality then
							selectedItem = itemRecord
							selectedHealQuality = healQuality
						end
					end
				end
			end
		end
	end
	if selectedItem ~= nil and selectedHealQuality ~= nil then
		return {selectedItem, selectedHealQuality}
	else
		return nil
	end
end

function Follower:selectRestoreSpell(effectId: string, attrDiff: number): {core.Spell, number} -- Selects the best restorative spell the NPC currently has (prioritizes magnitude over cost). Prefers the spell that restores closest to the missing amount of whichever attribute is being restored rather than just the spell with the greatest magnitude, currently ignores all side effects of casting the spell. Returns nil if no spell is found
	local spells = types.Actor.spells(self.selfObj)
	local currentMagicka = self.attributes[2](self.selfObj).current
	local selectedSpell: core.Spell
	local selectedMagnitude: number
	local selectedHealQuality: number
	for _, spell in pairs((spells as {any: core.Spell})) do
		if spell.type == core.magic.SPELL_TYPE.Spell or (spell.type == core.magic.SPELL_TYPE.Power and types.Actor.activeSpells(self.selfObj):canUsePower(spell.id) == true) then -- Only use a spell or power, no abilities. Powers will only be cast if they are not currently on cooldown
			for _, effect in pairs((spell.effects as {any: core.MagicEffectWithParams})) do
				if effect.id == (effectId as string) and effect.range == core.magic.RANGE.Self then -- We only care if at least one of the effects of this spell restores our chosen attribute and works on self
					if spell.cost < currentMagicka then -- Only selects this spell if we can afford to cast it
						local costRatio = spell.cost / currentMagicka
						local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration -- Find the average magnitude of the given effect for this spell
						local healQuality = math.abs(attrDiff - magnitude) * (1 + costRatio)
						if (selectedSpell == nil) or healQuality < selectedHealQuality then
							selectedSpell = spell
							selectedMagnitude = magnitude
							selectedHealQuality = healQuality
						end
					end
				end
			end
		end
	end
	if selectedSpell ~= nil and selectedMagnitude ~= nil then
		return {selectedSpell, selectedHealQuality}
	else
		return nil
	end
end

function Follower:selectRestorePotion(effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
	local inventory = types.Actor.inventory(self.selfObj)
	local selectedPotion: types.PotionRecord
	local selectedMagnitude: number
	local selectedHealQuality: number
	for _, potion in pairs(inventory:getAll(types.Potion) as {any: types.Potion}) do
		local potionRecord = types.Potion.record(potion)
		for _, effect in pairs(potionRecord.effects as {any: core.MagicEffectWithParams}) do
			if effect.id == effectId then
				local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration -- Find the average magnitude of the given effect for this potion
				local healQuality = math.abs(attrDiff - magnitude)
				if (selectedPotion == nil) or healQuality < selectedHealQuality then
					selectedPotion = potionRecord
					selectedMagnitude = magnitude
					selectedHealQuality = healQuality
				end
			end
		end
	end
	if selectedPotion ~= nil and selectedMagnitude ~= nil and selectedHealQuality ~= nil
	and (((selectedMagnitude * self.WASTE_THRESHOLD.POTION) < attrDiff) -- Only select potion if less than 25% of its effect will be wasted
	or (attrDiff > (attrMax * self.ATTRIBUTE_PANIC_THRESHOLD))) -- However, if follower is missing more than 75% of their attribute, ignore the waste threshold
	then
		return {selectedPotion.id, selectedHealQuality}
	else
		return nil
	end
end

function Follower:selectRestoreScroll(effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find whichever scroll is enchanted with an effect that has the most suitable restore health/magicka/fatigue amount out of all scrolls in the follower's inventory
	local inventory = types.Actor.inventory(self.selfObj)
	local selectedScroll: types.BookRecord
	local selectedMagnitude: number
	local selectedHealQuality: number
	for _, scroll in pairs(inventory:getAll(types.Book) as {any: types.Book}) do
		local scrollRecord = types.Book.record(scroll)
		if scrollRecord.isScroll == true then
			local enchant: core.Enchantment = (core.magic.enchantments.records as {string: core.Enchantment})[scrollRecord.enchant]
			if enchant.type == core.magic.ENCHANTMENT_TYPE.CastOnce then -- As far as we're concerned here, scrolls should be one time use only. Ignore any that aren't.
				for _, effect in pairs(enchant.effects as {any: core.MagicEffectWithParams}) do
					if effect.id == effectId then
						local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration -- Find the average magnitude of the given effect for this scroll
						local healQuality = math.abs(attrDiff - magnitude)
						if (selectedScroll == nil) or healQuality < selectedHealQuality then
							selectedScroll = scrollRecord
							selectedMagnitude = magnitude
							selectedHealQuality = healQuality
						end
					end
				end
			end
		end
	end
	if selectedScroll ~= nil and selectedMagnitude ~= nil and selectedHealQuality ~= nil
	and (((selectedMagnitude * self.WASTE_THRESHOLD.SCROLL) < attrDiff) -- Only select potion if less than 25% of its effect will be wasted
	or (attrDiff > (attrMax * self.ATTRIBUTE_PANIC_THRESHOLD))) -- However, if follower is missing more than 75% of their attribute, ignore the waste threshold
	then
		return {selectedScroll.id, selectedHealQuality}
	else
		return nil
	end
end

function Follower:chooseRestoreMethod(iter: integer) -- Intelligently selects the most appropriate healing method to use when health is low based on what spells, potions, scrolls, and enchantments are available. As of OpenMW 0.50, scrolls and enchantments are not available due to API limitations
	local enum RESTORE_METHOD
	  	"encharmor"
		"enchclothing"
		"enchweapon"
	  	"spell"
	  	"potion"
	  	"scroll"
	end
	local interface RestoreMethod
	  	name: RESTORE_METHOD
	  	data: any
	  	weight: number -- How this particular restore method is weighted against others. The lower, the better. Calculated by finding the difference between the method's restore magnitude and the quantity of missing attribute
	end

	local methodAction: {RESTORE_METHOD: function} = {
	  	["encharmor"] = function(method: RestoreMethod) self.restoreAttr[iter].enchantmentTimer = self:useEnchantment((method.data as cmn.EnchRecord), self.restoreAttr[iter].effectName, "restoration cast") end,
	  	["enchclothing"] = function(method: RestoreMethod) self.restoreAttr[iter].enchantmentTimer = self:useEnchantment((method.data as cmn.EnchRecord), self.restoreAttr[iter].effectName, "restoration cast") end,
	  	["enchweapon"] = function(method: RestoreMethod) self.restoreAttr[iter].enchantmentTimer = self:useEnchantment((method.data as cmn.EnchRecord), self.restoreAttr[iter].effectName, "restoration cast") end,
	  	["spell"] = function(method: RestoreMethod) self.restoreAttr[iter].spellTimer = self:castSpell((method.data as core.Spell), "restoration cast") end,
	  	["potion"] = function(method: RestoreMethod) self.restoreAttr[iter].potionTimer = self:consumePotion((method.data as string), self.restoreAttr[iter].effectName) end,
	  	["scroll"] = function(method: RestoreMethod) self.restoreAttr[iter].scrollTimer = self:useScroll((method.data as string), self.restoreAttr[iter].effectName, "restoration cast") end,
	}
	local attrDiff = self:getAttrDiff(self.attributes[iter](self.selfObj))
	local restoreMethods: {RestoreMethod} = {}
	if self.restoreAttr[iter].enchantmentTimer <= 0 then
		local armor = self:selectRestoreEnch(self.restoreAttr[iter].effectId, attrDiff, types.Armor as cmn.EnchType)
		if armor ~= nil then
	  		table.insert(restoreMethods, {
	  	  		name = "encharmor",
				data = armor[1],
				weight = armor[2] + (self:getMaxAttr(self.attributes[iter](self.selfObj)) * self.RESTORE_WEIGHTS.ENCHANTMENT),
	  		})
		end
		local clothing = self:selectRestoreEnch(self.restoreAttr[iter].effectId, attrDiff, types.Clothing as cmn.EnchType)
		if clothing ~= nil then
		  	table.insert(restoreMethods, {
		  	  	name = "enchclothing",
				data = clothing[1],
				weight = clothing[2] + (self:getMaxAttr(self.attributes[iter](self.selfObj)) * self.RESTORE_WEIGHTS.ENCHANTMENT),
	  		})
		end
		local weapon = self:selectRestoreEnch(self.restoreAttr[iter].effectId, attrDiff, types.Weapon as cmn.EnchType)
	  	if weapon ~= nil then
			table.insert(restoreMethods, {
		  	  	name = "enchweapon",
				data = weapon[1],
				weight = weapon[2] + (self:getMaxAttr(self.attributes[iter](self.selfObj)) * self.RESTORE_WEIGHTS.ENCHANTMENT),
	  		})
		end
	end
	if self.restoreAttr[iter].spellTimer <= 0 and self.attributes[2](self.selfObj).current > 0 then
	  	local spell = self:selectRestoreSpell(self.restoreAttr[iter].effectId, attrDiff)
		if spell ~= nil then
	  		table.insert(restoreMethods, {
	  		  	name = "spell",
	  		  	data = spell[1],
	  		  	weight = spell[2] + (self:getMaxAttr(self.attributes[iter](self.selfObj)) * self.RESTORE_WEIGHTS.SPELL),
	  		})
		end
	end
	if self.restoreAttr[iter].potionTimer <= 0 then
	  	local potion = self:selectRestorePotion(self.restoreAttr[iter].effectId, attrDiff, self:getMaxAttr(self.attributes[iter](self.selfObj)))
		if potion ~= nil then
		  	table.insert(restoreMethods, {
		  	  	name = "potion",
	  		  	data = potion[1],
	  	  		weight = potion[2] + (self:getMaxAttr(self.attributes[iter](self.selfObj)) * self.RESTORE_WEIGHTS.POTION),
	  		})
		end
	end
	if self.restoreAttr[iter].scrollTimer <= 0 then
	  	local scroll = self:selectRestoreScroll(self.restoreAttr[iter].effectId, attrDiff, self:getMaxAttr(self.attributes[iter](self.selfObj)))
		if scroll ~= nil then
		  	table.insert(restoreMethods, {
		  	  	name = "scroll",
	  		  	data = scroll[1],
	  	  		weight = scroll[2] + (self:getMaxAttr(self.attributes[iter](self.selfObj)) * self.RESTORE_WEIGHTS.SCROLL),
	  		})
		end
	end
	if #restoreMethods == 0 then return end

	local method: RestoreMethod = restoreMethods[1]
	for i = 2, #restoreMethods do
	 	if method.weight >= restoreMethods[i].weight then
	  	  	method = restoreMethods[i]
  	  	end
	end
	methodAction[method.name](method)
	self.timers["restorecooldown"] = self.DEFAULT_CD.RESTORE
end

function Follower:checkAttributes() -- Used to call various functions that affect follower's dynamic attributes like health, fatigue, and magicka
	for i = 1, #self.attributes do
		if self:checkAttrDamaged(self.attributes[i](self.selfObj)) == true and self.timers["restorecooldown"] <= 0 then
			self:chooseRestoreMethod(i)
		end
	end
end

function Follower:freeFall() -- Used to call various functions that should trigger while follower is in freefall
	if self.timers["freefall"] > 1 and self:checkForPotion("p_slowfall_s") then
		self.timers["freefall"] = -(self:consumePotion("p_slowfall_s", "SlowFall"))
	end
end
--

-- Movement functions - Functions that modify follower's movement behavior
function Follower:forceZLevel() -- If in combat, levitating and the player Z level is different from follower's, force follower's Z level to the player's
	local playerPos: cmn.CellLoc = (self:getPlayerCellPos() as cmn.CellLoc)
	local followerPos = self.selfObj.position
	if self.checks["fly"] == true and types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Weapon then
		core.sendGlobalEvent("teleport", {
			actor = self.selfObj,
			cell = self.selfObj.cell.name,
			position = util.vector3(followerPos.x, followerPos.y, playerPos.cellPos.z)
		})
	end
end

function Follower:maintainDistance() -- Toggles follower between wandering and following the player in order to maintain a small window of distance from the player. Works only if the player activates it from dialogue by updating the "compmove" variable
	local followerPos = self.selfObj.position
	local playerPos: cmn.CellLoc = (self:getPlayerCellPos() as cmn.CellLoc)
	if playerPos == nil then
		return
	end
	if self:isFollowing() and self.MWVars["compmove"] == self.BOOL.TRUE and self.checks["cMove"] == false
	and self:getCoDist(followerPos, playerPos.cellPos) < self.DISTANCE_THRESHOLD.MAINTAIN_LOWER
	then
		ai.removePackages("Follow")
		ai.startPackage({
			type = "Wander",
			distance = self.DISTANCE_THRESHOLD.WANDER
		})
		self.checks["cMove"] = true
	end
	if self.checks["cMove"] == true and self:getCoDist(followerPos, playerPos.cellPos) > self.DISTANCE_THRESHOLD.MAINTAIN_UPPER then
		ai.removePackages("Wander")
		self:makeCompanionFollow()
		self.checks["cMove"] = false
	end
end

function Follower:nudge(timePassed: number) -- Waits 4 seconds before making companion follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make them move
	if self.MWVars["onetimemove"] == self.BOOL.TRUE then
		self.timers["move"] = self.timers["move"] + timePassed
		if self.timers["move"] >= self.NUDGE_DELAY then
			self.timers["move"] = 0
			self:makeCompanionFollow()
			self:updateMWVar("onetimemove", self.BOOL.FALSE)
		end
	end
end

function Follower:warpToPlayer() -- If the player gets too far from follower, teleport follower closer to the player
	self.posA = self:getPlayerCellPos()
	if self.posA == nil then return end
	
	if self.doOnce == false then
		self.posB = self:getPlayerCellPos()
		self.doOnce = true
	end
	
	local coDist = self:getCoDist((self.posA as cmn.CellLoc).cellPos, self.posB.cellPos)
	if coDist > 360 then self.doOnce = false end
	
	if (coDist > 180 and self.doOnce2 == false) or self.posC == nil then
		self.posC = self:getPlayerCellPos()
		self.doOnce2 = true
	end

	local coDist2 = self:getCoDist((self.posA as cmn.CellLoc).cellPos, (self.posC as cmn.CellLoc).cellPos)
	if coDist2 > 360 then self.doOnce2 = false end

	if self.timers["warp"] <= 0 and self:getCoDist(self.selfObj.position, (self:getPlayerCellPos() as cmn.CellLoc).cellPos) > 680 then
		if coDist > 350 then
			core.sendGlobalEvent("teleport", {
				actor = self.selfObj,
				cell = (self.posC as cmn.CellLoc).cellId,
				position = (self.posC as cmn.CellLoc).cellPos
			})
			self:makeCompanionFollow()
		elseif coDist2 > 350 then
			core.sendGlobalEvent("teleport", {
				actor = self.selfObj,
				cell = self.posB.cellId,
				position = self.posB.cellPos
			})
			self:makeCompanionFollow()
		end
	end
end

function Follower:setDefaultSpeed() -- Sets follower's speed modifier while not following the player
	types.Actor.stats.attributes.speed(self.selfObj).modifier = self.STAT_MOD.WANDER
end

function Follower:modSpeedAndAthletics() -- Set follower's speed and athletics modifier to a flat value if they're within a certain distance of the player, or add a multiplier based off the player's stats if they're too far
	local followerSpeed = types.Actor.stats.attributes.speed(self.selfObj)
	local followerAthletics = types.NPC.stats.skills.athletics(self.selfObj)
	local cSpeed = types.Actor.stats.attributes.speed(self.player).modified * self.STAT_MOD.CATCHUP_MULT
	local cAthletics = types.NPC.stats.skills.athletics(self.player).modified * self.STAT_MOD.CATCHUP_MULT
	if (followerSpeed.modifier ~= self.STAT_MOD.FOLLOW or followerAthletics.modifier ~= self.STAT_MOD.FOLLOW)
		and (self:getCoDist(self.selfObj.position, self:getPlayerCellPos().cellPos) <= self.DISTANCE_THRESHOLD.MOD_SPEED)
	then
		followerSpeed.modifier = self.STAT_MOD.FOLLOW
		followerAthletics.modifier = self.STAT_MOD.FOLLOW
	elseif (followerSpeed.modifier ~= cSpeed or followerAthletics.modifier ~= cAthletics)
		and (self:getCoDist(self.selfObj.position, self:getPlayerCellPos().cellPos) > self.DISTANCE_THRESHOLD.MOD_SPEED)
	then
		followerSpeed.modifier = cSpeed
		followerAthletics.modifier = cAthletics
	end
end
--

return function(child: {string: any}): Follower
	child.parent = defaultFollower();
	return setmetatable(child as Follower, { __index = child.parent })
end