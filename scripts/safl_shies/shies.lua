local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local anim = require('openmw.animation')
local cmn = require('scripts.safl_shies.common')




local attributes = { types.Actor.stats.dynamic.health, types.Actor.stats.dynamic.magicka, types.Actor.stats.dynamic.fatigue }
local selfObj = self


local ScriptVersion = 1

local RECALL_LOC
local player

local checks = {}
local potionsArr = {}
local timers = {}

local counter


local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA = { recallLoc = { cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251) } }




local posA
local posB
local posC
local doOnce
local doOnce2



local MWVars = {}












local function updateMWVar(varName, varData)
   core.sendGlobalEvent("updateMWVar", { varName, varData, selfObj })
end

local function getMaxAttr(attr)
   return attr.base + attr.modifier
end

local function fullHeal()
   attributes[1](selfObj).current = getMaxAttr(attributes[1](selfObj))
end

local function checkAttrDamaged(attr)
   return attr.current < getMaxAttr(attr)
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
   if (selfObj).controls.sneak ~= checks["playerSneak"] then
      (selfObj).controls.sneak = checks["playerSneak"]
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
      if RECALL_LOC == INIT_DATA.recallLoc and (types.Player.quests(player))["SAFL_ShiesFled"].started == false then
         triggerShiesFledQuest()
      end
      return core.sendGlobalEvent("teleport", {
         actor = actor,
         cell = RECALL_LOC.cellId,
         position = RECALL_LOC.cellPos,
      })
   end,
   nil)

   if RECALL_LOC == INIT_DATA.recallLoc and (types.Player.quests(player))["SAFL_ShiesFled"].stage < 40 then
      checks["incapacitated"] = true
   end
   time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end

local function setSheatheTimer(timePassed)
   if checks["combat"] == true then
      timers["warp"] = 6
      timers["sheathe"] = timers["sheathe"] - timePassed
      if core.sound.isSoundPlaying("Weapon Swish", selfObj) == true or
         core.sound.isSoundPlaying("crossbowShoot", selfObj) == true or
         core.sound.isSoundPlaying("bowShoot", selfObj) == true or
         core.sound.isSoundPlaying("mysticism cast", selfObj) == true or
         core.sound.isSoundPlaying("restoration cast", selfObj) == true or
         core.sound.isSoundPlaying("destruction cast", selfObj) == true or
         core.sound.isSoundPlaying("illusion cast", selfObj) == true then

         timers["sheathe"] = 4.4
      elseif timers["sheathe"] <= 0 then
         checks["combat"] = false
         if types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then

         else
            types.Actor.setStance(selfObj, types.Actor.STANCE.Nothing)
         end
      end
   elseif types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon or
      types.Actor.getStance(selfObj) == types.Actor.STANCE.Spell then

      checks["combat"] = true
      timers["sheathe"] = 4.4
      timers["warp"] = 6
   end
end

local function forceZLevel()
   local playerPos = (getPlayerCellPos())
   local shiesPos = selfObj.position
   if checks["fly"] == true and types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon then
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
   if isShiesFollowing() and MWVars["compmove"] == 1 and checks["cMove"] == false and getCoDist(shiesPos, playerPos.cellPos) < 70 then
      ai.removePackages("Follow")
      ai.startPackage({
         type = "Wander",
         distance = 300,
      })
      checks["cMove"] = true
   end
   if checks["cMove"] == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
      ai.removePackages("Wander")
      makeShiesFollow()
      checks["cMove"] = false
   end
end

local function nudge(timePassed)
   if MWVars["onetimemove"] == 1 then
      timers["move"] = timers["move"] + timePassed
      if timers["move"] > 4 then
         timers["move"] = 0
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

   if timers["warp"] <= 0 and getCoDist(selfObj.position, (getPlayerCellPos()).cellPos) > 680 then
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

local function toggleEffect(flag, effectType)
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

local function checkForPotion(potionName)
   local inventory = types.Actor.inventory(selfObj)
   return inventory:countOf(potionName) > 0
end

local function consumePotion(potionID, effectName)
   local potion = types.Actor.inventory(selfObj):find(potionID)
   local potionEffects = types.Potion.record(potion).effects
   local duration = 60
   if effectName ~= nil then
      for i = 1, #potionEffects do
         if potionEffects[i].effect.name == effectName then
            duration = potionEffects[i].duration
         end
      end
   end
   core.sendGlobalEvent("UseItem", { object = potion, actor = selfObj })
   return duration
end

local function selectBestPotion(attr, potions)
   local potion
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
      return nil
   else
      return potions[potion].name
   end
end

local function shiesDrinkAttrPotion(potions, attr)
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

local function checkAttrPotions(potions)
   local inventory = types.Actor.inventory(selfObj)
   local count = 0
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

local function checkAttributes()
   if attributes[1](selfObj).current > 0 and attributes[1](selfObj).current / getMaxAttr(attributes[1](selfObj)) < FLEE_THRESHOLD then
      updateMWVar("companion", 0)
      checks["cMove"] = false
      flee()
      fullHeal()
      return
   end
   for i = 1, #attributes do
      if attributes[i](selfObj).current < getMaxAttr(attributes[i](selfObj)) and checkAttrDamaged(attributes[i](selfObj)) == false then
         checkAttrPotions(potionsArr[i])
         if potionsArr[i].check == false or shiesDrinkAttrPotion(potionsArr[i], attributes[i](selfObj)) == false then

         end
      end
   end
end

local function freeFall()
   if timers["freefall"] > 1 and checkForPotion("p_slowfall_s") then
      timers["freefall"] = -(consumePotion("p_slowfall_s", "SlowFall"))
   end
end

local function setDefaultSpeed()
   types.Actor.stats.attributes.speed(selfObj).modifier = 40
end

local function updateTimers(dt)
   for i = 1, #potionsArr do
      potionsArr[i].timer = potionsArr[i].timer - dt
   end
   timers["warp"] = timers["warp"] - dt
   if ((checks["fly"] == false) and (types.Actor.isOnGround(selfObj) == false)) or timers["freefall"] < 0 then
      timers["freefall"] = timers["freefall"] + dt
   elseif timers["freefall"] > 0 then
      timers["freefall"] = 0
   end
end

local function onUpdate(dt)
   if core.isWorldPaused() == true then
      return
   end
   getPlayerLeader()
   checkAttributes()


   if checks["fly"] == false and types.Actor.isOnGround(selfObj) == false then
      freeFall()
   end

   updateTimers(dt)
   setSheatheTimer(dt)

   if isShiesFollowing() then
      setSneak()
      toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate))
      toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking))
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

local function onInit()
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
      types = { {
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
   potionsArr[2] = {
      check = false,
      timer = 0,
      effectName = "Restore Magicka",
      types = { {
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
   potionsArr[3] = {
      check = false,
      timer = 0,
      effectName = "Restore Fatigue",
      types = { {
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
      ["fetchMWVars"] = function(data)
         MWVars = data
         for k, v in pairs(data) do
            if MWVars[k] ~= v then
               MWVars[k] = v
            end
         end
      end,
      ["Hit"] = function(attack)
         local attackerObj = attack.attacker
         attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
      end,
      ["hurtShies"] = function()
         attributes[1](selfObj).current = 1
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
            checks["playerSneak"] = sneaking
         end
      end,
   },
}
