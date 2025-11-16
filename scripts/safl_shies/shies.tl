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
-- important to note: all MWScript variables are automatically cast to all lowercase
local MWVars: {string: number} = {}
--

local function updateMWVar(varName: string, varData: number) -- Send an event to the global script to update a single mwscript variable with the provided value
	core.sendGlobalEvent("updateMWVar", {varName, varData, selfObj})
end

local function onInit() -- Called when the script is created but not loaded
	RECALL_LOC = INIT_DATA.recallLoc
end

local function onSave(): SaveData -- Called when the game saves, even if currently in an inactive state
	for k, v in pairs(MWVars) do
		updateMWVar(k, v)
	end
	return {
		version = ScriptVersion,
		recallLoc = RECALL_LOC,
		playerLeader = PlayerLeader,
	}
end

local function onLoad(data: SaveData) -- Called only when the script loads, not the saved game. will not be called if the script was not previously saved
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

local function triggerShiesFledQuest() -- Used to trigger the shies fled quest. should only be triggered once
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

local function isShiesFollowing(): boolean -- Simply return true or false if shies is currently following any player
	local currentPackage = ai.getActivePackage()
	if currentPackage ~= nil and currentPackage.type == "Follow" then
		return true
	else
		return false
	end
end

local function getPlayerLeader() -- Gets the player object that shies is currently following
	if isShiesFollowing() then
		PlayerLeader = ai.getActiveTarget("Follow")
	end
end

local function getPlayerCellPos(): CellLoc | nil -- Get the cell location of the player that shies is currently following
	if PlayerLeader == nil then
		return nil
	elseif (PlayerLeader as core.GameObject) then
		return {cellId = (PlayerLeader as core.GameObject).cell.name, cellPos = (PlayerLeader as core.GameObject).position}
	end
end

local function getCoDist(vector1: util.Vector3, vector2: util.Vector3): number -- Get cosine distance between two vectors
	local tempVar1 = vector1.x - vector2.x
	local tempVar2 = vector1.y - vector2.y
	return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function maintainDistance() -- Toggles shies between wandering and following the player in order to maintain a small window of distance from the player. works only if the player activates it from dialogue by updating the "compmove" variable
	local shiesPos = selfObj.position
	local playerPos: CellLoc = (getPlayerCellPos() as CellLoc)
	local c_move: boolean = false
	if playerPos == nil then
		return
	end
	if isShiesFollowing() and MWVars["compmove"] == 1 and c_move == false and getCoDist(shiesPos, playerPos.cellPos) < 70 then
		ai.startPackage({
			type = "Wander",
			distance = 300
		})
		c_move = true
	end
	if c_move == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
		ai.startPackage({
			type = "Follow",
			target = PlayerLeader
		})
		c_move = false
	end
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

	if MWVars["warp"] == 0 and getCoDist(selfObj.position, (getPlayerCellPos() as CellLoc).cellPos) > 680 then
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
			getPlayerLeader()
            if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
				updateMWVar("companion", 0)
				updateMWVar("c_move", 0)
                flee() -- Teleport Shies away from combat to whatever position he has marked
    			heal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
            end
			if isShiesFollowing() then
				warpToPlayer()
			end
			maintainDistance()
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
		["shiesActivated"] = function()
		 	for k, v in pairs(MWVars) do
				print(k)
				print(v)
				print("--")
		 	end
		end,
    }
}