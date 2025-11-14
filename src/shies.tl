-- meta info
local scriptVersion = 1 -- increment whenever onSave is changed
--

-- all requires
local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
--

-- custom types and interfaces
local interface RecallLoc
	recallCellId: string
	recallPos: util.Vector3
end

local interface SaveData
	version: number
	markedPos: RecallLoc
end
--

-- variables
local INIT_DATA: SaveData = {markedPos = {recallCellId = "Balmora, Council Club", recallPos = util.vector3(-5, -218, -251)}}
local FLEE_THRESHOLD = 0.1
local RECALL_LOC: RecallLoc
--local RECALL_CELL_IDS = {"Balmora, Council Club", "Balmora, Lucky Lockup"}
--local RECALL_POSITIONS = {util.vector3(-5, -218, -251), util.vector3(-189, 267, -506)}
local RECALL_TIMEOUT = 2 * time.second
local health = types.Actor.stats.dynamic.health
local selfObj = self as core.GameObject
--

-- functions
-- called when the script is created but not loaded
local function onInit()
	RECALL_LOC = INIT_DATA.markedPos
end

-- called when the game saves, even if currently in an inactive state
local function onSave(): SaveData
	return {
		version = scriptVersion,
		markedPos = RECALL_LOC
	}
end

-- called only when the script loads, not the saved game. will not be called if the script was not previously saved
local function onLoad(data: SaveData)
	if (not data) or (not data.version) or (data.version < scriptVersion) then
		print('Was saved with an old version of the script, initializing to default')
		RECALL_LOC = {recallCellId = "Balmora, Council Club", recallPos = util.vector3(-5, -218, -251)}
		return
	elseif (data.version > scriptVersion) then
		error('Required update to a new version of the script')
	elseif (data.version == scriptVersion) then
		RECALL_LOC = data.markedPos
	else

	end
end

--[[ this function relies on openmw.world, which is only available to global scripts. need to look at later
-- used to trigger the shies fled quest. should only be triggered once
local function triggerShiesFledQuest()
	local players = world.players
	for i = 1, #players do
		if types.Player.quests(players[i]) then

		end
	end
	--core.sendGlobalEvent("shiesFled", )
end]]

local function getCurrentHealth(): number
    return health(selfObj).current
end

local function getMaxHealth(): number
    return health(selfObj).base + health(selfObj).modifier
end

local function heal()
    health(selfObj).current = getMaxHealth()
end

local function flee()
    -- Trigger the Recall vfx
    local vfx = core.magic.effects.records["recall"]
    selfObj:sendEvent('AddVfx', {
        model = types.Static.record(vfx.hitStatic).model,
        options = {
            vfxId = "vfxShiesFlee",
            particleTextureOverride = vfx.particle,
            loop = false,
        }
    })
    
    -- Teleport away after RECALL_TIMEOUT seconds
    local cb = time.registerTimerCallback(
        selfObj.id .. "_FleeCallback",
        function(actor: core.GameObject)
			ai.removePackages("Combat")
			ai.removePackages("Follow")
            return core.sendGlobalEvent("teleport", {
				actor = actor,
				cell = RECALL_LOC.recallCellId,
				position = RECALL_LOC.recallPos
			})
			--[[
            -- Things break if you teleport an NPC to the same cell they're already in
			-- So we need to find the first uninhabited cell from a list of potential suitors
            for i, cell in ipairs(RECALL_CELL_IDS) do
                if string.lower(cell) ~= actor.cell.id then
                    -- No distractions
                    ai.removePackages("Combat")
                    ai.removePackages("Follow")
                    return core.sendGlobalEvent("teleport", {
                        actor = actor,
                        cell = cell,
                        position = RECALL_POSITIONS[i]
                    })
                end
            end]]
        end,
        nil
    )
    time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end

return {
    engineHandlers = {
        onUpdate = function()
            if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
				-- Teleport Shies away from combat to whatever position he has marked
                flee()
				-- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
    			heal()
            end
        end,
		onTeleported = function()
			if RECALL_LOC == INIT_DATA.markedPos then
				-- The player has not changed Shies' marked location. This likely means the Shies Fled quest has not been started yet; we can further check by checking the player's journal entries
				--triggerShiesFledQuest()
			end
		end,
		onInit = onInit,
		onSave = onSave,
		onLoad = onLoad,
    },
    eventHandlers = {
        -- example of sending an event (with a message) back to the player that hit him
        ["Hit"] = function(attack: I.Combat.AttackInfo)
            local attackerObj = attack.attacker as core.GameObject
            attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
        end,
        -- for testing the "Recall away at low health" feature - this event is sent from the player script
        ["hurtShies"] = function()
            health(selfObj).current = 1
        end,
    }
}