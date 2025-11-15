local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local nearby = require('openmw.nearby')
local util = require('openmw.util')
require("scripts.safl_shies.shies_var")
require("scripts.safl_shies.common")

local health = types.Actor.stats.dynamic.health
local selfObj = self as core.GameObject

local function onInit() -- called when the script is created but not loaded
	RECALL_LOC = INIT_DATA.markedPos
end

local function onSave(): SaveData -- called when the game saves, even if currently in an inactive state
	return {
		version = ScriptVersion,
		markedPos = RECALL_LOC
	}
end

local function onLoad(data: SaveData) -- called only when the script loads, not the saved game. will not be called if the script was not previously saved
	if (not data) or (not data.version) or (data.version < ScriptVersion) then
		print('Was saved with an old version of the script, initializing to default')
		RECALL_LOC = INIT_DATA.markedPos
		return
	elseif (data.version > ScriptVersion) then
		error('Required update to a new version of the script')
	elseif (data.version == ScriptVersion) then
		RECALL_LOC = data.markedPos
	else

	end
end

local function retrieveMWVar(varName: string): number
	return core.sendGlobalEvent("fetchMWVar", {varName, selfObj})
end

local function updateMWVar(data: {string, number})
	core.sendGlobalEvent("updateMWVar", {data, selfObj})
end

local function triggerShiesFledQuest() -- used to trigger the shies fled quest. should only be triggered once
	local players = nearby.players
	for i = 1, #players do
		players[i]:sendEvent("shiesFled", nil)
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

local function getPlayerCellPos(): CellLoc
	local players = nearby.players
	for i = 1, #players do
		if (players[i]) then
			return {cellId = players[i].cell.name, cellPos = players[i].position}
		end
	end
end

local function getCoDist(vector1:util.Vector3, vector2: util.Vector3): number
	local tempVar1: number
	local tempVar2: number
	tempVar1 = vector1.x - vector2.x
	tempVar1 = tempVar1 * tempVar1
	tempVar2 = vector1.y - vector2.y
	tempVar2 = tempVar2 * tempVar2
	tempVar1 = tempVar1 + tempVar2
	return math.sqrt(tempVar1)
end

local posA: CellLoc
local posB: CellLoc
local posC: CellLoc
local doOnce = false
local doOnce2 = false
local coDist: number
local coDist2: number

local function warpToPlayer() -- If the player gets too far from shies, teleport shies closer to the player
	if ai.getActivePackage().type == "Follow" then
		local warpVar = retrieveMWVar("warp")
		posA = getPlayerCellPos()

		if doOnce == false then
			posB = getPlayerCellPos()
			doOnce = true
		end

		coDist = getCoDist(posA, posB)
		if coDist > 360 then
			doOnce = false
		end

		if coDist > 180 then
			if doOnce2 == false then
				posC = getPlayerCellPos()
				doOnce2 = true
			end
		end

		coDist2 = getCoDist(posA, posC)
		if coDist2 > 360 then
			doOnce2 = false
		end

		if warpVar == 0 then
			if getCoDist(self.object.position, getPlayerCellPos().cellPos) > 680 then
				if coDist > 350 then
					core.sendGlobalEvent("teleport", {
						actor = selfObj,
						cell = posC.cellId,
						position = posC.cellPos
					})
				elseif coDist2 > 350 then
					core.sendGlobalEvent("teleport", {
						actor = selfObj,
						cell = posB.cellId,
						position = posB.cellPos
					})
				end
			end
		end
	end
end
--[[
; this block teleports the NPC to the player if the player gets too far away
if ( GetCurrentAIPackage == 3 )
  if ( warp == 0 )
    if ( GetDistance Player > 680 )
      if ( coDist > 350 )
        SetPos, x, cx
        SetPos, y, cy
        SetPos, z, cz
        AiFollow, Player, 0, 0, 0, 0
      elseif (coDist2 > 350)
        SetPos, x, bx
        SetPos, y, by
        SetPos, z, bz
        AiFollow, Player, 0, 0, 0, 0
      endif
    endif
  endif
endif]]

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
			if RECALL_LOC == INIT_DATA.markedPos then
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
			warpToPlayer()
            if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
				updateMWVar({"companion", 0})
				updateMWVar({"c_move", 0})
                flee() -- Teleport Shies away from combat to whatever position he has marked
    			heal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
            end
        end,
		onInit = onInit,
		onSave = onSave,
		onLoad = onLoad,
    },
    eventHandlers = {
        ["Hit"] = function(attack: I.Combat.AttackInfo) -- example of sending an event (with a message) back to the player that hit him
            local attackerObj = attack.attacker as core.GameObject
            attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
        end,
        ["hurtShies"] = function() -- for testing the "Recall away at low health" feature - this event is sent from the player script
            health(selfObj).current = 1
        end,
    }
}