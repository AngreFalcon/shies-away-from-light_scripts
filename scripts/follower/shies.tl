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

local Shies = follower({
	self = self as follower.OMW_SELF,
	ai = ai as follower.OMW_AI
})

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
	short fled -- 1 if shies has teleported away during combat
]]

-- Shies-specific utility functions
local function triggerShiesFledQuest() -- Used to trigger the shies fled quest. Should only be triggered once
	if Shies.player ~= nil then
		Shies.player:sendEvent("shiesFled", nil)
	end
end
--

-- Shies-specific gameplay functions
local function shiesIncapacitated(getBackUp: boolean) -- This function applies and ends the knockout animation for shies. The boolean parameter must be true for the animation to end
	local animName = "knockout"
	if anim.isPlaying(Shies.selfObj, animName) == false then
		anim.clearAnimationQueue(Shies.selfObj, false) -- Empties anim queue to immediately play the knockout animation
		anim.playQueued(Shies.selfObj, animName, {})
	elseif getBackUp == true then
		I.AnimationController.addTextKeyHandler(animName, function(animGroup: string, key: string)
			anim.playQueued(Shies.selfObj, animGroup, {startkey = 'stop', stopkey = 'stop', loops = 0})
			if key.sub(key, #key - #'stop') == 'stop' then
				anim.clearAnimationQueue(Shies.selfObj, true) -- Only clear the anim queue once the knockout anim has finished its current loop
			end
		end)
		Shies.checks["incapacitated"] = false
	end
end

local function flee() -- Triggers if shies' health drops below a certain threshold. Plays the magic cast VFX and then teleports shies to a preset location while canceling shies' follow AI package
    local vfx = core.magic.effects.records["recall"] -- Trigger the Recall vfx
    Shies.selfObj:sendEvent('AddVfx', {
        model = types.Static.record(vfx.hitStatic).model,
        options = {
            vfxId = "vfxShiesFlee",
            particleTextureOverride = vfx.particle,
            loop = false,
        }
    })
	core.sound.playSound3d("mysticism cast", Shies.selfObj, {})
	
    local cb = time.registerTimerCallback( -- Teleport away after RECALL_TIMEOUT seconds
        Shies.selfObj.id .. "_FleeCallback",
        function(actor: core.GameObject)
			ai.removePackages("Combat")
			ai.removePackages("Follow")
			if RecallLoc == SHIES.INIT_DATA.recallLoc and (types.Player.quests(Shies.player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].started == false then
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
	if RecallLoc == SHIES.INIT_DATA.recallLoc and (types.Player.quests(Shies.player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage < SHIES.SHIES_FLED_FOUND_STAGE then -- The player has not recovered shies yet
		Shies.checks["incapacitated"] = true
	end
    time.newSimulationTimer(SHIES.RECALL_TIMEOUT, cb, self, nil)
end

local function shiesCheckDynStats() -- Calls shies-specific functions relating to dynamic stats
	if Shies.dynamicStats[1](Shies.selfObj).current > 0
	and Shies.dynamicStats[1](Shies.selfObj).current / cmn.getMaxDynStat(Shies.dynamicStats[1](Shies.selfObj)) < SHIES.FLEE_THRESHOLD then -- Check health ratio
		Shies:updateMWVars({["companion"] = Shies.mwBool.FALSE})
		Shies.checks["cMove"] = false
        flee() -- Teleport Shies away from combat to whatever position he has marked
		Shies:fullHeal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
		return
	end
end

local function setNewRecallLoc() -- Mark a new location for shies to recall to when fleeing from combat
	Shies:updateMWVars({["markloc"] = Shies.mwBool.FALSE})
    local vfx = core.magic.effects.records["mark"] -- Trigger the Mark vfx
    core.sound.playSound3d("mysticism cast", Shies.selfObj, {})
	Shies.selfObj:sendEvent('AddVfx', {
        model = types.Static.record(vfx.hitStatic).model,
        options = {
            vfxId = "vfxShiesFlee",
            particleTextureOverride = vfx.particle,
            loop = false,
        }
    })
	if (Shies.selfObj.cell.isExterior == true) then
		RecallLoc.cellId = ""
	else
		RecallLoc.cellId = Shies.selfObj.cell.id
	end
	RecallLoc.cellPos = util.vector3(Shies.selfObj.position.x, Shies.selfObj.position.y, Shies.selfObj.position.z)
end
--

-- Handler functions - Functions that will be called directly by OpenMW
time.runRepeatedly( -- This function runs once every x seconds, where x = DELAY1
	function() 
		Shies:delayUpdate1()
	end, Shies.DELAY1, {}
)

time.runRepeatedly( -- This function runs once every x seconds, where x = DELAY2
	function()
		Shies:delayUpdate2()
	end, Shies.DELAY2, {}
)

time.runRepeatedly( -- This function runs once every x seconds, where x = DELAY3
	function()
		Shies:delayUpdate3()
	end, Shies.DELAY3, {}
)

	-- Engine handlers
local engine = {}

function engine.onUpdate(dt: number) -- Called every frame while the script is loaded
	if core.isWorldPaused() == true then return end

	shiesCheckDynStats()
	if Shies.checks["incapacitated"] == true then
		-- Right now there is only one instance of shies being incapacitated, and only one condition under which he gets back up
		-- However, if this mechanic is extended in the future, passing a boolean parameter as the get up condition makes this trivial
		shiesIncapacitated((types.Player.quests(Shies.player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage >= SHIES.SHIES_FLED_FOUND_STAGE)
	end

	if Shies.MWVars["markloc"] == Shies.mwBool.TRUE then
		setNewRecallLoc()
	end

	Shies:onUpdate(dt)
end

function engine.onInit() -- Called when the script is created but not loaded
	RecallLoc = SHIES.INIT_DATA.recallLoc
end

function engine.onSave(): cmn.SaveData -- Called when the game saves, even if currently in an inactive state
	return Shies:onSave({
		version = cmn.SCRIPT_VERSION,
		recallLoc = RecallLoc,
	})
end

function engine.onLoad(data: cmn.SaveData) -- Called only when the script loads, not the saved game. Will not be called if the script was not previously saved
	if (not data) or (not data.version) or (data.version < cmn.SCRIPT_VERSION) then
		print('Was saved with an old version of the script, initializing to default')
		RecallLoc = SHIES.INIT_DATA.recallLoc
		return
	elseif (data.version > cmn.SCRIPT_VERSION) then
		error('Required update to a new version of the script')
	elseif (data.version == cmn.SCRIPT_VERSION) then
		RecallLoc = data.recallLoc
		Shies:onLoad(data)
	end
end

function engine.onActivated(actor: types.Actor) -- Called whenever a player activates shies, initiating dialogue
	Shies:onActivated(actor)
end
--

return {
    engineHandlers = engine,
    eventHandlers = {
		["fetchMWVars"] = function(data: {string: number})
			Shies.MWVars = data
			for k, v in pairs(data) do
				if Shies.MWVars[k] ~= v then
					Shies.MWVars[k] = v
				end
			end
		end,
        ["Hit"] = function(attack: I.Combat.AttackInfo) -- Example of sending an event (with a message) back to the player that hit him
            local attackerObj = attack.attacker as core.GameObject
            attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
        end,
        ["hurtShies"] = function() -- For testing the "Recall away at low health" feature - this event is sent from the player script
            Shies.dynamicStats[1](Shies.selfObj).current = 1
        end,
		["shiesJump"] = function()
			print(types.NPC.stats.skills.acrobatics(Shies.selfObj).progress)
			Shies.controls.jump = true
			print(types.NPC.stats.skills.acrobatics(Shies.selfObj).progress)
			local playerRecord = types.NPC.record(Shies.player)
			local playerFactions = types.NPC.getFactions(Shies.player)
			print(playerRecord.race)
			for _, v in ipairs(playerFactions) do
				print(v)
			end
		end,
		["shiesActivated"] = function()
		end,
		["playerSneak"] = function(sneaking: boolean)
			if sneaking ~= nil then
				Shies.checks["playerSneak"] = sneaking
			end
		end,
    }
}