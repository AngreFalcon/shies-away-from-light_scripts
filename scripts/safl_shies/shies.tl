local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')

local interface CellLoc
	cellId: string
	cellPos: util.Vector3
end

local interface SaveData
	version: number
	recallLoc: CellLoc
	playerLeader: core.GameObject | nil
end

-- variables
local ScriptVersion = 1 -- increment whenever onSave is changed
local health = types.Actor.stats.dynamic.health
local selfObj = self as core.GameObject
--

-- constants
local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA: SaveData = {recallLoc = {cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251)}}
--

-- persistent variables
local RECALL_LOC: CellLoc
local PlayerLeader: core.GameObject | nil = nil
--

-- warp function variables - persistent
local posA: CellLoc | nil
local posB: CellLoc
local posC: CellLoc | nil
local doOnce: boolean = false
local doOnce2: boolean = false

-- mwscript variables - persistent
local MWVars: {string: number}
--

local function onInit() -- called when the script is created but not loaded
	RECALL_LOC = INIT_DATA.recallLoc
end

local function onSave(): SaveData -- called when the game saves, even if currently in an inactive state
	return {
		version = ScriptVersion,
		recallLoc = RECALL_LOC,
		playerLeader = PlayerLeader,
	}
end

local function onLoad(data: SaveData) -- called only when the script loads, not the saved game. will not be called if the script was not previously saved
	if (not data) or (not data.version) or (data.version < ScriptVersion) then
		print('Was saved with an old version of the script, initializing to default')
		RECALL_LOC = INIT_DATA.recallLoc
		return
	elseif (data.version > ScriptVersion) then
		error('Required update to a new version of the script')
	elseif (data.version == ScriptVersion) then
		RECALL_LOC = data.recallLoc
		PlayerLeader = data.playerLeader
	else

	end
end

local function updateMWVar(varName: string, varData: number)
	core.sendGlobalEvent("updateMWVar", {varName, varData, selfObj})
end

local function triggerShiesFledQuest() -- used to trigger the shies fled quest. should only be triggered once
	if PlayerLeader ~= nil then
		(PlayerLeader as core.GameObject):sendEvent("shiesFled", nil)
	end
end

local function getCurrentHealth(): number
    return health(selfObj).current
end

local function getMaxHealth(): number
    return health(selfObj).base + health(selfObj).modifier
end

local function heal()
    health(selfObj).current = getMaxHealth()
end

local function getPlayerCellPos(): CellLoc | nil
	if PlayerLeader == nil then
		return nil
	elseif (PlayerLeader as core.GameObject) then
		return {cellId = (PlayerLeader as core.GameObject).cell.name, cellPos = (PlayerLeader as core.GameObject).position}
	end
end

local function getCoDist(vector1: util.Vector3, vector2: util.Vector3): number
	local tempVar1 = vector1.x - vector2.x
	local tempVar2 = vector1.y - vector2.y
	return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function warpToPlayer() -- If the player gets too far from shies, teleport shies closer to the player
	posA = getPlayerCellPos()
	if posA == nil then
		return
	end
	
	if doOnce == false then
		posB = getPlayerCellPos()
		doOnce = true
	end
	
	local coDist = getCoDist((posA as CellLoc).cellPos, posB.cellPos)
	if coDist > 360 then
		doOnce = false
	end
	
	if (coDist > 180 and doOnce2 == false) or posC == nil then
		posC = getPlayerCellPos()
		doOnce2 = true
	end

	local coDist2 = getCoDist((posA as CellLoc).cellPos, (posC as CellLoc).cellPos)
	if coDist2 > 360 then
		doOnce2 = false
	end

	if MWVars["warp"] == 0 and getCoDist(self.object.position, (getPlayerCellPos() as CellLoc).cellPos) > 680 then
		if coDist > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = (posC as CellLoc).cellId,
				position = (posC as CellLoc).cellPos
			})
			ai.startPackage({
				type = "Follow",
				target = PlayerLeader
			})
		elseif coDist2 > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = posB.cellId,
				position = posB.cellPos
			})
			ai.startPackage({
				type = "Follow",
				target = PlayerLeader
			})
		end
	end
end

local function flee()
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
			if RECALL_LOC == INIT_DATA.recallLoc then
				triggerShiesFledQuest() -- The player has not changed Shies' marked location. This likely means the Shies Fled quest has not been started yet; we can further check by checking the player's journal entries
			end
            return core.sendGlobalEvent("teleport", {
				actor = actor,
				cell = RECALL_LOC.cellId,
				position = RECALL_LOC.cellPos
			})
        end,
        nil
    )
    time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end

return {
    engineHandlers = {
        onUpdate = function()
			local currentPackage = ai.getActivePackage()
            if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
				updateMWVar("companion", 0)
				updateMWVar("c_move", 0)
                flee() -- Teleport Shies away from combat to whatever position he has marked
    			heal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
            end
			if currentPackage ~= nil and currentPackage.type == "Follow" then
				warpToPlayer()
			end
        end,
		onInit = onInit,
		onSave = onSave,
		onLoad = onLoad,
    },
    eventHandlers = {
		["fetchMWVars"] = function(data: {string: number})
			MWVars = data
		end,
        ["Hit"] = function(attack: I.Combat.AttackInfo) -- example of sending an event (with a message) back to the player that hit him
            local attackerObj = attack.attacker as core.GameObject
            attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
        end,
        ["hurtShies"] = function() -- for testing the "Recall away at low health" feature - this event is sent from the player script
            health(selfObj).current = 1
        end,
		["shiesActivated"] = function(player: core.GameObject)
			print("shies activated")
			PlayerLeader = player
		end,
    }
}