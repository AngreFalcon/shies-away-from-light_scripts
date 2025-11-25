local types = require('openmw.types')
local core = require('openmw.core')
local time = require('openmw_aux.time')
local util = require('openmw.util')
local cmn = require('scripts.follower.common')

-- Credit to Grumpy and Kateri for their companion mwscripts, which were used as the foundation from which this script was built

local interface Follower is Follower.OMW_SELF
	metamethod __call: function(Follower, ...: DerivedFollower): DerivedFollower
    type DynamicStats = { function(core.GameObject): types.DynamicStat }
    interface STAT_MOD
        CATCHUP_MULT: number
        FOLLOW: number
        WANDER: number
	end
	interface DEFAULT_CD
		RESTORE: number
		ENCHANTMENT: number
		SPELL: number
		POTION: number
		SCROLL: number
		WARP: number
		SHEATHE: number
	end
	interface RESTORE_CONSTS
		TRIGGER_PERC: number
		PANIC_THRESHOLD: number
		ENCHANTMENT_WEIGHT: number
		SPELL_WEIGHT: number
		POTION_WEIGHT: number
		POTION_WASTE: number
		SCROLL_WEIGHT: number
		SCROLL_WASTE: number
	end
	interface DISTANCE_THRESHOLD
		MOD_SPEED: number
		MAINTAIN_LOWER: number
		MAINTAIN_UPPER: number
		WANDER: number
	end
	interface BOOL
		TRUE: integer
		FALSE: integer
	end
	interface OMW_SELF_CONTROLS
		sneak: boolean
		jump: boolean
	end
	interface OMW_SELF
		controls: OMW_SELF_CONTROLS
	end
	interface OMW_AI_PACKAGE
		type: string
		target: core.GameObject
		distance: number
	end
	interface OMW_AI
		getActiveTarget: function(string): core.GameObject
		getActivePackage: function(): OMW_AI_PACKAGE
		removePackages: function(string)
		startPackage: function(OMW_AI_PACKAGE)
	end

    selfObj: core.GameObject
    ai: OMW_AI
	controls: OMW_SELF_CONTROLS
	dynamicStats: DynamicStats
	statMod: STAT_MOD
	defaultCd: DEFAULT_CD
	restoreConsts: RESTORE_CONSTS
	distanceThreshold: DISTANCE_THRESHOLD
	mwBool: BOOL
	NUDGE_DELAY: number
	DELAY1: number
	DELAY2: number
	player: core.GameObject
    checks: {cmn.Flag: boolean}
    restoreDynStat: {cmn.RestoreDynStat}
	timers: {cmn.Timer: number}
    posA: cmn.CellLoc
    posB: cmn.CellLoc
    posC: cmn.CellLoc
    doOnce: boolean
    doOnce2: boolean
	MWVars: {string: number}
	
	delayUpdate1: function(self: Follower)
	delayUpdate2: function(self: Follower)
	onUpdate: function(self: Follower, dt: number)
	onSave: function(self: Follower, payload: {string: any}): cmn.SaveData
	onLoad: function(self: Follower, data: cmn.SaveData)
	updateMWVar: function(self: Follower, varName: string, varData: number)
	isFollowing: function(self: Follower): boolean
	getPlayerLeader: function(self: Follower)
	fullHeal: function(self: Follower)
	checkForPotion: function(self: Follower, potionName: string): boolean
	getPlayerCellPos: function(self: Follower): cmn.CellLoc
	setSheatheWarpTimers: function(self: Follower, dt: number)
	updateTimers: function(self: Follower, dt: number)
	setSneak: function(self: Follower)
	makeCompanionFollow: function(self: Follower)
	toggleEffect: function(self: Follower, flag: cmn.Flag, effectType: string)
	castSpell: function(self: Follower, spell: core.Spell, castSound: string): number
	useEnchantment: function(self: Follower, itemRecord: cmn.EnchRecord, effectName: string, castSound: string): number
	consumePotion: function(self: Follower, potionID: string, effectName: string): number
	useScroll: function(self: Follower, scrollId: string, effectName: string, castSound: string): number
	selectRestoreEnch: function(self: Follower, effectId: string, attrDiff: number, itemType: cmn.EnchType): {cmn.EnchRecord, number}
	selectRestoreSpell: function(self: Follower, effectId: string, attrDiff: number): {core.Spell, number}
	selectRestorePotion: function(self: Follower, effectId: string, attrDiff: number, attrMax: number): {string, number}
	selectRestoreScroll: function(self: Follower, effectId: string, attrDiff: number, attrMax: number): {string, number}
	chooseRestoreMethod: function(self: Follower, iter: integer)
	checkAttributes: function(self: Follower)
	freeFall: function(self: Follower)
	forceZLevel: function(self: Follower)
	maintainDistance: function(self: Follower)
	nudge: function(self: Follower, timePassed: number)
	warpToPlayer: function(self: Follower)
	setDefaultSpeed: function(self: Follower)
	modSpeedAndAthletics: function(self: Follower)
end

-- Handler functions - Functions that will be called directly by OpenMW
local function delayUpdate1(self: Follower) -- This function runs once every x seconds, where x = DELAY1
	if self:isFollowing() then
		self:modSpeedAndAthletics()
	elseif self.player ~= nil then
		self:setDefaultSpeed()
	end
end

local function delayUpdate2(self: Follower) -- This function runs once every x seconds, where x = DELAY2

end

local function onUpdate(self: Follower, dt: number)
	self:getPlayerLeader()
    self:checkAttributes()
	self:updateTimers(dt)
	if types.Actor.isOnGround(self.selfObj) == false and self.checks["fly"] == false then
		self:freeFall()
	end
	if self:isFollowing() then
		self:setSneak()
		self:toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate as string))
		self:toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking as string))
		self:forceZLevel()
		self:warpToPlayer()
	elseif self.player ~= nil then -- This condition should be reserved for function calls that take place when the follower is temporarily not following the player e.g., the follower has not been dismissed. Behaviors that occur when the follower has been dismissed should be placed outside of this condition block
		self:maintainDistance()
		self:nudge(dt)
	end
end

local function onSave(self: Follower, payload: {string: any}): cmn.SaveData
	for k, v in pairs(self.MWVars) do
		self:updateMWVar(k, v)
	end
	return cmn.merge(
		{
			player = self.player,
			doOnce = self.doOnce,
			doOnce2 = self.doOnce2,
			checks = self.checks,
			timers = self.timers,
			restoreAttr = self.restoreDynStat,
			posA = self.posA,
			posB = self.posB,
			posC = self.posC,
		},
		payload
	)
end

local function onLoad(self: Follower, data: cmn.SaveData)
		self.player = data.player
		self.doOnce = data.doOnce
		self.doOnce2 = data.doOnce2
		self.checks = data.checks
		self.timers = data.timers
		self.restoreDynStat = data.restoreDynStat
		self.posA = data.posA
		self.posB = data.posB
		self.posC = data.posC
end

-- Utility functions -- Functions that may return game values or that other functions may depend on for calculations or checks
local function updateMWVar(self: Follower, varName: string, varData: number) -- Send an event to the global script to update a single mwscript variable with the provided value
	core.sendGlobalEvent("updateMWVar", {varName, varData, self.selfObj})
end

local function isFollowing(self: Follower): boolean -- Simply return true or false if companion is currently following any player
	local currentPackage = self.ai.getActivePackage()
	return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

local function getPlayerLeader(self: Follower) -- Gets the player object that companion is currently following
	if self:isFollowing() then
		self.player = self.ai.getActiveTarget("Follow")
	end
end

local function fullHeal(self: Follower) -- Fully restore follower's health
	self.dynamicStats[1](self.selfObj).current = cmn.getMaxDynStat(self.dynamicStats[1](self.selfObj))
end

local function checkForPotion(self: Follower, potionName: string): boolean -- Returns true if follower has any of the specified potions in their inventory
	local inventory = types.Actor.inventory(self.selfObj)
	return inventory:countOf(potionName) > 0
end

local function getPlayerCellPos(self: Follower): cmn.CellLoc -- Get the cell location of the player that companion is currently following
	return {cellId = self.player.cell.name, cellPos = self.player.position}
end

local function setSheatheWarpTimers(self: Follower, dt: number) -- Sheathe weapon after combat check
	if self.checks["combat"] == true then
		self.timers["warp"] = self.defaultCd.WARP
		self.timers["sheathe"] = self.timers["sheathe"] - dt
		if core.sound.isSoundPlaying("Weapon Swish", self.selfObj) == true
			or core.sound.isSoundPlaying("crossbowShoot", self.selfObj) == true
			or core.sound.isSoundPlaying("bowShoot", self.selfObj) == true
			or core.sound.isSoundPlaying("mysticism cast", self.selfObj) == true
			or core.sound.isSoundPlaying("restoration cast", self.selfObj) == true
			or core.sound.isSoundPlaying("destruction cast", self.selfObj) == true
			or core.sound.isSoundPlaying("illusion cast", self.selfObj) == true
		then
			self.timers["sheathe"] = self.defaultCd.SHEATHE
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
		self.timers["warp"] = self.defaultCd.WARP
		self.timers["sheathe"] = self.defaultCd.SHEATHE
	end
end

local function updateTimers(self: Follower, dt: number) -- This function updates our various timers by dt, the time passed since this script's last executions
	for i = 1, #self.restoreDynStat do
		if self.restoreDynStat[i].spellTimer > 0 then
			self.restoreDynStat[i].spellTimer = self.restoreDynStat[i].spellTimer - dt
		end
		if self.restoreDynStat[i].enchantmentTimer > 0 then
			self.restoreDynStat[i].enchantmentTimer = self.restoreDynStat[i].enchantmentTimer - dt
		end
		if self.restoreDynStat[i].potionTimer > 0 then
			self.restoreDynStat[i].potionTimer = self.restoreDynStat[i].potionTimer - dt
		end
		if self.restoreDynStat[i].scrollTimer > 0 then
			self.restoreDynStat[i].scrollTimer = self.restoreDynStat[i].scrollTimer - dt
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
local function setSneak(self: Follower) -- Make sure if the player is sneaking, follower sneaks as well
	if self.player ~= nil then
		self.player:sendEvent("getSneakVal", self.selfObj)
	end
	if self.controls.sneak ~= self.checks["playerSneak"] then
		self.controls.sneak = self.checks["playerSneak"]
	end
end

local function makeCompanionFollow(self: Follower) -- Helper function for setting the Follow AI package
	self.ai.startPackage({
		type = "Follow",
		target = self.player
	})
end

local function toggleEffect(self: Follower, flag: cmn.Flag, effectType: string) -- This function should apply the levitate effect to companion if the player is levitating, and remove it if the player isn't
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

local function freeFall(self: Follower) -- Used to call various functions that should trigger while follower is in freefall
	if self.timers["freefall"] > 1 and self:checkForPotion("p_slowfall_s") then
		self.timers["freefall"] = -(self:consumePotion("p_slowfall_s", "SlowFall"))
	end
end
	-- Restore dynamic stat logic

local function castSpell(self: Follower, spell: core.Spell, castSound: string): number -- Applies the effect of the specified spell to the follower, including vfx and sound, and then consumes follower's magicka equal to the cost of the spell. 
	local duration: number = self.defaultCd.SPELL
	-- This should be the correct way to do this. However, it appears this event does not work properly, possibly a feature that's not present in openmw 0.50?
	-- selfObj:sendEvent('ModifyStat', {name = 'magicka', amount = -10}) -- Subtract the cost of the spell from the follower's current magicka
	self.dynamicStats[2](self.selfObj).current = self.dynamicStats[2](self.selfObj).current - spell.cost -- Subtract the cost of the spell from the follower's current magicka
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

local function useEnchantment(self: Follower, itemRecord: cmn.EnchRecord, effectName: string, castSound: string): number -- Makes follower use the specified enchanted item, applying its magic effect and consuming some of the item's charge
	local item = types.Actor.inventory(self.selfObj):find(itemRecord.id)
	local enchantment = (core.magic.enchantments.records as {string: core.Enchantment})[itemRecord.enchant]
	local duration: number = self.defaultCd.SCROLL
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

local function consumePotion(self: Follower, potionID: string, effectName: string): number -- Sends a global event to trigger follower to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
	local potion = types.Actor.inventory(self.selfObj):find(potionID)
	local potionEffects = types.Potion.record(potion).effects
	local duration: number = self.defaultCd.POTION
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

local function useScroll(self: Follower, scrollId: string, effectName: string, castSound: string): number -- Sends a global event to trigger follower to use the specified scroll. Returns the duration of whatever effect is specified, or 60 if the scroll does not have that effect
	local scroll = types.Actor.inventory(self.selfObj):find(scrollId)
	local scrollRecord = types.Book.record(scroll)
	local scrollEffects: {core.MagicEffectWithParams} = (core.magic.enchantments.records as {string: core.Enchantment})[scrollRecord.enchant].effects
	local duration: number = self.defaultCd.SCROLL
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

local function selectRestoreEnch(self: Follower, effectId: string, attrDiff: number, itemType: cmn.EnchType): {cmn.EnchRecord, number} -- Scans through the follower's inventory, finding the enchanted item that has the most applicable restorative effect
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

local function selectRestoreSpell(self: Follower, effectId: string, attrDiff: number): {core.Spell, number} -- Selects the best restorative spell the NPC currently has (prioritizes magnitude over cost). Prefers the spell that restores closest to the missing amount of whichever attribute is being restored rather than just the spell with the greatest magnitude, currently ignores all side effects of casting the spell. Returns nil if no spell is found
	local spells = types.Actor.spells(self.selfObj)
	local currentMagicka = self.dynamicStats[2](self.selfObj).current
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

local function selectRestorePotion(self: Follower, effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
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
	and (((selectedMagnitude * self.restoreConsts.POTION_WASTE) < attrDiff) -- Only select potion if less than 25% of its effect will be wasted
	or (attrDiff > (attrMax * self.restoreConsts.PANIC_THRESHOLD))) -- However, if follower is missing more than 75% of their attribute, ignore the waste threshold
	then
		return {selectedPotion.id, selectedHealQuality}
	else
		return nil
	end
end

local function selectRestoreScroll(self: Follower, effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find whichever scroll is enchanted with an effect that has the most suitable restore health/magicka/fatigue amount out of all scrolls in the follower's inventory
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
	and (((selectedMagnitude * self.restoreConsts.SCROLL_WASTE) < attrDiff) -- Only select potion if less than 25% of its effect will be wasted
	or (attrDiff > (attrMax * self.restoreConsts.PANIC_THRESHOLD))) -- However, if follower is missing more than 75% of their attribute, ignore the waste threshold
	then
		return {selectedScroll.id, selectedHealQuality}
	else
		return nil
	end
end

local function chooseRestoreMethod(self: Follower, iter: integer) -- Intelligently selects the most appropriate healing method to use when health is low based on what spells, potions, scrolls, and enchantments are available. As of OpenMW 0.50, scrolls and enchantments are not available due to API limitations
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
		["encharmor"] = function(method: RestoreMethod) self.restoreDynStat[iter].enchantmentTimer = self:useEnchantment((method.data as cmn.EnchRecord), self.restoreDynStat[iter].effectName, "restoration cast") end,
		["enchclothing"] = function(method: RestoreMethod) self.restoreDynStat[iter].enchantmentTimer = self:useEnchantment((method.data as cmn.EnchRecord), self.restoreDynStat[iter].effectName, "restoration cast") end,
		["enchweapon"] = function(method: RestoreMethod) self.restoreDynStat[iter].enchantmentTimer = self:useEnchantment((method.data as cmn.EnchRecord), self.restoreDynStat[iter].effectName, "restoration cast") end,
		["spell"] = function(method: RestoreMethod) self.restoreDynStat[iter].spellTimer = self:castSpell((method.data as core.Spell), "restoration cast") end,
		["potion"] = function(method: RestoreMethod) self.restoreDynStat[iter].potionTimer = self:consumePotion((method.data as string), self.restoreDynStat[iter].effectName) end,
		["scroll"] = function(method: RestoreMethod) self.restoreDynStat[iter].scrollTimer = self:useScroll((method.data as string), self.restoreDynStat[iter].effectName, "restoration cast") end,
	}
	local attrDiff = cmn.getDynStatDiff(self.dynamicStats[iter](self.selfObj))
	local restoreMethods: {RestoreMethod} = {}
	if self.restoreDynStat[iter].enchantmentTimer <= 0 then
		local armor = self:selectRestoreEnch(self.restoreDynStat[iter].effectId, attrDiff, types.Armor as cmn.EnchType)
		if armor ~= nil then
			table.insert(restoreMethods, {
				name = "encharmor",
				data = armor[1],
				weight = armor[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.ENCHANTMENT_WEIGHT),
			})
		end
		local clothing = self:selectRestoreEnch(self.restoreDynStat[iter].effectId, attrDiff, types.Clothing as cmn.EnchType)
		if clothing ~= nil then
			table.insert(restoreMethods, {
				name = "enchclothing",
				data = clothing[1],
				weight = clothing[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.ENCHANTMENT_WEIGHT),
			})
		end
		local weapon = self:selectRestoreEnch(self.restoreDynStat[iter].effectId, attrDiff, types.Weapon as cmn.EnchType)
		if weapon ~= nil then
			table.insert(restoreMethods, {
				name = "enchweapon",
				data = weapon[1],
				weight = weapon[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.ENCHANTMENT_WEIGHT),
			})
		end
	end
	if self.restoreDynStat[iter].spellTimer <= 0 and self.dynamicStats[2](self.selfObj).current > 0 then
		local spell = self:selectRestoreSpell(self.restoreDynStat[iter].effectId, attrDiff)
		if spell ~= nil then
			table.insert(restoreMethods, {
				name = "spell",
				data = spell[1],
				weight = spell[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.SPELL_WEIGHT),
			})
		end
	end
	if self.restoreDynStat[iter].potionTimer <= 0 then
		local potion = self:selectRestorePotion(self.restoreDynStat[iter].effectId, attrDiff, cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)))
		if potion ~= nil then
			table.insert(restoreMethods, {
				name = "potion",
				data = potion[1],
				weight = potion[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.POTION_WEIGHT),
			})
		end
	end
	if self.restoreDynStat[iter].scrollTimer <= 0 then
		local scroll = self:selectRestoreScroll(self.restoreDynStat[iter].effectId, attrDiff, cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)))
		if scroll ~= nil then
			table.insert(restoreMethods, {
				name = "scroll",
				data = scroll[1],
				weight = scroll[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.SCROLL_WEIGHT),
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
	self.timers["restorecooldown"] = self.defaultCd.RESTORE
end

local function checkAttributes(self: Follower) -- Used to call various functions that affect follower's dynamic attributes like health, fatigue, and magicka
	for i = 1, #self.dynamicStats do
		if cmn.getDynStatMissingPerc(self.dynamicStats[i](self.selfObj)) <= self.restoreConsts.TRIGGER_PERC and self.timers["restorecooldown"] <= 0 then
			self:chooseRestoreMethod(i)
		end
	end
end
--

-- Movement functions - Functions that modify follower's movement behavior
local function forceZLevel(self: Follower) -- If in combat, levitating and the player Z level is different from follower's, force follower's Z level to the player's
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

local function maintainDistance(self: Follower) -- Toggles follower between wandering and following the player in order to maintain a small window of distance from the player. Works only if the player activates it from dialogue by updating the "compmove" variable
	local followerPos = self.selfObj.position
	local playerPos: cmn.CellLoc = (self:getPlayerCellPos() as cmn.CellLoc)
	if playerPos == nil then
		return
	end
	if self:isFollowing() and self.MWVars["compmove"] == self.mwBool.TRUE and self.checks["cMove"] == false
	and cmn.getCoDist(followerPos, playerPos.cellPos) < self.distanceThreshold.MAINTAIN_LOWER
	then
		self.ai.removePackages("Follow")
		self.ai.startPackage({
			type = "Wander",
			distance = self.distanceThreshold.WANDER
		})
		self.checks["cMove"] = true
	end
	if self.checks["cMove"] == true and cmn.getCoDist(followerPos, playerPos.cellPos) > self.distanceThreshold.MAINTAIN_UPPER then
		self.ai.removePackages("Wander")
		self:makeCompanionFollow()
		self.checks["cMove"] = false
	end
end

local function nudge(self: Follower, timePassed: number) -- Waits 4 seconds before making companion follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make them move
	if self.MWVars["onetimemove"] == self.mwBool.TRUE then
		self.timers["move"] = self.timers["move"] + timePassed
		if self.timers["move"] >= self.NUDGE_DELAY then
			self.timers["move"] = 0
			self:makeCompanionFollow()
			self:updateMWVar("onetimemove", self.mwBool.FALSE)
		end
	end
end

local function warpToPlayer(self: Follower) -- If the player gets too far from follower, teleport follower closer to the player
	self.posA = self:getPlayerCellPos()
	if self.posA == nil then return end
	if self.doOnce == false then
		self.posB = self:getPlayerCellPos()
		self.doOnce = true
	end
	local coDist = cmn.getCoDist((self.posA as cmn.CellLoc).cellPos, self.posB.cellPos)
	if coDist > 360 then self.doOnce = false end
	if (coDist > 180 and self.doOnce2 == false) or self.posC == nil then
		self.posC = self:getPlayerCellPos()
		self.doOnce2 = true
	end
	local coDist2 = cmn.getCoDist((self.posA as cmn.CellLoc).cellPos, (self.posC as cmn.CellLoc).cellPos)
	if coDist2 > 360 then self.doOnce2 = false end
	if self.timers["warp"] <= 0 and cmn.getCoDist(self.selfObj.position, (self:getPlayerCellPos() as cmn.CellLoc).cellPos) > 680 then
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

local function setDefaultSpeed(self: Follower) -- Sets follower's speed modifier while not following the player
	types.Actor.stats.attributes.speed(self.selfObj).modifier = self.statMod.WANDER
end

local function modSpeedAndAthletics(self: Follower) -- Set follower's speed and athletics modifier to a flat value if they're within a certain distance of the player, or add a multiplier based off the player's stats if they're too far
	local followerSpeed = types.Actor.stats.attributes.speed(self.selfObj)
	local followerAthletics = types.NPC.stats.skills.athletics(self.selfObj)
	local cSpeed = types.Actor.stats.attributes.speed(self.player).modified * self.statMod.CATCHUP_MULT
	local cAthletics = types.NPC.stats.skills.athletics(self.player).modified * self.statMod.CATCHUP_MULT
	if (followerSpeed.modifier ~= self.statMod.FOLLOW or followerAthletics.modifier ~= self.statMod.FOLLOW)
		and (cmn.getCoDist(self.selfObj.position, self:getPlayerCellPos().cellPos) <= self.distanceThreshold.MOD_SPEED)
	then
		followerSpeed.modifier = self.statMod.FOLLOW
		followerAthletics.modifier = self.statMod.FOLLOW
	elseif (followerSpeed.modifier ~= cSpeed or followerAthletics.modifier ~= cAthletics)
		and (cmn.getCoDist(self.selfObj.position, self:getPlayerCellPos().cellPos) > self.distanceThreshold.MOD_SPEED)
	then
		followerSpeed.modifier = cSpeed
		followerAthletics.modifier = cAthletics
	end
end
--

-- 
local function defaultFollower(): Follower
	return {
		-- Aliases
	    selfObj = nil,
	    dynamicStats = {types.Actor.stats.dynamic.health, types.Actor.stats.dynamic.magicka, types.Actor.stats.dynamic.fatigue},
	    ai = nil,
		
	    -- Constants
	    --SKILL_LEVEL_MULT <const> = 1.5 -- The multiplier to apply to all skill increases
	    statMod = {
	        CATCHUP_MULT = 2.25, -- Multiplier that is applied to the player's athletics and speed, the product of which is then added to the follower's athletics and speed as a modifier
	        FOLLOW = 15, -- Flat modifier to be applied to follower's speed and athletics when normally following the player
	        WANDER = 40, -- Flat modifier to be applies to follower's speed when wandering instead of followings
	    },
		defaultCd = { -- Default cooldowns in seconds
			RESTORE = 10, -- The general cooldown to wait before using any other restore effects, regardless of individual method cooldown
			ENCHANTMENT = 10, -- The default cooldown for a restorative enchantment if the actual duration couldn't be found
			SPELL = 10, -- The default cooldown for a restorative spell if the actual duration couldn't be found
			POTION = 60, -- The default cooldown for a restorative potion if the actual duration couldn't be found
			SCROLL = 60, -- The default cooldown for a restorative scroll if the actual duration couldn't be found
			WARP = 6, -- Default value for the warp timer
			SHEATHE = 4.4, -- Default value for the sheathe timer
		},
		restoreConsts = {
			TRIGGER_PERC = 0.15, -- What percentage of the dynamic stat must be missing before a restore method is triggered
			PANIC_THRESHOLD = 0.75, -- The percentage missing from an attribute before follower should ignore the waste threshold and consume a restorative consumable anyway. At 0.75, if follower is missing more than 75% health, follower will use a restore health consumable whether its effect would be considered wasted or not
			ENCHANTMENT_WEIGHT = 0.75, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
			SPELL_WEIGHT = 1, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
			POTION_WEIGHT = 1.25, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
			POTION_WASTE = 0.25, -- At 0.25, if follower is only missing 25 health or less, a restorative effect with magnitude greater than 100 would be considered wasted
			SCROLL_WEIGHT = 1.5, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
			SCROLL_WASTE = 0.50, -- At 0.50, if follower is only missing 50 health or less, a restorative effect with magnitude greater than 100 would be considered wasted
		},
		distanceThreshold = {
			MOD_SPEED = 300, -- The distance threshold that determines whether follower moves at normal speed or speeds up to catch up with the player
			MAINTAIN_LOWER = 70, -- The lower distance threshold that forces follower to wander away from the player
			MAINTAIN_UPPER = 100, -- The upper distance threshold that makes companion follow the player again after moving away
			WANDER = 300, -- The distance parameter for follower's wander package when maintaining their distance
		},
		mwBool = { -- MWScript does not have boolean types, so all MWVars are numbers even if they're being used as boolean flags
			TRUE = 1,
			FALSE = 0,
		},
		NUDGE_DELAY = 4, -- The number of seconds follower should wander after being nudged before following the player again
		DELAY1 = 0.5 * time.second, -- The number of seconds to wait before executing our delayed, non-priority functions
		DELAY2 = 5 * time.second, -- The number of seconds to wait before executing our delayed, non-priority functions
	
		-- Variables
	    player = nil,
	    checks = {
			["cMove"] = false,
			["fly"] = false,
			["ww"] = false,
			["combat"] = false,
			["incapacitated"] = false,
			["playerSneak"] = false,
		},
	    restoreDynStat = {
			[1] = {
				potionTimer = 0,
				spellTimer = 0,
				scrollTimer = 0,
				enchantmentTimer = 0,
				effectName = "Restore Health",
				effectId = "restorehealth",
			},
			[2] = {
				potionTimer = 0,
				spellTimer = 0,
				scrollTimer = 0,
				enchantmentTimer = 0,
				effectName = "Restore Magicka",
				effectId = "restoremagicka",
			},
			[3] = {
				potionTimer = 0,
				spellTimer = 0,
				scrollTimer = 0,
				enchantmentTimer = 0,
				effectName = "Restore Fatigue",
				effectId = "restorefatigue",
			}
		},
	    timers = {
			["move"] = 0,
			["sheathe"] = 0,
			["warp"] = 0,
			["freefall"] = 0,
			["restorecooldown"] = 0,
		},
	
		-- Warp function variables - Must persist between function calls
	    posA = nil,
	    posB = nil,
	    posC = nil,
	    doOnce = false,
	    doOnce2 = false,
	
		-- MWScript variables
		-- Important to note: all MWScript variables are automatically cast to all lowercase
		-- If making a follower that uses this script, the follower must have the following variables declared in MWScript within their .esp plugin file
		MWVars = {},
		--[[ MWVars:
			short companion -- Engine variable -- True if follower is currently following the player. If 0, companion dialogue topics don't appear
			short nohello -- Engine variable -- 
			short nolore -- Engine variable --
			short compmove -- True if the player has asked follower to maintain their distance
			short onetimemove -- True if the player has asked follower to move out of the way
			short weapuse -- True if the player has asked follower to use the same weapons as the player
			short addonce -- True after the mwscript has executed once, is used to initialize companion to 0
		]]
		
		-- Handler functions - Functions that will be called directly by OpenMW
		delayUpdate1 = delayUpdate1,
		delayUpdate2 = delayUpdate2,
		onUpdate = onUpdate,
		onSave = onSave,
		onLoad = onLoad,
		-- Utility functions -- Functions that may return game values or that other functions may depend on for calculations or checks
		updateMWVar = updateMWVar, -- Send an event to the global script to update a single mwscript variable with the provided value
		isFollowing = isFollowing, -- Simply return true or false if companion is currently following any player
		getPlayerLeader = getPlayerLeader, -- Gets the player object that companion is currently following		
		fullHeal = fullHeal, -- Fully restore follower's health		
		checkForPotion = checkForPotion, -- Returns true if follower has any of the specified potions in their inventory
		getPlayerCellPos = getPlayerCellPos, -- Get the cell location of the player that companion is currently following
		setSheatheWarpTimers = setSheatheWarpTimers, -- Sheathe weapon after combat check
		updateTimers = updateTimers, -- This function updates our various timers by dt, the time passed since this script's last executions
		-- Gameplay functions -- Functions that modify follower's gameplay behavior
		setSneak = setSneak, -- Make sure if the player is sneaking, follower sneaks as well
		makeCompanionFollow = makeCompanionFollow, -- Helper function for setting the Follow AI package
		toggleEffect = toggleEffect, -- This function should apply the levitate effect to companion if the player is levitating, and remove it if the player isn't
		castSpell = castSpell, -- Applies the effect of the specified spell to the follower, including vfx and sound, and then consumes follower's magicka equal to the cost of the spell. 
		useEnchantment = useEnchantment, -- Makes follower use the specified enchanted item, applying its magic effect and consuming some of the item's charge
		consumePotion = consumePotion, -- Sends a global event to trigger follower to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
		useScroll = useScroll, -- Sends a global event to trigger follower to use the specified scroll. Returns the duration of whatever effect is specified, or 60 if the scroll does not have that effect
		selectRestoreEnch = selectRestoreEnch, -- Scans through the follower's inventory, finding the enchanted item that has the most applicable restorative effect
		selectRestoreSpell = selectRestoreSpell, -- Selects the best restorative spell the NPC currently has (prioritizes magnitude over cost). Prefers the spell that restores closest to the missing amount of whichever attribute is being restored rather than just the spell with the greatest magnitude, currently ignores all side effects of casting the spell. Returns nil if no spell is found
		selectRestorePotion = selectRestorePotion, -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
		selectRestoreScroll = selectRestoreScroll, -- Find whichever scroll is enchanted with an effect that has the most suitable restore health/magicka/fatigue amount out of all scrolls in the follower's inventory
		chooseRestoreMethod = chooseRestoreMethod, -- Intelligently selects the most appropriate healing method to use when health is low based on what spells, potions, scrolls, and enchantments are available. As of OpenMW 0.50, scrolls and enchantments are not available due to API limitations
		checkAttributes = checkAttributes, -- Used to call various functions that affect follower's dynamic attributes like health, fatigue, and magicka
		freeFall = freeFall, -- Used to call various functions that should trigger while follower is in freefall
		-- Movement functions - Functions that modify follower's movement behavior
		forceZLevel = forceZLevel, -- If in combat, levitating and the player Z level is different from follower's, force follower's Z level to the player's
		maintainDistance = maintainDistance, -- Toggles follower between wandering and following the player in order to maintain a small window of distance from the player. Works only if the player activates it from dialogue by updating the "compmove" variable
		nudge = nudge, -- Waits 4 seconds before making companion follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make them move
		warpToPlayer = warpToPlayer, -- If the player gets too far from follower, teleport follower closer to the player
		setDefaultSpeed = setDefaultSpeed, -- Sets follower's speed modifier while not following the player
		modSpeedAndAthletics = modSpeedAndAthletics, -- Set follower's speed and athletics modifier to a flat value if they're within a certain distance of the player, or add a multiplier based off the player's stats if they're too far
	}
end

local interface DerivedFollower is Follower
	base: Follower
	self: Follower.OMW_SELF
end

local function constructor(_: Follower, child: DerivedFollower): DerivedFollower
	child.base = defaultFollower()
	return setmetatable(child,
		{ __index = setmetatable(child.base,
			{ __index = {
				selfObj = child.self,
				controls = child.self.controls
			}})
		})
end

return setmetatable({} as Follower, { __call = constructor })