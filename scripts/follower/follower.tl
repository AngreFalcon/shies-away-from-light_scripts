local types = require('openmw.types')
local core = require('openmw.core')
local time = require('openmw_aux.time')
local util = require('openmw.util')
local cmn = require('scripts.follower.common')

-- Credit to Grumpy and Kateri for their companion mwscripts, which were used as the foundation from which this script was built

local interface Follower is Follower.OMW_SELF
	metamethod __call: function(Follower, ...: DerivedFollower): DerivedFollower
    type DynamicStats = { function(core.GameObject): types.DynamicStat }
	interface FEATURES
		REST_DYN_STATS: boolean
		REST_ENCHANT_USE: boolean
		REST_SPELL_USE: boolean
		REST_POTION_USE: boolean
		REST_SCROLL_USE: boolean
		RAPP_EN: boolean
		RAPP_RACE: boolean
		RAPP_SEX: boolean
		RAPP_GUILDS: boolean
		RAPP_DISP: boolean
	end
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
	interface FOLLOWER_PREFS
		RACE: {string: number}
		SEX: {boolean: number}
		GUILDS: {string: number}
	end
	interface RAPPORT_MODS
		BASE: number
		DISP_MOD: number
		DISP_DIV: number
		EXPELLED_MOD: number
		MAX: number
		MIN: number
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
	player: core.GameObject
    ai: OMW_AI
	mwBool: BOOL
	controls: OMW_SELF_CONTROLS
	dynamicStats: DynamicStats
	
	RAPPORT_GROWTH_THRESHOLD: number
	NUDGE_DELAY: number
	DELAY1: number
	DELAY2: number
	DELAY3 : number
	features: FEATURES
	defaultCd: DEFAULT_CD
	statMod: STAT_MOD
	restoreConsts: RESTORE_CONSTS
	distanceThreshold: DISTANCE_THRESHOLD
	followerPrefs: FOLLOWER_PREFS
	rapportMods: RAPPORT_MODS

	rapportCounter: number
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
	delayUpdate3: function(self: Follower)
	onUpdate: function(self: Follower, dt: number)
	onSave: function(self: Follower, payload: {string: any}): cmn.SaveData
	onLoad: function(self: Follower, data: cmn.SaveData)
	onActivated: function(self: Follower, actor: types.Actor)
	updateMWVars: function(self: Follower, data: {string: number})
	isFollowing: function(self: Follower): boolean
	getPlayerLeader: function(self: Follower)
	fullHeal: function(self: Follower)
	checkForPotion: function(self: Follower, potionName: string): boolean
	getPlayerCellPos: function(self: Follower): cmn.CellLoc
	setSheatheWarpTimers: function(self: Follower, dt: number)
	updateTimers: function(self: Follower, dt: number)
	resetDialogueVars: function(self: Follower)
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
	checkDynStats: function(self: Follower)
	freeFall: function(self: Follower)
	incrementRapport: function(self: Follower)
	checkRapportGrowth: function(self: Follower)
	forceZLevel: function(self: Follower)
	maintainDistance: function(self: Follower)
	nudge: function(self: Follower, timePassed: number)
	warpToPlayer: function(self: Follower)
	setDefaultSpeed: function(self: Follower)
	modSpeedAndAthletics: function(self: Follower)
end

-- Constant Definitions
local Delay1 <const>: number = 0.5 * time.second -- The number of seconds to wait before executing our delayed, non-priority functions
local Delay2 <const>: number = 10 * time.second -- The number of seconds to wait before executing our delayed, non-priority functions
--local SkillLevelGainMultiplier <const> = 1.5 -- The multiplier to apply to all skill increases
-- Feature enable flags
local FeatureFlags <const> = {
	RestoreDynStats = { -- Dynamic stat restoration flags used to enable or disable mechanics
		Enable: boolean = true, -- If true, will use one of the following methods to restore dynamic stats
		Enchant: boolean = true, -- If true, will use enchantments to restore dynamic stats
		Spell: boolean = true, -- If true, will use spells to restore dynamic stats
		Potion: boolean = true, -- If true, will use potions to restore dynamic stats
		Scroll: boolean = true, -- If true, will use scrolls to restore dynamic stats
	},
	Rapport = {
		Enable: boolean = true, -- If true, rapport mechanic will be used
		Race: boolean = true, -- If true, player's race will be taken into account when calculating rapport growth
		Sex: boolean = true, -- If true, player's sex will be taken into account when calculating rapport growth
		Guilds: boolean = true, -- If true, player's guilds will be taken into account when calculating rapport growth
		Disp: boolean = true, -- If true, player's disposition will be taken into account when calculating rapport growth
	},
}
local Rapport <const> = {
	Preferences = {
		Race = { -- The race this follower prefers, if any. If the player's race matches this value, the player's rapport with this follower will grow faster and decrease slower by the associated value
			["argonian"] = 0.005,
			["khajiit"] = 0.002,
		},
		Sex = { -- The sex this follower prefers, if any (true for male, false for female). If the player's sex matches this value, the player's rapport with this follower will grow faster and decrease slower by the associated value
			[true] = 0.005,
		},
		Guilds = { -- For each of these guilds the player belongs to, their rapport with this follower will grow faster and decrease slower by the associated value. This value is further modified by being multiplied by the player's rank in the guild, so smaller values are recommended
			["morag tong"] = 0.002,
			["mages guild"] = 0.003,
			["telvanni"] = 0.003,
		}
	},
	BaseModifier: number = 0.01, -- The value that will be used to increase the player's rapport growth every Delay3 seconds
	DispModifier: number = 80, -- This modifier is subtracted from the player's current disposition with the follower
	DispDivisor: number = 10000, -- This value is used to divide the player's modified disposition to then be applied to the player's rapport growth. For instance, with a default modifier value of 80 and default divisor of 10000, at 0 disposition, the player's rapport growth with the follower will be modified by -0.008. At a max disposition of 100, rapport growth would be modified by +0.002
	ExpelledModifier: number = -10, -- This multiplier is applied to the rapport modifier of the guild that the player is expelled from, and the product is applied to the player's rapport growth
	GrowthThreshold: number = 1, -- This is the required value the player's rapport growth must reach before their rapport with the follower increases
	Min: number = -1000, -- The minimum rapport the player can attain with this follower
	Max: number = 1000, -- The maximum rapport the player can attain with this follower
}
local Restore <const> = {
	CDs = {
		General: number = 10, -- The general cooldown to wait before using any other restore effects, regardless of individual method cooldown
		Enchantment: number = 10, -- The default cooldown for a restorative enchantment if the actual duration couldn't be found
		Spell: number = 10, -- The default cooldown for a restorative spell if the actual duration couldn't be found
		Potion: number = 60, -- The default cooldown for a restorative potion if the actual duration couldn't be found
		Scroll: number = 60, -- The default cooldown for a restorative scroll if the actual duration couldn't be found
	},
	Thresholds = {
		Trigger: number = 0.15, -- What percentage of the dynamic stat must be missing before a restore method is triggered
		Panic: number = 0.75, -- The percentage missing from an attribute before follower should ignore the waste threshold and consume a restorative consumable anyway. At 0.75, if follower is missing more than 75% health, follower will use a restore health consumable whether its effect would be considered wasted or not
		PotionWaste: number = 0.25, -- At 0.25, if follower is only missing 25 health or less, a restorative effect with magnitude greater than 100 would be considered wasted
		ScrollWaste: number = 0.50, -- At 0.50, if follower is only missing 50 health or less, a restorative effect with magnitude greater than 100 would be considered wasted
	},
	Weights = {
		Enchantment: number = 0.75, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
		Spell: number = 1, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
		Potion: number = 1.25, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
		Scroll: number = 1.5, -- Multiplier to be applied to each restoration method when comparing against other restoration methods to make each appear more or less favorable for selection. The smaller, the better
	}
}
local CDs <const> = {
	Warp: number = 6, -- Duration for the warp timer
	Sheathe: number = 4.4, -- Duration for the sheathe timer
	NudgeDelay: number = 4, -- The number of seconds follower should wander after being nudged before following the player again
}
local StatMods <const> = {
	CatchupMultiplier: number = 2.25, -- Multiplier that is applied to the player's athletics and speed, the product of which is then added to the follower's athletics and speed as a modifier
	DefaultSpeed: number = 15, -- Flat modifier to be applied to follower's speed and athletics when normally following the player
	WanderSpeed: number = 40, -- Flat modifier to be applies to follower's speed when wandering instead of followings
}
local Thresholds <const> = {
	ModifySpeed: number = 300, -- The distance threshold that determines whether follower moves at normal speed or speeds up to catch up with the player
	MaintainDistLower: number = 70, -- The lower distance threshold that forces follower to wander away from the player
	MaintainDistUpper: number = 100, -- The upper distance threshold that makes companion follow the player again after moving away
	Wander: number = 300, -- The distance parameter for follower's wander package when maintaining their distance
}

-- Function Definitions
-- Handler functions - Functions that will be called directly by OpenMW
local handler = {}

function handler.delayUpdate1(self: Follower) -- This function runs once every x seconds, where x = DELAY1
	if core.isWorldPaused() == true then return end

	if self:isFollowing() == true then
		self:toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate as string))
		self:toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking as string))
		self:forceZLevel()
		self:modSpeedAndAthletics()
	elseif self.player ~= nil then
		self:setDefaultSpeed()
	end
end

function handler.delayUpdate2(self: Follower) -- This function runs once every x seconds, where x = DELAY2
	if core.isWorldPaused() == true then return end

	if self:isFollowing() == true then
		self:incrementRapport()
	end
end

function handler.onUpdate(self: Follower, dt: number) -- This function executes every frame and, as such, should be used as sparingly as possible
	self:getPlayerLeader()
	self:resetDialogueVars()
    self:checkDynStats()
	self:updateTimers(dt)
	if types.Actor.isOnGround(self.selfObj) == false and self.checks["fly"] == false then
		self:freeFall()
	end
	if self:isFollowing() == true then
		self:setSneak()
		self:warpToPlayer()
	elseif self.player ~= nil then -- This condition should be reserved for function calls that take place when the follower is temporarily not following the player e.g., the follower has not been dismissed. Behaviors that occur when the follower has been dismissed should be placed outside of this condition block
		self:maintainDistance()
		self:nudge(dt)
	end
end

function handler.onSave(self: Follower, payload: {string: any}): cmn.SaveData -- This function executes whenever the player saves their game, and the return value of this function is used to store data to the player's save file that should persist across player sessions
	for k, v in pairs(self.MWVars) do
		self:updateMWVars({[k] = v})
	end
	return cmn.merge(
		{
			player = self.player,
			rapportCounter = self.rapportCounter,
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

function handler.onLoad(self: Follower, data: cmn.SaveData) -- This function will run only when the script loads data from a saved game. If onSave was not previously called, no data will have been saved to the player's game file and this function will not execute
		self.player = data.player
		self.rapportCounter = data.rapportCounter
		self.doOnce = data.doOnce
		self.doOnce2 = data.doOnce2
		self.checks = data.checks
		self.timers = data.timers
		self.restoreDynStat = data.restoreDynStat
		self.posA = data.posA
		self.posB = data.posB
		self.posC = data.posC
end

function handler.onActivated(_: Follower, _: types.Actor) -- This function will run any time the follower is activated by another actor, presumably a player
end

-- Utility functions -- Functions that may return game values or that other functions may depend on for calculations or checks
local utility = {}

function utility.updateMWVars(self: Follower, data: {string: number}) -- Send an event to the global script to update a single mwscript variable with the provided value
	core.sendGlobalEvent("updateMWVar", {data, self.selfObj})
end

function utility.isFollowing(self: Follower): boolean -- Simply return true or false if companion is currently following any player
	local currentPackage = self.ai.getActivePackage()
	return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

function utility.getPlayerLeader(self: Follower) -- Gets the player object that companion is currently following
	if self:isFollowing() then
		self.player = self.ai.getActiveTarget("Follow")
	end
end

function utility.fullHeal(self: Follower) -- Fully restore follower's health
	self.dynamicStats[1](self.selfObj).current = cmn.getMaxDynStat(self.dynamicStats[1](self.selfObj))
end

function utility.checkForPotion(self: Follower, potionName: string): boolean -- Returns true if follower has any of the specified potions in their inventory
	local inventory = types.Actor.inventory(self.selfObj)
	return inventory:countOf(potionName) > 0
end

function utility.getPlayerCellPos(self: Follower): cmn.CellLoc -- Get the cell location of the player that companion is currently following
	return {cellId = self.player.cell.name, cellPos = self.player.position}
end

function utility.setSheatheWarpTimers(self: Follower, dt: number) -- Sheathe weapon after combat check
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

function utility.updateTimers(self: Follower, dt: number) -- This function updates our various timers by dt, the time passed since this script's last executions
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

function utility.resetDialogueVars(self: Follower) -- This function sets all dialogue mwscript variables back to 0 when called
	local vars = {
		["locationThoughts"] = self.mwBool.FALSE,
		["npcThoughts"] = self.mwBool.FALSE,
		["mainquestThoughts"] = self.mwBool.FALSE,
		["magequestThoughts"] = self.mwBool.FALSE,
		["moragquestThoughts"] = self.mwBool.FALSE,
		["thiefquestThoughts"] = self.mwBool.FALSE,
		["fighterquestThoughts"] = self.mwBool.FALSE,
		["legionquestThoughts"] = self.mwBool.FALSE,
		["cultquestThoughts"] = self.mwBool.FALSE,
		["templequestThoughts"] = self.mwBool.FALSE,
		["housequestThoughts"] = self.mwBool.FALSE,
	}
	self:updateMWVars(vars)
end
--

-- Gameplay functions -- Functions that modify follower's gameplay behavior
local gameplay = {}

function gameplay.setSneak(self: Follower) -- Make sure if the player is sneaking, follower sneaks as well
	if self.player ~= nil then
		self.player:sendEvent("getSneakVal", self.selfObj)
	end
	if self.controls.sneak ~= self.checks["playerSneak"] then
		self.controls.sneak = self.checks["playerSneak"]
	end
end

function gameplay.makeCompanionFollow(self: Follower) -- Helper function for setting the Follow AI package
	self.ai.startPackage({
		type = "Follow",
		target = self.player
	})
end

function gameplay.toggleEffect(self: Follower, flag: cmn.Flag, effectType: string) -- This function should apply the levitate effect to companion if the player is levitating, and remove it if the player isn't
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

function gameplay.freeFall(self: Follower) -- Used to call various functions that should trigger while follower is in freefall
	if self.timers["freefall"] > 1 and self:checkForPotion("p_slowfall_s") then
		self.timers["freefall"] = -(self:consumePotion("p_slowfall_s", "SlowFall"))
	end
end

function gameplay.incrementRapport(self: Follower) -- Used to increment or decrement the player's rapport with the follower
	if self.rapportCounter >= 1 and self.MWVars["rapport"] < self.rapportMods.MAX then
		self:updateMWVars({["rapport"] = 1})
	elseif self.rapportCounter <= -1 and self.MWVars["rapport"] > self.rapportMods.MIN then
		self:updateMWVars({["rapport"] = -1})
	end
end

function gameplay.checkRapportGrowth(self: Follower) -- Calculate the player's rapport growth based on the player's time spent traveling with the follower and the follower's preferences toward the player
	if self.features.RAPP_EN == false then return end
	local playerRecord = types.NPC.record(self.player)
	local rapportGrowth = self.rapportMods.BASE

	if self.features.RAPP_RACE == true and self.followerPrefs.RACE[playerRecord.race] ~= nil then
		rapportGrowth = rapportGrowth + self.followerPrefs.RACE[playerRecord.race]
	end

	if self.features.RAPP_SEX == true and self.followerPrefs.SEX[playerRecord.isMale] ~= nil then
		rapportGrowth = rapportGrowth + self.followerPrefs.SEX[playerRecord.isMale]
	end
	
	if self.features.RAPP_GUILDS == true then
		local playerFactions = types.NPC.getFactions(self.player)
		for _, v in ipairs(playerFactions) do
			if self.followerPrefs.GUILDS[v] ~= nil then
				if types.NPC.isExpelled(self.player, v) == false then
					rapportGrowth = rapportGrowth + (self.followerPrefs.GUILDS[v] * types.NPC.getFactionRank(self.player, v))
				else
					rapportGrowth = rapportGrowth + (self.followerPrefs.GUILDS[v] * self.rapportMods.EXPELLED_MOD)
				end
			end
		end
	end

	if self.features.RAPP_DISP == true then
		local dispositionMod = ((types.NPC.getDisposition(self.selfObj, self.player) - self.rapportMods.DISP_MOD) / self.rapportMods.DISP_DIV)
		rapportGrowth = rapportGrowth + dispositionMod
	end

	self.rapportCounter = self.rapportCounter + rapportGrowth
	if (self.rapportCounter >= 1 or self.rapportCounter <= -1) then
		self:incrementRapport()
		self.rapportCounter = 0
	end
end

	-- Restore dynamic stat logic
function gameplay.castSpell(self: Follower, spell: core.Spell, castSound: string): number -- Applies the effect of the specified spell to the follower, including vfx and sound, and then consumes follower's magicka equal to the cost of the spell. 
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

function gameplay.useEnchantment(self: Follower, itemRecord: cmn.EnchRecord, effectName: string, castSound: string): number -- Makes follower use the specified enchanted item, applying its magic effect and consuming some of the item's charge
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

function gameplay.consumePotion(self: Follower, potionID: string, effectName: string): number -- Sends a global event to trigger follower to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
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

function gameplay.useScroll(self: Follower, scrollId: string, effectName: string, castSound: string): number -- Sends a global event to trigger follower to use the specified scroll. Returns the duration of whatever effect is specified, or 60 if the scroll does not have that effect
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

function gameplay.selectRestoreEnch(self: Follower, effectId: string, attrDiff: number, itemType: cmn.EnchType): {cmn.EnchRecord, number} -- Scans through the follower's inventory, finding the enchanted item that has the most applicable restorative effect
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

function gameplay.selectRestoreSpell(self: Follower, effectId: string, attrDiff: number): {core.Spell, number} -- Selects the best restorative spell the NPC currently has (prioritizes magnitude over cost). Prefers the spell that restores closest to the missing amount of whichever attribute is being restored rather than just the spell with the greatest magnitude, currently ignores all side effects of casting the spell. Returns nil if no spell is found
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

function gameplay.selectRestorePotion(self: Follower, effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
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

function gameplay.selectRestoreScroll(self: Follower, effectId: string, attrDiff: number, attrMax: number): {string, number} -- Find whichever scroll is enchanted with an effect that has the most suitable restore health/magicka/fatigue amount out of all scrolls in the follower's inventory
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

function gameplay.chooseRestoreMethod(self: Follower, iter: integer) -- Intelligently selects the most appropriate healing method to use when health is low based on what spells, potions, scrolls, and enchantments are available. As of OpenMW 0.50, scrolls and enchantments are not available due to API limitations
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
	if self.features.REST_ENCHANT_USE == true and self.restoreDynStat[iter].enchantmentTimer <= 0 then
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
	if self.features.REST_SPELL_USE == true and self.restoreDynStat[iter].spellTimer <= 0 and self.dynamicStats[2](self.selfObj).current > 0 then
		local spell = self:selectRestoreSpell(self.restoreDynStat[iter].effectId, attrDiff)
		if spell ~= nil then
			table.insert(restoreMethods, {
				name = "spell",
				data = spell[1],
				weight = spell[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.SPELL_WEIGHT),
			})
		end
	end
	if self.features.REST_POTION_USE == true and self.restoreDynStat[iter].potionTimer <= 0 then
		local potion = self:selectRestorePotion(self.restoreDynStat[iter].effectId, attrDiff, cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)))
		if potion ~= nil then
			table.insert(restoreMethods, {
				name = "potion",
				data = potion[1],
				weight = potion[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.POTION_WEIGHT),
			})
		end
	end
	if self.features.REST_SCROLL_USE == true and self.restoreDynStat[iter].scrollTimer <= 0 then
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

function gameplay.checkDynStats(self: Follower) -- Used to call various functions that affect follower's dynamic attributes like health, fatigue, and magicka
	for i = 1, #self.dynamicStats do
		if self.features.REST_DYN_STATS == true and cmn.getDynStatMissingPerc(self.dynamicStats[i](self.selfObj)) <= self.restoreConsts.TRIGGER_PERC and self.timers["restorecooldown"] <= 0 then
			self:chooseRestoreMethod(i)
		end
	end
end
--

-- Movement functions - Functions that modify follower's movement behavior
local movement = {}

function movement.forceZLevel(self: Follower) -- If in combat, levitating and the player Z level is different from follower's, force follower's Z level to the player's
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

function movement.maintainDistance(self: Follower) -- Toggles follower between wandering and following the player in order to maintain a small window of distance from the player. Works only if the player activates it from dialogue by updating the "compmove" variable
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

function movement.nudge(self: Follower, timePassed: number) -- Waits 4 seconds before making companion follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make them move
	if self.MWVars["onetimemove"] == self.mwBool.TRUE then
		self.timers["move"] = self.timers["move"] + timePassed
		if self.timers["move"] >= self.NUDGE_DELAY then
			self.timers["move"] = 0
			self:makeCompanionFollow()
			self:updateMWVars({["onetimemove"] = self.mwBool.FALSE})
		end
	end
end

function movement.warpToPlayer(self: Follower) -- If the player gets too far from follower, teleport follower closer to the player
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

function movement.setDefaultSpeed(self: Follower) -- Sets follower's speed modifier while not following the player
	types.Actor.stats.attributes.speed(self.selfObj).modifier = self.statMod.WANDER
end

function movement.modSpeedAndAthletics(self: Follower) -- Set follower's speed and athletics modifier to a flat value if they're within a certain distance of the player, or add a multiplier based off the player's stats if they're too far
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
		mwBool = { -- MWScript does not have boolean types, so all MWVars are numbers even if they're being used as boolean flags
			TRUE = 1,
			FALSE = 0,
		},
		
	    -- Constants
	    --SKILL_LEVEL_MULT = SkillLevelGainMultiplier
		RAPPORT_GROWTH_THRESHOLD = Rapport.GrowthThreshold,
		NUDGE_DELAY = CDs.NudgeDelay,
		DELAY1 = Delay1,
		DELAY2 = Delay2,
	    features = {
			REST_DYN_STATS = FeatureFlags.RestoreDynStats.Enable,
			REST_ENCHANT_USE = FeatureFlags.RestoreDynStats.Enchant,
			REST_SPELL_USE = FeatureFlags.RestoreDynStats.Spell,
			REST_POTION_USE = FeatureFlags.RestoreDynStats.Potion,
			REST_SCROLL_USE = FeatureFlags.RestoreDynStats.Scroll,
			RAPP_EN = FeatureFlags.Rapport.Enable,
			RAPP_RACE = FeatureFlags.Rapport.Race,
			RAPP_SEX = FeatureFlags.Rapport.Sex,
			RAPP_GUILDS = FeatureFlags.Rapport.Guilds,
			RAPP_DISP = FeatureFlags.Rapport.Disp,
		},
	    statMod = {
	        CATCHUP_MULT = StatMods.CatchupMultiplier,
	        FOLLOW = StatMods.DefaultSpeed,
	        WANDER = StatMods.WanderSpeed,
	    },
		defaultCd = {
			RESTORE = Restore.CDs.General,
			ENCHANTMENT = Restore.CDs.Enchantment,
			SPELL = Restore.CDs.Spell,
			POTION = Restore.CDs.Potion,
			SCROLL = Restore.CDs.Scroll,
			WARP = CDs.Warp,
			SHEATHE = CDs.Sheathe,
		},
		restoreConsts = {
			TRIGGER_PERC = Restore.Thresholds.Trigger,
			PANIC_THRESHOLD = Restore.Thresholds.Panic,
			ENCHANTMENT_WEIGHT = Restore.Weights.Enchantment,
			SPELL_WEIGHT = Restore.Weights.Spell,
			POTION_WEIGHT = Restore.Weights.Potion,
			POTION_WASTE = Restore.Thresholds.PotionWaste,
			SCROLL_WEIGHT = Restore.Weights.Scroll,
			SCROLL_WASTE = Restore.Thresholds.ScrollWaste,
		},
		distanceThreshold = {
			MOD_SPEED = Thresholds.ModifySpeed,
			MAINTAIN_LOWER = Thresholds.MaintainDistLower,
			MAINTAIN_UPPER = Thresholds.MaintainDistUpper,
			WANDER = Thresholds.Wander,
		},
		followerPrefs = {
			RACE = Rapport.Preferences.Race,
			SEX = Rapport.Preferences.Sex,
			GUILDS = Rapport.Preferences.Guilds,
		},
		rapportMods = {
			BASE = Rapport.BaseModifier,
			DISP_MOD = Rapport.DispModifier,
			DISP_DIV = Rapport.DispDivisor,
			EXPELLED_MOD = Rapport.ExpelledModifier,
			MAX = Rapport.Max,
			MIN = Rapport.Min,
		},
	
		-- Variables
	    player = nil,
		rapportCounter = 0,
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
			short companion -- 1 enables companion share, 0 disables it
			short nohello -- Not entirely sure
			short nolore -- Not entirely sure
			short compmove -- 1 if the player has asked follower to maintain their distance
			short onetimemove -- 1 if the player has asked follower to move out of the way
			short weapuse -- 1 if the player has asked follower to use the same weapons as the player
			short questThoughts -- 1 if the player has asked follower for their opinion about ongoing quests. Enables dialogue topics for in-progress quests
			short locationThoughts -- 1 if the player has asked follower for their opinion about locations. Enables dialogue topics for visited locations
			short npcThoughts -- 1 if the player has asked follower for their opinion about individuals. Enables dialogue topics for various NPCs that have been met
		]]
		
		-- Handler functions - Functions that will be called directly by OpenMW
		delayUpdate1 = handler.delayUpdate1,
		delayUpdate2 = handler.delayUpdate2,
		onUpdate = handler.onUpdate,
		onSave = handler.onSave,
		onLoad = handler.onLoad,
		onActivated = handler.onActivated,
		-- Utility functions -- Functions that may return game values or that other functions may depend on for calculations or checks
		updateMWVars = utility.updateMWVars, -- Send an event to the global script to update a single mwscript variable with the provided value
		isFollowing = utility.isFollowing, -- Simply return true or false if companion is currently following any player
		getPlayerLeader = utility.getPlayerLeader, -- Gets the player object that companion is currently following		
		fullHeal = utility.fullHeal, -- Fully restore follower's health		
		checkForPotion = utility.checkForPotion, -- Returns true if follower has any of the specified potions in their inventory
		getPlayerCellPos = utility.getPlayerCellPos, -- Get the cell location of the player that companion is currently following
		setSheatheWarpTimers = utility.setSheatheWarpTimers, -- Sheathe weapon after combat check
		updateTimers = utility.updateTimers, -- This function updates our various timers by dt, the time passed since this script's last executions
		resetDialogueVars = utility.resetDialogueVars, -- This function sets all dialogue mwscript variables back to 0 when called
		-- Gameplay functions -- Functions that modify follower's gameplay behavior
		setSneak = gameplay.setSneak, -- Make sure if the player is sneaking, follower sneaks as well
		makeCompanionFollow = gameplay.makeCompanionFollow, -- Helper function for setting the Follow AI package
		toggleEffect = gameplay.toggleEffect, -- This function should apply the levitate effect to companion if the player is levitating, and remove it if the player isn't
		freeFall = gameplay.freeFall, -- Used to call various functions that should trigger while follower is in freefall
		incrementRapport = gameplay.incrementRapport, -- Used to increment or decrement the player's rapport with the follower
		checkRapportGrowth = gameplay.checkRapportGrowth, -- Calculate the player's rapport growth based on the player's time spent traveling with the follower and the follower's preferences toward the player
		castSpell = gameplay.castSpell, -- Applies the effect of the specified spell to the follower, including vfx and sound, and then consumes follower's magicka equal to the cost of the spell. 
		useEnchantment = gameplay.useEnchantment, -- Makes follower use the specified enchanted item, applying its magic effect and consuming some of the item's charge
		consumePotion = gameplay.consumePotion, -- Sends a global event to trigger follower to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
		useScroll = gameplay.useScroll, -- Sends a global event to trigger follower to use the specified scroll. Returns the duration of whatever effect is specified, or 60 if the scroll does not have that effect
		selectRestoreEnch = gameplay.selectRestoreEnch, -- Scans through the follower's inventory, finding the enchanted item that has the most applicable restorative effect
		selectRestoreSpell = gameplay.selectRestoreSpell, -- Selects the best restorative spell the NPC currently has (prioritizes magnitude over cost). Prefers the spell that restores closest to the missing amount of whichever attribute is being restored rather than just the spell with the greatest magnitude, currently ignores all side effects of casting the spell. Returns nil if no spell is found
		selectRestorePotion = gameplay.selectRestorePotion, -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
		selectRestoreScroll = gameplay.selectRestoreScroll, -- Find whichever scroll is enchanted with an effect that has the most suitable restore health/magicka/fatigue amount out of all scrolls in the follower's inventory
		chooseRestoreMethod = gameplay.chooseRestoreMethod, -- Intelligently selects the most appropriate healing method to use when health is low based on what spells, potions, scrolls, and enchantments are available. As of OpenMW 0.50, scrolls and enchantments are not available due to API limitations
		checkDynStats = gameplay.checkDynStats, -- Used to call various functions that affect follower's dynamic stats like health, fatigue, and magicka
		-- Movement functions - Functions that modify follower's movement behavior
		forceZLevel = movement.forceZLevel, -- If in combat, levitating and the player Z level is different from follower's, force follower's Z level to the player's
		maintainDistance = movement.maintainDistance, -- Toggles follower between wandering and following the player in order to maintain a small window of distance from the player. Works only if the player activates it from dialogue by updating the "compmove" variable
		nudge = movement.nudge, -- Waits 4 seconds before making companion follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make them move
		warpToPlayer = movement.warpToPlayer, -- If the player gets too far from follower, teleport follower closer to the player
		setDefaultSpeed = movement.setDefaultSpeed, -- Sets follower's speed modifier while not following the player
		modSpeedAndAthletics = movement.modSpeedAndAthletics, -- Set follower's speed and athletics modifier to a flat value if they're within a certain distance of the player, or add a multiplier based off the player's stats if they're too far
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