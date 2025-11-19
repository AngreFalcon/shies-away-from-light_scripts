local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local anim = require('openmw.animation')
local cmn = require('scripts.safl_shies.common')

-- Credit to Grumpy and Kateri for their companion mwscripts, which were used as the foundation for much of the below logic

-- aliases
local attributes = {types.Actor.stats.dynamic.health,types.Actor.stats.dynamic.magicka,types.Actor.stats.dynamic.fatigue}
local selfObj = self as core.GameObject

-- variables
local ScriptVersion = 1 -- increment whenever onSave is changed

local RECALL_LOC: cmn.CellLoc
local player: core.GameObject

local checks: {cmn.Flag: boolean} = {}
local potionsArr: {cmn.Potions} = {}
local timers: {cmn.Timer: number} = {}

local counter: number

-- constants
local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA: cmn.SaveData = {recallLoc = {cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251)}}

-- persistent variables

-- warp function variables - persistent
local posA: cmn.CellLoc
local posB: cmn.CellLoc
local posC: cmn.CellLoc
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
]]

local function updateMWVar(varName: string, varData: number) -- Send an event to the global script to update a single mwscript variable with the provided value
	core.sendGlobalEvent("updateMWVar", {varName, varData, selfObj})
end

local function getMaxAttr(attr: types.DynamicStat): number -- Get the maximum value of the specified dynamic stat
    return attr.base + attr.modifier
end

local function fullHeal() -- Fully restore shies' health
    attributes[1](selfObj).current = getMaxAttr(attributes[1](selfObj))
end

local function checkAttrDamaged(attr: types.DynamicStat): boolean
	return attr.current < getMaxAttr(attr)
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

local function makeShiesFollow() -- Helper function for setting the Follow AI package
	ai.startPackage({
		type = "Follow",
		target = player
	})
end

local function getPlayerCellPos(): cmn.CellLoc -- Get the cell location of the player that shies is currently following
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
	if (selfObj as self).controls.sneak ~= checks["playerSneak"] then
		(selfObj as self).controls.sneak = checks["playerSneak"]
	end
end

local function shiesIncapacitated()
	local animName = "deathknockdown"
	if checks["incapacitated"] == true and anim.isPlaying(selfObj, animName) == false then
		anim.playQueued(selfObj, animName, {})
		checks["incapacitated"] = false
	elseif checks["incapacitated"] == false then
		anim.cancel(selfObj, animName)
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
			if RECALL_LOC == INIT_DATA.recallLoc and (types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].started == false then
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
	if RECALL_LOC == INIT_DATA.recallLoc and (types.Player.quests(player) as {string: cmn.PlayerQuest})["SAFL_ShiesFled"].stage < 40 then -- The player has not recovered shies yet
		checks["incapacitated"] = true
	end
    time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end

local function setSheatheTimer(timePassed: number) -- Sheathe weapon after combat check
	if checks["combat"] == true then
		timers["warp"] = 6
		timers["sheathe"] = timers["sheathe"] - timePassed
		if core.sound.isSoundPlaying("Weapon Swish", selfObj) == true
			or core.sound.isSoundPlaying("crossbowShoot", selfObj) == true
			or core.sound.isSoundPlaying("bowShoot", selfObj) == true
			or core.sound.isSoundPlaying("mysticism cast", selfObj) == true
			or core.sound.isSoundPlaying("restoration cast", selfObj) == true
			or core.sound.isSoundPlaying("destruction cast", selfObj) == true
			or core.sound.isSoundPlaying("illusion cast", selfObj) == true
		then
			timers["sheathe"] = 4.4
		elseif timers["sheathe"] <= 0 then
			checks["combat"] = false
			if types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then
				-- cast levitation spell on player? not sure why
			else
				types.Actor.setStance(selfObj, types.Actor.STANCE.Nothing)
			end
		end
	elseif types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon
		or types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell
	then
		checks["combat"] = true
		timers["sheathe"] = 4.4
		timers["warp"] = 6
	end
end

local function forceZLevel() -- If in combat, levitating and the player Z level is different from shies', force shies' Z level to the player's
	local playerPos: cmn.CellLoc = (getPlayerCellPos() as cmn.CellLoc)
	local shiesPos = selfObj.position
	if checks["fly"] == true and types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon then
		core.sendGlobalEvent("teleport", {
			actor = selfObj,
			cell = selfObj.cell.name,
			position = util.vector3(shiesPos.x, shiesPos.y, playerPos.cellPos.z)
		})
	end
end

local function maintainDistance() -- Toggles shies between wandering and following the player in order to maintain a small window of distance from the player. works only if the player activates it from dialogue by updating the "compmove" variable
	local shiesPos = selfObj.position
	local playerPos: cmn.CellLoc = (getPlayerCellPos() as cmn.CellLoc)
	if playerPos == nil then
		return
	end
	if isShiesFollowing() and MWVars["compmove"] == 1 and checks["cMove"] == false and getCoDist(shiesPos, playerPos.cellPos) < 70 then
		ai.removePackages("Follow")
		ai.startPackage({
			type = "Wander",
			distance = 300
		})
		checks["cMove"] = true
	end
	if checks["cMove"] == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
		ai.removePackages("Wander")
		makeShiesFollow()
		checks["cMove"] = false
	end
end

local function nudge(timePassed: number) -- Waits 4 seconds before making shies follow the player again. onetimemove is set true in dialogue while simultaneously triggering the Wander AI package to make him move
	if MWVars["onetimemove"] == 1 then
		timers["move"] = timers["move"] + timePassed
		if timers["move"] > 4 then
			timers["move"] = 0
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
	
	local coDist = getCoDist((posA as cmn.CellLoc).cellPos, posB.cellPos)
	if coDist > 360 then
		doOnce = false
	end
	
	if (coDist > 180 and doOnce2 == false) or posC == nil then
		posC = getPlayerCellPos()
		doOnce2 = true
	end

	local coDist2 = getCoDist((posA as cmn.CellLoc).cellPos, (posC as cmn.CellLoc).cellPos)
	if coDist2 > 360 then
		doOnce2 = false
	end

	if timers["warp"] <= 0 and getCoDist(selfObj.position, (getPlayerCellPos() as cmn.CellLoc).cellPos) > 680 then
		if coDist > 350 then
			core.sendGlobalEvent("teleport", {
				actor = selfObj,
				cell = (posC as cmn.CellLoc).cellId,
				position = (posC as cmn.CellLoc).cellPos
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

local function toggleEffect(flag: cmn.Flag, effectType: string) -- This function should apply the levitate effect to shies if the player is levitating, and remove it if the player isn't
	local playerEffect = types.Actor.activeEffects(player):getEffect(effectType, nil).magnitude
	if playerEffect > 0 and checks[flag] == false then
		types.Actor.activeEffects(selfObj):modify(playerEffect, effectType, nil)
		checks[flag] = true
	elseif playerEffect <= 0 and checks[flag] == true then
		local shiesEffect = types.Actor.activeEffects(selfObj):getEffect(effectType, nil).magnitude
		types.Actor.activeEffects(selfObj):modify(-(shiesEffect), effectType, nil)
		checks[flag] = false
	end
end

local function modSpeedAndAthletics() -- Set shies' speed and athletics modifier to a flat 15 if he's within a certain distance of the player, or add a multiplier based off the player's stats if he's too far
	if getCoDist(selfObj.position, (getPlayerCellPos() as cmn.CellLoc).cellPos) < 300 then
		types.Actor.stats.attributes.speed(selfObj).modifier = 15
		types.NPC.stats.skills.athletics(selfObj).modifier = 15
	elseif getCoDist(selfObj.position, (getPlayerCellPos() as cmn.CellLoc).cellPos) > 300 then
		local cSpeed = types.Actor.stats.attributes.speed(selfObj).modified * 2.25
		local cAthletics = types.NPC.stats.skills.athletics(player).modified * 2.25
		types.Actor.stats.attributes.speed(selfObj).modifier = cSpeed
		types.NPC.stats.skills.athletics(selfObj).modifier = cAthletics
	end
end

local function checkForPotion(potionName: string): boolean -- Returns true if shies has any of the specified potions in his inventory
	local inventory = types.Actor.inventory(selfObj)
	return inventory:countOf(potionName) > 0
end

local function consumePotion(potionID: string, effectName: string): number -- Sends a global event to trigger shies to consume the specified potion. Returns the duration of whatever effect is specified, or 60 if the potion does not have that effect
	local potion = types.Actor.inventory(selfObj):find(potionID)
	local potionEffects = types.Potion.record(potion).effects
	local duration: number = 60
	if effectName ~= nil then
		for i = 1, #potionEffects do
			if potionEffects[i].effect.name == effectName then
				duration = potionEffects[i].duration
			end
		end
	end
	core.sendGlobalEvent("UseItem", {object = potion, actor = selfObj})
	return duration
end

local function selectBestPotion(attr: types.DynamicStat, potions: {cmn.PotionArr}): string -- Find the potion whose restore amount is closest to the amount missing from the specified attribute
	local potion: integer
	local attrDiff = getMaxAttr(attr) - attr.current
	for i = 1, #potions do
		if potions[i].count > 0 then
			if potion == nil then
				potion = i
			end
			for j = i + 1, #potions do
				if potions[j].count > 0 then
					if math.abs(attrDiff - potions[potion].magnitude) > math.abs(attrDiff - potions[j].magnitude) then
						potion = j
					end
				end
			end
		end
	end
	if ((potions[potion].magnitude / 4) >= attrDiff) and (attrDiff <= (getMaxAttr(attr) * 0.75)) then
		return nil -- If 3/4s or more of the potion's effect will be wasted, don't consume it unless shies is missing more than 3/4s of the attribute
	else
		return potions[potion].name
	end
end

local function shiesDrinkAttrPotion(potions: cmn.Potions, attr: types.DynamicStat): boolean -- Find the most applicable restore potion for the given attribute and then consume it. Returns false if a potion was not consumed
	if potions.check == true and potions.timer <= 0 then
		local potion = selectBestPotion(attr, potions.types)
		if potion ~= nil then
			potions.timer = consumePotion(potion, potions.effectName)
			return true
		else
			return false
		end
	end
end

local function checkAttrPotions(potions: cmn.Potions) -- Checks shies' inventory to update the count of restore health/magicka/stamina potions he has
	local inventory = types.Actor.inventory(selfObj)
	local count: number = 0
	for i = 1, #potions.types do
		potions.types[i].count = inventory:countOf(potions.types[i].name)
		count = count + potions.types[i].count
	end
	if count > 0 and potions.check == false then
		potions.check = true
	elseif count == 0 and potions.check == true then
		potions.check = false
	end
end

local function checkAttributes() -- Used to call various functions that affect shies' dynamic attributes like health, fatigue, magicka
	if attributes[1](selfObj).current > 0 and attributes[1](selfObj).current / getMaxAttr(attributes[1](selfObj)) < FLEE_THRESHOLD then -- Check health ratio
		updateMWVar("companion", 0)
		checks["cMove"] = false
        flee() -- Teleport Shies away from combat to whatever position he has marked
		fullHeal() -- Heal Shies to avoid the script triggering again, and also to ensure the player doesn't have to restore his health upon recovering him
		return
	end
	for i = 1, #attributes do
		if checkAttrDamaged(attributes[i](selfObj)) == true then
			checkAttrPotions(potionsArr[i])
			if potionsArr[i].check == false or shiesDrinkAttrPotion(potionsArr[i], attributes[i](selfObj)) == false then
				-- cast some sort of restorative spell on self
			end
		end
	end
end

local function freeFall() -- Used to call various functions that should trigger while shies is in freefall
	if timers["freefall"] > 1 and checkForPotion("p_slowfall_s") then
		timers["freefall"] = -(consumePotion("p_slowfall_s", "SlowFall"))
	end
end

local function setDefaultSpeed() -- Sets shies' speed modifier while not following the player
	types.Actor.stats.attributes.speed(selfObj).modifier = 40
end

local function updateTimers(dt: number)
	for i = 1, #potionsArr do
		potionsArr[i].timer = potionsArr[i].timer - dt
	end
	timers["warp"] = timers["warp"] - dt
	if ((checks["fly"] == false) and (types.Actor.isOnGround(selfObj) == false)) or timers["freefall"] < 0 then
		timers["freefall"] = timers["freefall"] + dt
	elseif timers["freefall"] > 0 then -- A negative timers["freefall"] implies a slowfall potion is active and the timer should not be reset
		timers["freefall"] = 0
	end
end

local function onUpdate(dt: number) -- called every frame while the script is loaded
	if core.isWorldPaused() == true then
		return
	end
	getPlayerLeader()
    checkAttributes()
	--shiesIncapacitated()

	if checks["fly"] == false and types.Actor.isOnGround(selfObj) == false then
		freeFall()
	end

	updateTimers(dt)
	setSheatheTimer(dt)

	if isShiesFollowing() then
		setSneak()
		toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate as string))
		toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking as string))
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
	elseif player ~= nil then
		setDefaultSpeed()
	end
end

local function onInit() -- Called when the script is created but not loaded
	RECALL_LOC = INIT_DATA.recallLoc
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
	counter = 0
	potionsArr[1] = {
		check = false,
		timer = 0,
		effectName = "Restore Health",
		types = {{
			name = "p_restore_health_b",
			count = 0,
			magnitude = 5
		},
		{
			name = "p_restore_health_c",
			count = 0,
			magnitude = 10
		},
		{
			name = "p_restore_health_s",
			count = 0,
			magnitude = 50
		},
		{
			name = "p_restore_health_q",
			count = 0,
			magnitude = 100
		},
		{
			name = "p_restore_health_e",
			count = 0,
			magnitude = 200
		}
	}}
	potionsArr[2] = {
		check = false,
		timer = 0,
		effectName = "Restore Magicka",
		types = {{
			name = "p_restore_magicka_b",
			count = 0,
			magnitude = 5
		},
		{
			name = "p_restore_magicka_c",
			count = 0,
			magnitude = 10
		},
		{
			name = "p_restore_magicka_s",
			count = 0,
			magnitude = 50
		},
		{
			name = "p_restore_magicka_q",
			count = 0,
			magnitude = 100
		},
		{
			name = "p_restore_magicka_e",
			count = 0,
			magnitude = 200
		}
	}}
	potionsArr[3] = {
		check = false,
		timer = 0,
		effectName = "Restore Fatigue",
		types = {{
			name = "p_restore_fatigue_b",
			count = 0,
			magnitude = 25
		},
		{
			name = "p_restore_fatigue_c",
			count = 0,
			magnitude = 50
		},
		{
			name = "p_restore_fatigue_s",
			count = 0,
			magnitude = 100
		},
		{
			name = "p_restore_fatigue_q",
			count = 0,
			magnitude = 200
		},
		{
			name = "p_restore_fatigue_e",
			count = 0,
			magnitude = 400
		}
	}}
	for i = 1, #potionsArr do
		checkAttrPotions(potionsArr[i])
	end
end

local function onSave(): cmn.SaveData -- Called when the game saves, even if currently in an inactive state
	for k, v in pairs(MWVars) do
		updateMWVar(k, v)
	end
	return {
		version = ScriptVersion,
		recallLoc = RECALL_LOC,
		player = player,
		checks = checks,
		doOnce = doOnce,
		doOnce2 = doOnce2,
		timers = timers,
		counter = counter,
		posA = posA,
		posB = posB,
		posC = posC,
		potionsArr = potionsArr,
	}
end

local function onLoad(data: cmn.SaveData) -- Called only when the script loads, not the saved game. will not be called if the script was not previously saved
	if (not data) or (not data.version) or (data.version < ScriptVersion) then
		print('Was saved with an old version of the script, initializing to default')
		RECALL_LOC = INIT_DATA.recallLoc
		return
	elseif (data.version > ScriptVersion) then
		error('Required update to a new version of the script')
	elseif (data.version == ScriptVersion) then
		RECALL_LOC = data.recallLoc
		player = data.player
		checks = data.checks
		doOnce = data.doOnce
		doOnce2 = data.doOnce2
		timers = data.timers
		counter = data.counter
		posA = data.posA
		posB = data.posB
		posC = data.posC
		potionsArr = data.potionsArr
	end
end

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
        ["Hit"] = function(attack: I.Combat.AttackInfo) -- example of sending an event (with a message) back to the player that hit him
            local attackerObj = attack.attacker as core.GameObject
            attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
        end,
        ["hurtShies"] = function() -- for testing the "Recall away at low health" feature - this event is sent from the player script
            attributes[1](selfObj).current = 1
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
				checks["playerSneak"] = sneaking
			end
		end,
    }
}