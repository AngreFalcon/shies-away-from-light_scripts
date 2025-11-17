local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')













local health = types.Actor.stats.dynamic.health
local selfObj = self



local ScriptVersion = 1

local cMove = false
local flyCheck = false
local wwCheck = false
local combatCheck = false

local moveTimer = 0
local sheatheTimer = 0
local warpTimer = 0
local counter = 0



local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA = { recallLoc = { cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251) } }



local RECALL_LOC
local playerSneaking = false



local posA
local posB
local posC
local doOnce = false
local doOnce2 = false



local MWVars = {}


local function updateMWVar(varName, varData)
   core.sendGlobalEvent("updateMWVar", { varName, varData, selfObj })
end

local function onInit()
   RECALL_LOC = INIT_DATA.recallLoc
end

local function onSave()
   for k, v in pairs(MWVars) do
      updateMWVar(k, v)
   end
   return {
      version = ScriptVersion,
      recallLoc = RECALL_LOC,
   }
end

local function onLoad(data)
   if (not data) or (not data.version) or (data.version < ScriptVersion) then
      print('Was saved with an old version of the script, initializing to default')
      RECALL_LOC = INIT_DATA.recallLoc
      return
   elseif (data.version > ScriptVersion) then
      error('Required update to a new version of the script')
   elseif (data.version == ScriptVersion) then
      RECALL_LOC = data.recallLoc
   else

   end
end

local function getCurrentHealth()
   return health(selfObj).current
end

local function getMaxHealth()
   return health(selfObj).base + health(selfObj).modifier
end

local function heal()
   health(selfObj).current = getMaxHealth()
end

local function isShiesFollowing()
   local currentPackage = ai.getActivePackage()
   return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

local function getPlayerLeader()
   if isShiesFollowing() then
      return ai.getActiveTarget("Follow")
   end
end

local function getPlayerCellPos()
   local player = getPlayerLeader()
   if player == nil then
      return nil
   else
      return { cellId = player.cell.name, cellPos = player.position }
   end
end

local function getCoDist(vector1, vector2)
   local tempVar1 = vector1.x - vector2.x
   local tempVar2 = vector1.y - vector2.y
   return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function setSneak()
   local player = getPlayerLeader()
   if player ~= nil then
      player:sendEvent("getSneakVal", selfObj)
   end
   if (selfObj).controls.sneak ~= playerSneaking then
      (selfObj).controls.sneak = playerSneaking
   end
end

local function triggerShiesFledQuest()
   local player = getPlayerLeader()
   if player ~= nil then
      player:sendEvent("shiesFled", nil)
   end
end

local function flee()
   local vfx = core.magic.effects.records["recall"]
   selfObj:sendEvent('AddVfx', {
      model = types.Static.record(vfx.hitStatic).model,
      options = {
         vfxId = "vfxShiesFlee",
         particleTextureOverride = vfx.particle,
         loop = false,
      },
   })

   local cb = time.registerTimerCallback(
   selfObj.id .. "_FleeCallback",
   function(actor)
      ai.removePackages("Combat")
      ai.removePackages("Follow")
      if RECALL_LOC == INIT_DATA.recallLoc then
         triggerShiesFledQuest()
      end
      return core.sendGlobalEvent("teleport", {
         actor = actor,
         cell = RECALL_LOC.cellId,
         position = RECALL_LOC.cellPos,
      })
   end,
   nil)

   time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end


local function setSheatheTimer(timePassed)
   if combatCheck == true then
      warpTimer = 6
      sheatheTimer = sheatheTimer - timePassed
      if core.sound.isSoundPlaying("Weapon Swish", selfObj) == true or
         core.sound.isSoundPlaying("crossbowShoot", selfObj) == true or
         core.sound.isSoundPlaying("bowShoot", selfObj) == true or
         core.sound.isSoundPlaying("mysticism cast", selfObj) == true or
         core.sound.isSoundPlaying("restoration cast", selfObj) == true or
         core.sound.isSoundPlaying("destruction cast", selfObj) == true or
         core.sound.isSoundPlaying("illusion cast", selfObj) == true then

         sheatheTimer = 4.4
      elseif sheatheTimer <= 0 then
         combatCheck = false
         if types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then

         else
            types.Actor.setStance(selfObj, types.Actor.STANCE.Nothing)
         end
      end
   elseif types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon or
      types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then

      combatCheck = true
      sheatheTimer = 4.4
      warpTimer = 6
   end
end

local function forceZLevel()
   local playerPos = (getPlayerCellPos())
   local shiesPos = selfObj.position
   if playerPos == nil then
      return
   end
   if flyCheck == true and types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon then
      core.sendGlobalEvent("teleport", {
         actor = selfObj,
         cell = selfObj.cell.name,
         position = util.vector3(shiesPos.x, shiesPos.y, playerPos.cellPos.z),
      })
   end
end

local function maintainDistance()
   local shiesPos = selfObj.position
   local playerPos = (getPlayerCellPos())
   if playerPos == nil then
      return
   end
   if isShiesFollowing() and MWVars["compmove"] == 1 and cMove == false and getCoDist(shiesPos, playerPos.cellPos) < 70 then
      ai.startPackage({
         type = "Wander",
         distance = 300,
      })
      cMove = true
   end
   if cMove == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
      ai.startPackage({
         type = "Follow",
         target = getPlayerLeader(),
      })
      cMove = false
   end
end

local function nudge(timePassed)
   if MWVars["onetimemove"] == 1 then
      moveTimer = moveTimer + timePassed
      if moveTimer > 4 then
         moveTimer = 0
         ai.startPackage({
            type = "Follow",
            target = getPlayerLeader(),
         })
         updateMWVar("onetimemove", 0)
      end
   end
end

local function warpToPlayer()
   posA = getPlayerCellPos()
   if posA == nil then
      return
   end

   if doOnce == false then
      posB = getPlayerCellPos()
      doOnce = true
   end

   local coDist = getCoDist((posA).cellPos, posB.cellPos)
   if coDist > 360 then
      doOnce = false
   end

   if (coDist > 180 and doOnce2 == false) or posC == nil then
      posC = getPlayerCellPos()
      doOnce2 = true
   end

   local coDist2 = getCoDist((posA).cellPos, (posC).cellPos)
   if coDist2 > 360 then
      doOnce2 = false
   end

   if warpTimer <= 0 and getCoDist(selfObj.position, (getPlayerCellPos()).cellPos) > 680 then
      if coDist > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = (posC).cellId,
            position = (posC).cellPos,
         })
         if isShiesFollowing() ~= true then
            ai.startPackage({
               type = "Follow",
               target = getPlayerLeader,
            })
         end
      elseif coDist2 > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = posB.cellId,
            position = posB.cellPos,
         })
         if isShiesFollowing() ~= true then
            ai.startPackage({
               type = "Follow",
               target = getPlayerLeader,
            })
         end
      end
   end
end

local function toggleLevitation()
   local playerLevitating = types.Actor.activeEffects(getPlayerLeader()):getEffect((core.magic.EFFECT_TYPE.Levitate), nil).magnitude
   if playerLevitating > 0 and flyCheck == false then
      types.Actor.activeEffects(selfObj):modify(playerLevitating, (core.magic.EFFECT_TYPE.Levitate), nil)
      flyCheck = true
   elseif playerLevitating <= 0 and flyCheck == true then
      local shiesLevitating = types.Actor.activeEffects(selfObj):getEffect((core.magic.EFFECT_TYPE.Levitate), nil).magnitude
      types.Actor.activeEffects(selfObj):modify(-(shiesLevitating), (core.magic.EFFECT_TYPE.Levitate), nil)
      flyCheck = false
   end
end

local function toggleWaterWalking()
   local playerWaterWalking = types.Actor.activeEffects(getPlayerLeader()):getEffect((core.magic.EFFECT_TYPE.WaterWalking), nil).magnitude
   if playerWaterWalking > 0 and wwCheck == false then
      types.Actor.activeEffects(selfObj):modify(playerWaterWalking, (core.magic.EFFECT_TYPE.WaterWalking), nil)
      wwCheck = true
   elseif playerWaterWalking <= 0 and wwCheck == true then
      local shiesWaterWalking = types.Actor.activeEffects(selfObj):getEffect((core.magic.EFFECT_TYPE.WaterWalking), nil).magnitude
      types.Actor.activeEffects(selfObj):modify(-(shiesWaterWalking), (core.magic.EFFECT_TYPE.WaterWalking), nil)
      wwCheck = false
   end
end



return {
   engineHandlers = {
      onUpdate = function(dt)
         getPlayerLeader()
         if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
            updateMWVar("companion", 0)
            cMove = false
            flee()
            heal()
         end


         warpTimer = warpTimer - dt
         setSheatheTimer(dt)
         if isShiesFollowing() then
            setSneak()
            toggleLevitation()
            toggleWaterWalking()
            forceZLevel()
            warpToPlayer()
         end

         maintainDistance()
         nudge(dt)

         if counter < 20 then
            counter = counter + 1
            return
         end
         counter = 0




      end,
      onInit = onInit,
      onSave = onSave,
      onLoad = onLoad,
   },
   eventHandlers = {
      ["fetchMWVars"] = function(data)
         MWVars = data
      end,
      ["Hit"] = function(attack)
         local attackerObj = attack.attacker
         attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
      end,
      ["hurtShies"] = function()
         health(selfObj).current = 1
      end,
      ["shiesActivated"] = function()
         for k, v in pairs(MWVars) do
            print(k)
            print(v)
            print("--")
         end
      end,
      ["playerSneak"] = function(sneaking)
         if sneaking ~= nil then
            playerSneaking = sneaking
         end
      end,
   },
}
