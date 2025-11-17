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
	player: core.GameObject
	cMove: boolean
	flyCheck: boolean
	wwCheck: boolean
	combatCheck: boolean
	pCheck: boolean
	playerSneaking: boolean
	doOnce: boolean
	doOnce2: boolean
	moveTimer: number
	sheatheTimer: number
	warpTimer: number
	counter: number
	potionTimer: number
	posA: CellLoc
	posB: CellLoc
	posC: CellLoc
	potions: {{string, number, number}}
end

-- aliases
local health = types.Actor.stats.dynamic.health
local selfObj = self as core.GameObject

-- variables
local ScriptVersion = 1 -- increment whenever onSave is changed

local cMove: boolean
local flyCheck: boolean
local wwCheck: boolean
local combatCheck: boolean
local pCheck: boolean

local moveTimer: number
local sheatheTimer: number
local warpTimer: number
local counter: number
local potionTimer: number

local potions: {{string, number, number}} = {}

-- constants
local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA: SaveData = {recallLoc = {cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251)}}

-- persistent variables
local RECALL_LOC: CellLoc
local player: core.GameObject
local playerSneaking: boolean

-- warp function variables - persistent
local posA: CellLoc
local posB: CellLoc
local posC: CellLoc
local doOnce: boolean
local doOnce2: boolean

-- mwscript variables - persistent
-- important to note: all MWScript variables are automatically cast to all lowercase
local MWVars: {string: number} = {}
--[[
variables:
short companion -- engine variable -- true if shies is currently following the player. if 0, companion dialogue topics don't appear
short nohello -- engine variable -- 
short nolore -- engine variable --
short fled -- true if shies has teleported away during combat
short compmove -- true if the player has asked shies to maintain his distance
short onetimemove -- true if the player has asked shies to move out of the way
short weapuse -- true if the player has asked shies to use the same weapons as the player
short addonce -- true after the mwscript has executed once, is used to initialize companion to 0
short p_b_count -- number of bargain healing potions in shies' inventory - restores ~5 hitpoints
short p_c_count -- number of cheap healing potions in shies' inventory - restore ~10 hitpoints
short p_s_count -- number of standard healing potions in shies' inventory - restores ~50 hitpoints
short p_q_count -- number of quality healing potions in shies' inventory - restores ~100 hitpoints
short p_e_count -- number of exclusive healing potions in shies' inventory - restores ~200 hitpoints
]]

local function updateMWVar(varName: string, varData: number) -- Send an event to the global script to update a single mwscript variable with the provided value
	core.sendGlobalEvent("updateMWVar", {varName, varData, selfObj})
end

local function onInit() -- Called when the script is created but not loaded
	RECALL_LOC = INIT_DATA.recallLoc
	cMove = false
	flyCheck = false
	wwCheck = false
	combatCheck = false
	pCheck = false
	playerSneaking = false
	doOnce = false
	doOnce2 = false
	moveTimer = 0
	sheatheTimer = 0
	warpTimer = 0
	counter = 0
	potionTimer = 0
	potions[1] = {"p_restore_health_b", 0, 5}
	potions[2] = {"p_restore_health_c", 0, 10}
	potions[3] = {"p_restore_health_s", 0, 50}
	potions[4] = {"p_restore_health_q", 0, 100}
	potions[5] = {"p_restore_health_e", 0, 200}
end

local function onSave(): SaveData -- Called when the game saves, even if currently in an inactive state
	for k, v in pairs(MWVars) do
		updateMWVar(k, v)
	end
	return {
		version = ScriptVersion,
		recallLoc = RECALL_LOC,
		player = player,
		cMove = cMove,
		flyCheck = flyCheck,
		wwCheck = wwCheck,
		combatCheck = combatCheck,
		pCheck = pCheck,
		playerSneaking = playerSneaking,
		doOnce = doOnce,
		doOnce2 = doOnce2,
		moveTimer= moveTimer,
		sheatheTimer = sheatheTimer,
		warpTimer = warpTimer,
		counter = counter,
		potionTimer = potionTimer,
		posA = posA,
		posB = posB,
		posC = posC,
		potions = potions,
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
		player = data.player
		cMove = data.cMove
		flyCheck = data.flyCheck
		wwCheck = data.wwCheck
		combatCheck = data.combatCheck
		pCheck = data.pCheck
		playerSneaking = data.playerSneaking
		doOnce = data.doOnce
		doOnce2 = data.doOnce2
		moveTimer= data.moveTimer
		sheatheTimer = data.sheatheTimer
		warpTimer = data.warpTimer
		counter = data.counter
		potionTimer = data.potionTimer
		posA = data.posA
		posB = data.posB
		posC = data.posC
		potions = data.potions
	end
end

local function getCurrentHealth(): number
    return health(selfObj).current
end

local function getMaxHealth(): number
    return health(selfObj).base + health(selfObj).modifier
end

local function fullHeal()
    health(selfObj).current = getMaxHealth()
end

local function isShiesHurt(): boolean
	return getCurrentHealth() < getMaxHealth()
end

local function consumePotion(potionID: string): number
	local potion = types.Actor.inventory(selfObj):find(potionID)
	local potionEffects = types.Potion.record(potion).effects
	local duration: number = 60
	for i = 1, #potionEffects do
		if potionEffects[i].effect.name == "Restore Health" then
			duration = potionEffects[i].duration
		end
	end
	core.sendGlobalEvent("UseItem", {object = potion, actor = selfObj})
	return duration
end

local function selectBestPotion(): string
	local missingHealth = getMaxHealth() - getCurrentHealth()
	local potion: integer
	for i = 1, #potions do
		if potions[i][2] > 0 then -- only execute if shies actually has any potions of this type
			if potion == nil then
				potion = i
			end
			for j = i + 1, #potions do
				if potions[j][2] > 0 then
					if math.abs(missingHealth - potions[potion][3]) > math.abs(missingHealth - potions[j][3]) then
						potion = j
					end
				end
			end
		end
	end
	return potions[potion][1]
end

local function shiesDrinkPotion()
	if pCheck == true and potionTimer <= 0 then
		local potion = selectBestPotion()
		potionTimer = consumePotion(potion)
	elseif potionTimer > 0 then
	end
end

local function isShiesFollowing(): boolean -- Simply return true or false if shies is currently following any player
	local currentPackage = ai.getActivePackage()
	return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

local function getPlayerLeader() -- Gets the player object that shies is currently following
	if isShiesFollowing() then
		player = ai.getActiveTarget("Follow")
	end
end

local function makeShiesFollow()
	ai.startPackage({
		type = "Follow",
		target = player
	})
end

local function getPlayerCellPos(): CellLoc -- Get the cell location of the player that shies is currently following
	return {cellId = player.cell.name, cellPos = player.position}
end

local function getCoDist(vector1: util.Vector3, vector2: util.Vector3): number -- Get cosine distance between two vectors
	local tempVar1 = vector1.x - vector2.x
	local tempVar2 = vector1.y - vector2.y
	return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function setSneak() -- Make sure if the player is sneaking, shies sneaks as well
	if player ~= nil then
		player:sendEvent("getSneakVal", selfObj)
	end
	if (selfObj as self).controls.sneak ~= playerSneaking then
		(selfObj as self).controls.sneak = playerSneaking
	end
end

local function triggerShiesFledQuest() -- Used to trigger the shies fled quest. Should only be triggered once
	if player ~= nil then
		player:sendEvent("shiesFled", nil)
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

-- mwscript logic below
local function setSheatheTimer(timePassed: number) -- Sheathe weapon after combat check
	if combatCheck == true then
		warpTimer = 6
		sheatheTimer = sheatheTimer - timePassed
		if core.sound.isSoundPlaying("Weapon Swish", selfObj) == true
			or core.sound.isSoundPlaying("crossbowShoot", selfObj) == true
			or core.sound.isSoundPlaying("bowShoot", selfObj) == true
			or core.sound.isSoundPlaying("mysticism cast", selfObj) == true
			or core.sound.isSoundPlaying("restoration cast", selfObj) == true
			or core.sound.isSoundPlaying("destruction cast", selfObj) == true
			or core.sound.isSoundPlaying("illusion cast", selfObj) == true
		then
			sheatheTimer = 4.4
		elseif sheatheTimer <= 0 then
			combatCheck = false
			if types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then
				-- cast levitation spell on player? not sure why
			else
				types.Actor.setStance(selfObj, types.Actor.STANCE.Nothing)
			end
		end
	elseif types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon
		or types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell
	then
		combatCheck = true
		sheatheTimer = 4.4
		warpTimer = 6
	end
end

local function forceZLevel() -- If in combat, levitating and the player Z level is different from shies', force shies' Z level to the player's
	local playerPos: CellLoc = (getPlayerCellPos() as CellLoc)
	local shiesPos = selfObj.position
	if flyCheck == true and types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon then
		core.sendGlobalEvent("teleport", {
			actor = selfObj,
			cell = selfObj.cell.name,
			position = util.vector3(shiesPos.x, shiesPos.y, playerPos.cellPos.z)
		})
	end
end

local function maintainDistance() -- Toggles shies between wandering and following the player in order to maintain a small window of distance from the player. works only if the player activates it from dialogue by updating the "compmove" variable
	local shiesPos = selfObj.position
	local playerPos: CellLoc = (getPlayerCellPos() as CellLoc)
	if playerPos == nil then
		return
	end
	if isShiesFollowing() and MWVars["compmove"] == 1 and cMove == false and getCoDist(shiesPos, playerPos.cellPos) < 70 then
		ai.removePackages("Follow")
		ai.startPackage({
			type = "Wander",
			distance = 300
		})
		cMove = true
	end
	if cMove == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
		ai.removePackages("Wander")
		makeShiesFollow()
		cMove = false
	end
end

local function nudge(timePassed: number) -- Waits 4 seconds before making shies follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make him move
	if MWVars["onetimemove"] == 1 then
		moveTimer = moveTimer + timePassed
		if moveTimer > 4 then
			moveTimer = 0
			makeShiesFollow()
			updateMWVar("onetimemove", 0)
		end
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

	if warpTimer <= 0 and getCoDist(selfObj.position, (getPlayerCellPos() as CellLoc).cellPos) > 680 then
		if coDist > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = (posC as CellLoc).cellId,
				position = (posC as CellLoc).cellPos
			})
			makeShiesFollow()
		elseif coDist2 > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = posB.cellId,
				position = posB.cellPos
			})
			makeShiesFollow()
		end
	end
end

local function toggleLevitation() -- This function should apply the levitate effect to shies if the player is levitating, and remove it if the player isn't
	local playerLevitating = types.Actor.activeEffects(player):getEffect((core.magic.EFFECT_TYPE.Levitate as string), nil).magnitude
	if playerLevitating > 0 and flyCheck == false then
		types.Actor.activeEffects(selfObj):modify(playerLevitating, (core.magic.EFFECT_TYPE.Levitate as string), nil)
		flyCheck = true
	elseif playerLevitating <= 0 and flyCheck == true then
		local shiesLevitating = types.Actor.activeEffects(selfObj):getEffect((core.magic.EFFECT_TYPE.Levitate as string), nil).magnitude
		types.Actor.activeEffects(selfObj):modify(-(shiesLevitating), (core.magic.EFFECT_TYPE.Levitate as string), nil)
		flyCheck = false
	end
end

local function toggleWaterWalking() -- This function should apply the waterwalking effect to shies if the player is waterwalking, and remove it if the player isn't
	local playerWaterWalking = types.Actor.activeEffects(player):getEffect((core.magic.EFFECT_TYPE.WaterWalking as string), nil).magnitude
	if playerWaterWalking > 0 and wwCheck == false then
		types.Actor.activeEffects(selfObj):modify(playerWaterWalking, (core.magic.EFFECT_TYPE.WaterWalking as string), nil)
		wwCheck = true
	elseif playerWaterWalking <= 0 and wwCheck == true then
		local shiesWaterWalking = types.Actor.activeEffects(selfObj):getEffect((core.magic.EFFECT_TYPE.WaterWalking as string), nil).magnitude
		types.Actor.activeEffects(selfObj):modify(-(shiesWaterWalking), (core.magic.EFFECT_TYPE.WaterWalking as string), nil)
		wwCheck = false
	end
end

local function modSpeedAndAthletics()
	if getCoDist(selfObj.position, (getPlayerCellPos() as CellLoc).cellPos) < 300 then
		types.Actor.stats.attributes.speed(selfObj).modifier = 15
		types.NPC.stats.skills.athletics(selfObj).modifier = 15
	elseif getCoDist(selfObj.position, (getPlayerCellPos() as CellLoc).cellPos) > 300 then
		local cSpeed = types.Actor.stats.attributes.speed(selfObj).modified * 2.25
		local cAthletics = types.NPC.stats.skills.athletics(player).modified * 2.25
		types.Actor.stats.attributes.speed(selfObj).modifier = cSpeed
		types.NPC.stats.skills.athletics(selfObj).modifier = cAthletics
	end
end

local function hasPotions()
	local inventory = types.Actor.inventory(selfObj)
	local bPotion = inventory:countOf("p_restore_health_b")
	local cPotion = inventory:countOf("p_restore_health_c")
	local sPotion = inventory:countOf("p_restore_health_s")
	local qPotion = inventory:countOf("p_restore_health_q")
	local ePotion = inventory:countOf("p_restore_health_e")

	if potions[1][2] ~= bPotion then
		potions[1][2] = bPotion
	end
	if potions[2][2] ~= cPotion then
		potions[2][2] = cPotion
	end
	if potions[3][2] ~= sPotion then
		potions[3][2] = sPotion
	end
	if potions[4][2] ~= qPotion then
		potions[4][2] = qPotion
	end
	if potions[5][2] ~= ePotion then
		potions[5][2] = ePotion
	end

	if (bPotion + cPotion + sPotion + qPotion + ePotion) > 0 and pCheck == false then
		pCheck = true
	elseif (bPotion + cPotion + sPotion + qPotion + ePotion) == 0 and pCheck == true then
		pCheck = false
	end
end

local function setWanderSpeed()
	types.Actor.stats.attributes.speed(selfObj).modifier = 40
end
-- mwscript logic above

return {
    engineHandlers = {
        onUpdate = function(dt: number)
			getPlayerLeader()
			if isShiesHurt() then
				shiesDrinkPotion()
			end
            
			if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
				updateMWVar("companion", 0)
				cMove = false
                flee() -- Teleport Shies away from combat to whatever position he has marked
    			fullHeal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
            end

			potionTimer = potionTimer - dt
			warpTimer = warpTimer - dt
			setSheatheTimer(dt)
			if isShiesFollowing() then
				setSneak()
				toggleLevitation()
				toggleWaterWalking()
				forceZLevel()
				warpToPlayer()
			elseif player ~= nil then
				maintainDistance()
				nudge(dt)
			end

			if counter < 20 then
				counter = counter + 1
				return
			end
			counter = 0

			if isShiesFollowing() then
				modSpeedAndAthletics()
				hasPotions()
			elseif player ~= nil then
				setWanderSpeed()
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
		["shiesActivated"] = function()
		 	for k, v in pairs(MWVars) do
				print(k)
				print(v)
				print("--")
		 	end
		end,
		["playerSneak"] = function(sneaking: boolean)
			if sneaking ~= nil then
				playerSneaking = sneaking
			end
		end,
    }
}