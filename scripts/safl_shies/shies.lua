local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')










































local health = types.Actor.stats.dynamic.health
local magicka = types.Actor.stats.dynamic.magicka
local fatigue = types.Actor.stats.dynamic.fatigue
local selfObj = self


local ScriptVersion = 1

local cMove
local flyCheck
local wwCheck
local combatCheck

local moveTimer
local sheatheTimer
local warpTimer
local counter

local hPotions = {}
local mPotions = {}
local fPotions = {}


local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA = { recallLoc = { cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251) } }


local RECALL_LOC
local player
local playerSneaking


local posA
local posB
local posC
local doOnce
local doOnce2



local MWVars = {}












local function updateMWVar(varName, varData)
   core.sendGlobalEvent("updateMWVar", { varName, varData, selfObj })
end

local function onInit()
   RECALL_LOC = INIT_DATA.recallLoc
   cMove = false
   flyCheck = false
   wwCheck = false
   combatCheck = false
   playerSneaking = false
   doOnce = false
   doOnce2 = false
   moveTimer = 0
   sheatheTimer = 0
   warpTimer = 0
   counter = 0
   hPotions = {
      check = false,
      timer = 0,
      count = { {
         name = "p_restore_health_b",
         count = 0,
         magnitude = 5,
      },
      {
         name = "p_restore_health_c",
         count = 0,
         magnitude = 10,
      },
      {
         name = "p_restore_health_s",
         count = 0,
         magnitude = 50,
      },
      {
         name = "p_restore_health_q",
         count = 0,
         magnitude = 100,
      },
      {
         name = "p_restore_health_e",
         count = 0,
         magnitude = 200,
      },
      }, }
   mPotions = {
      check = false,
      timer = 0,
      count = { {
         name = "p_restore_magicka_b",
         count = 0,
         magnitude = 5,
      },
      {
         name = "p_restore_magicka_c",
         count = 0,
         magnitude = 10,
      },
      {
         name = "p_restore_magicka_s",
         count = 0,
         magnitude = 50,
      },
      {
         name = "p_restore_magicka_q",
         count = 0,
         magnitude = 100,
      },
      {
         name = "p_restore_magicka_e",
         count = 0,
         magnitude = 200,
      },
      }, }
   fPotions = {
      check = false,
      timer = 0,
      count = { {
         name = "p_restore_fatigue_b",
         count = 0,
         magnitude = 25,
      },
      {
         name = "p_restore_fatigue_c",
         count = 0,
         magnitude = 50,
      },
      {
         name = "p_restore_fatigue_s",
         count = 0,
         magnitude = 100,
      },
      {
         name = "p_restore_fatigue_q",
         count = 0,
         magnitude = 200,
      },
      {
         name = "p_restore_fatigue_e",
         count = 0,
         magnitude = 400,
      },
      }, }
end

local function onSave()
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
      playerSneaking = playerSneaking,
      doOnce = doOnce,
      doOnce2 = doOnce2,
      moveTimer = moveTimer,
      sheatheTimer = sheatheTimer,
      warpTimer = warpTimer,
      counter = counter,
      posA = posA,
      posB = posB,
      posC = posC,
      hPotions = hPotions,
      mPotions = mPotions,
      fPotions = fPotions,
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
      player = data.player
      cMove = data.cMove
      flyCheck = data.flyCheck
      wwCheck = data.wwCheck
      combatCheck = data.combatCheck
      playerSneaking = data.playerSneaking
      doOnce = data.doOnce
      doOnce2 = data.doOnce2
      moveTimer = data.moveTimer
      sheatheTimer = data.sheatheTimer
      warpTimer = data.warpTimer
      counter = data.counter
      posA = data.posA
      posB = data.posB
      posC = data.posC
      hPotions = data.hPotions
      mPotions = data.mPotions
      fPotions = data.fPotions
   end
end

local function getCurrentHealth()
   return health(selfObj).current
end

local function getMaxHealth()
   return health(selfObj).base + health(selfObj).modifier
end

local function getCurrentMagicka()
   return magicka(selfObj).current
end

local function getMaxMagicka()
   return magicka(selfObj).base + magicka(selfObj).modifier
end

local function getCurrentFatigue()
   return fatigue(selfObj).current
end

local function getMaxFatigue()
   return fatigue(selfObj).base + fatigue(selfObj).modifier
end

local function fullHeal()
   health(selfObj).current = getMaxHealth()
end

local function isShiesHurt()
   return getCurrentHealth() < getMaxHealth()
end

local function isShiesMagickaFull()
   return getCurrentMagicka() < getMaxMagicka()
end

local function isShiesStaminaFull()
   return getCurrentFatigue() < getMaxFatigue()
end

local function consumePotion(potionID)
   local potion = types.Actor.inventory(selfObj):find(potionID)
   local potionEffects = types.Potion.record(potion).effects
   local duration = 60
   for i = 1, #potionEffects do
      if potionEffects[i].effect.name == "Restore Health" then
         duration = potionEffects[i].duration
      end
   end
   core.sendGlobalEvent("UseItem", { object = potion, actor = selfObj })
   return duration
end

local function selectBestPotion(statDiff, potions)
   local potion
   for i = 1, #potions do
      if potions[i].count > 0 then
         if potion == nil then
            potion = i
         end
         for j = i + 1, #potions do
            if potions[j].count > 0 then
               if math.abs(statDiff - potions[potion].magnitude) > math.abs(statDiff - potions[j].magnitude) then
                  potion = j
               end
            end
         end
      end
   end
   return potions[potion].name
end

local function shiesDrinkAttrPotion(potions, attrMax, attrCurrent)
   if potions.check == true and potions.timer <= 0 then
      local potion = selectBestPotion(attrMax - attrCurrent, potions.count)
      potions.timer = consumePotion(potion)
   elseif potions.timer > 0 then
   end
end

local function shiesRestoreAttr()
   if isShiesHurt() then
      shiesDrinkAttrPotion(hPotions, getMaxHealth(), getCurrentHealth())
   end
   if isShiesMagickaFull() then
      shiesDrinkAttrPotion(mPotions, getMaxMagicka(), getCurrentMagicka())
   end
   if isShiesStaminaFull() then
      shiesDrinkAttrPotion(fPotions, getMaxFatigue(), getCurrentFatigue())
   end
end

local function isShiesFollowing()
   local currentPackage = ai.getActivePackage()
   return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

local function getPlayerLeader()
   if isShiesFollowing() then
      player = ai.getActiveTarget("Follow")
   end
end

local function makeShiesFollow()
   ai.startPackage({
      type = "Follow",
      target = player,
   })
end

local function getPlayerCellPos()
   return { cellId = player.cell.name, cellPos = player.position }
end

local function getCoDist(vector1, vector2)
   local tempVar1 = vector1.x - vector2.x
   local tempVar2 = vector1.y - vector2.y
   return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function setSneak()
   if player ~= nil then
      player:sendEvent("getSneakVal", selfObj)
   end
   if (selfObj).controls.sneak ~= playerSneaking then
      (selfObj).controls.sneak = playerSneaking
   end
end

local function triggerShiesFledQuest()
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
      ai.removePackages("Follow")
      ai.startPackage({
         type = "Wander",
         distance = 300,
      })
      cMove = true
   end
   if cMove == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
      ai.removePackages("Wander")
      makeShiesFollow()
      cMove = false
   end
end

local function nudge(timePassed)
   if MWVars["onetimemove"] == 1 then
      moveTimer = moveTimer + timePassed
      if moveTimer > 4 then
         moveTimer = 0
         makeShiesFollow()
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
         makeShiesFollow()
      elseif coDist2 > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = posB.cellId,
            position = posB.cellPos,
         })
         makeShiesFollow()
      end
   end
end

local function toggleLevitation()
   local playerLevitating = types.Actor.activeEffects(player):getEffect((core.magic.EFFECT_TYPE.Levitate), nil).magnitude
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
   local playerWaterWalking = types.Actor.activeEffects(player):getEffect((core.magic.EFFECT_TYPE.WaterWalking), nil).magnitude
   if playerWaterWalking > 0 and wwCheck == false then
      types.Actor.activeEffects(selfObj):modify(playerWaterWalking, (core.magic.EFFECT_TYPE.WaterWalking), nil)
      wwCheck = true
   elseif playerWaterWalking <= 0 and wwCheck == true then
      local shiesWaterWalking = types.Actor.activeEffects(selfObj):getEffect((core.magic.EFFECT_TYPE.WaterWalking), nil).magnitude
      types.Actor.activeEffects(selfObj):modify(-(shiesWaterWalking), (core.magic.EFFECT_TYPE.WaterWalking), nil)
      wwCheck = false
   end
end

local function modSpeedAndAthletics()
   if getCoDist(selfObj.position, (getPlayerCellPos()).cellPos) < 300 then
      types.Actor.stats.attributes.speed(selfObj).modifier = 15
      types.NPC.stats.skills.athletics(selfObj).modifier = 15
   elseif getCoDist(selfObj.position, (getPlayerCellPos()).cellPos) > 300 then
      local cSpeed = types.Actor.stats.attributes.speed(selfObj).modified * 2.25
      local cAthletics = types.NPC.stats.skills.athletics(player).modified * 2.25
      types.Actor.stats.attributes.speed(selfObj).modifier = cSpeed
      types.NPC.stats.skills.athletics(selfObj).modifier = cAthletics
   end
end

local function hasPotions(potions)
   local inventory = types.Actor.inventory(selfObj)
   local count = 0
   for i = 1, #potions.count do
      local potion = inventory:countOf(potions.count[i].name)
      if potions.count[i].count ~= potion then
         potions.count[i].count = potion
         count = count + potion
      end
   end

   if count > 0 and potions.check == false then
      potions.check = true
   elseif count == 0 and potions.check == true then
      potions.check = false
   end
end

local function setWanderSpeed()
   types.Actor.stats.attributes.speed(selfObj).modifier = 40
end


return {
   engineHandlers = {
      onUpdate = function(dt)
         getPlayerLeader()
         shiesRestoreAttr()
         if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
            updateMWVar("companion", 0)
            cMove = false
            flee()
            fullHeal()
         end

         hPotions.timer = hPotions.timer - dt
         mPotions.timer = mPotions.timer - dt
         fPotions.timer = fPotions.timer - dt
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
            hasPotions(hPotions)
            hasPotions(mPotions)
            hasPotions(fPotions)
         elseif player ~= nil then
            setWanderSpeed()
         end
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
