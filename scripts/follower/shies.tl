local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local anim = require('openmw.animation')
local cmn = require('scripts.follower.common')
local follower = require('scripts.follower.follower')

local Shies = {}
setmetatable(Shies, { __index = Shies.parent })

-- Shies Constants
local SHIES <const> = {
	FLEE_THRESHOLD = 0.1, -- The health percentage at which shies should flee from combat via recall
	SHIES_FLED_FOUND_STAGE = 40, -- The stage at which the player has found and spoken with shies after shies fled from combat for the first time
	RECALL_TIMEOUT = 2 * time.second, -- The number of seconds it will take for shies' recall to complete when initiated
	INIT_DATA: cmn.SaveData = {recallLoc = {cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251)}} -- Initial recall point for shies
}

-- Shies Variables
local RecallLoc: cmn.CellLoc

--[[ Shies-specific MWVars
	short fled -- True if shies has teleported away during combat
]]

-- Shies-specific utility functions
local function triggerShiesFledQuest() -- Used to trigger the shies fled quest. Should only be triggered once
	if player ~= nil then
		player:sendEvent("shiesFled", nil)
	end
end
--

-- Shies-specific gameplay functions
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
			if RecallLoc == SHIES.INIT_DATA.recallLoc and (types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].started == false then
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
	if RecallLoc == SHIES.INIT_DATA.recallLoc and (types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage < SHIES.SHIES_FLED_FOUND_STAGE then -- The player has not recovered shies yet
		checks["incapacitated"] = true
	end
    time.newSimulationTimer(SHIES.RECALL_TIMEOUT, cb, self, nil)
end

local function shiesCheckAttributes() -- Calls shies-specific functions relating to attributes
	if attributes[1](selfObj).current > 0 and attributes[1](selfObj).current / getMaxAttr(attributes[1](selfObj)) < SHIES.FLEE_THRESHOLD then -- Check health ratio
		updateMWVar("companion", BOOL.FALSE)
		checks["cMove"] = false
        flee() -- Teleport Shies away from combat to whatever position he has marked
		fullHeal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
		return
	end
end
--

-- Handler functions - Functions that will be called directly by OpenMW
time.runRepeatedly( -- This function runs once every x seconds, where x = DELAY1
	function() 
		if isFollowing() then
			modSpeedAndAthletics()
		elseif player ~= nil then
			setDefaultSpeed()
		end
	end, DELAY1, {}
)

time.runRepeatedly( -- This function runs once every x seconds, where x = DELAY2
	function()

	end, DELAY2, {}
)

local function onUpdate(dt: number) -- Called every frame while the script is loaded
	if core.isWorldPaused() == true then
		return
	end
	getPlayerLeader()
    checkAttributes()
	updateTimers(dt)
	
	shiesCheckAttributes()
	if checks["incapacitated"] == true then
		-- Right now there is only one instance of shies being incapacitated, and only one condition under which he gets back up
		-- However, if this mechanic is extended in the future, passing a boolean parameter as the get up condition makes this trivial
		shiesIncapacitated((types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage >= SHIES.SHIES_FLED_FOUND_STAGE)
	end

	if checks["fly"] == false and types.Actor.isOnGround(selfObj) == false then
		freeFall()
	end
	if isFollowing() then
		setSneak()
		toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate as string))
		toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking as string))
		forceZLevel()
		warpToPlayer()
	elseif player ~= nil then -- This condition should be reserved for only function calls that take place when the follower is temporarily not following the player e.g., the follower has not been dismissed. Behaviors that occur when the follower has been dismissed should be placed outside of this condition block
		maintainDistance()
		nudge(dt)
	end
end

local function onInit() -- Called when the script is created but not loaded
	RecallLoc = SHIES.INIT_DATA.recallLoc
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
	timers["restorecooldown"] = 0
	restoreAttr[1] = {
		potionTimer = 0,
		spellTimer = 0,
		scrollTimer = 0,
		enchantmentTimer = 0,
		effectName = "Restore Health",
		effectId = "restorehealth",
	}
	restoreAttr[2] = {
		potionTimer = 0,
		spellTimer = 0,
		scrollTimer = 0,
		enchantmentTimer = 0,
		effectName = "Restore Magicka",
		effectId = "restoremagicka",
	}
	restoreAttr[3] = {
		potionTimer = 0,
		spellTimer = 0,
		scrollTimer = 0,
		enchantmentTimer = 0,
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
		RecallLoc = SHIES.INIT_DATA.recallLoc
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
		["shiesJump"] = function()
			print(types.NPC.stats.skills.acrobatics(selfObj).progress)
			(selfObj as self).controls.jump = true
			print(types.NPC.stats.skills.acrobatics(selfObj).progress)
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