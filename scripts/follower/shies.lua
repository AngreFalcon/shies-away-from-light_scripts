local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local anim = require('openmw.animation')
local cmn = require('scripts.follower.common')




local attributes = { types.Actor.stats.dynamic.health, types.Actor.stats.dynamic.magicka, types.Actor.stats.dynamic.fatigue }
local selfObj = self


local SCRIPT_VERSION = 1

local STAT_MOD = {
   CATCHUP_MULT = 2.25,
   FOLLOW = 15,
   WANDER = 40,
}
local DEFAULT_CD = {
   RESTORE = 10,
   ENCHANTMENT = 10,
   SPELL = 10,
   POTION = 60,
   SCROLL = 60,
   WARP = 6,
   SHEATHE = 4.4,
}
local RESTORE_WEIGHTS = {
   ENCHANTMENT = 0.75,
   SPELL = 1,
   POTION = 1.25,
   SCROLL = 1.5,
}
local ATTRIBUTE_PANIC_THRESHOLD = 0.75
local WASTE_THRESHOLD = {
   POTION = 0.25,
   SCROLL = 0.50,
}
local DISTANCE_THRESHOLD = {
   MOD_SPEED = 300,
   MAINTAIN_LOWER = 70,
   MAINTAIN_UPPER = 100,
   WANDER = 300,
}
local BOOL = {
   TRUE = 1,
   FALSE = 0,
}
local NUDGE_DELAY = 4
local DELAY1 = 0.5 * time.second
local DELAY2 = 5 * time.second


local SHIES = {
   FLEE_THRESHOLD = 0.1,
   SHIES_FLED_FOUND_STAGE = 40,
   RECALL_TIMEOUT = 2 * time.second,
   INIT_DATA = { recallLoc = { cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251) } },
}


local RecallLoc
local player
local checks = {}
local restoreAttr = {}
local timers = {}


local posA
local posB
local posC
local doOnce
local doOnce2




local MWVars = {}
















local function updateMWVar(varName, varData)
   core.sendGlobalEvent("updateMWVar", { varName, varData, selfObj })
end

local function isFollowing()
   local currentPackage = ai.getActivePackage()
   return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

local function getPlayerLeader()
   if isFollowing() then
      player = ai.getActiveTarget("Follow")
   end
end

local function getMaxAttr(attr)
   return attr.base + attr.modifier
end

local function getAttrDiff(attr)
   return getMaxAttr(attr) - attr.current
end

local function checkAttrDamaged(attr)
   return attr.current < getMaxAttr(attr)
end

local function fullHeal()
   attributes[1](selfObj).current = getMaxAttr(attributes[1](selfObj))
end

local function checkForPotion(potionName)
   local inventory = types.Actor.inventory(selfObj)
   return inventory:countOf(potionName) > 0
end

local function getPlayerCellPos()
   return { cellId = player.cell.name, cellPos = player.position }
end

local function getCoDist(vector1, vector2)
   local tempVar1 = vector1.x - vector2.x
   local tempVar2 = vector1.y - vector2.y
   return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function setSheatheWarpTimers(dt)
   if checks["combat"] == true then
      timers["warp"] = DEFAULT_CD.WARP
      timers["sheathe"] = timers["sheathe"] - dt
      if core.sound.isSoundPlaying("Weapon Swish", selfObj) == true or
         core.sound.isSoundPlaying("crossbowShoot", selfObj) == true or
         core.sound.isSoundPlaying("bowShoot", selfObj) == true or
         core.sound.isSoundPlaying("mysticism cast", selfObj) == true or
         core.sound.isSoundPlaying("restoration cast", selfObj) == true or
         core.sound.isSoundPlaying("destruction cast", selfObj) == true or
         core.sound.isSoundPlaying("illusion cast", selfObj) == true then

         timers["sheathe"] = DEFAULT_CD.SHEATHE
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
      timers["warp"] = DEFAULT_CD.WARP
      timers["sheathe"] = DEFAULT_CD.SHEATHE
   end
end

local function updateTimers(dt)
   for i = 1, #restoreAttr do
      if restoreAttr[i].spellTimer > 0 then
         restoreAttr[i].spellTimer = restoreAttr[i].spellTimer - dt
      end
      if restoreAttr[i].enchantmentTimer > 0 then
         restoreAttr[i].enchantmentTimer = restoreAttr[i].enchantmentTimer - dt
      end
      if restoreAttr[i].potionTimer > 0 then
         restoreAttr[i].potionTimer = restoreAttr[i].potionTimer - dt
      end
      if restoreAttr[i].scrollTimer > 0 then
         restoreAttr[i].scrollTimer = restoreAttr[i].scrollTimer - dt
      end
   end

   if timers["restorecooldown"] > 0 then
      timers["restorecooldown"] = timers["restorecooldown"] - dt
   end

   if timers["warp"] > 0 then
      timers["warp"] = timers["warp"] - dt
   end

   if ((checks["fly"] == false) and (types.Actor.isOnGround(selfObj) == false)) or timers["freefall"] < 0 then
      timers["freefall"] = timers["freefall"] + dt
   elseif timers["freefall"] > 0 then
      timers["freefall"] = 0
   end

   setSheatheWarpTimers(dt)
end


local function triggerShiesFledQuest()
   if player ~= nil then
      player:sendEvent("shiesFled", nil)
   end
end



local function setSneak()
   if player ~= nil then
      player:sendEvent("getSneakVal", selfObj)
   end
   if (selfObj).controls.sneak ~= checks["playerSneak"] then
      (selfObj).controls.sneak = checks["playerSneak"]
   end
end

local function makeCompanionFollow()
   ai.startPackage({
      type = "Follow",
      target = player,
   })
end

local function toggleEffect(flag, effectType)
   local playerEffect = types.Actor.activeEffects(player):getEffect(effectType, nil).magnitude
   if playerEffect > 0 and checks[flag] == false then
      types.Actor.activeEffects(selfObj):modify(playerEffect, effectType, nil)
      checks[flag] = true
   elseif playerEffect <= 0 and checks[flag] == true then
      local companionEffect = types.Actor.activeEffects(selfObj):getEffect(effectType, nil).magnitude
      types.Actor.activeEffects(selfObj):modify(-(companionEffect), effectType, nil)
      checks[flag] = false
   end
end

local function castSpell(spell, castSound)
   local duration = DEFAULT_CD.SPELL


   attributes[2](selfObj).current = attributes[2](selfObj).current - spell.cost
   if false then
      return 0
   end
   types.Actor.activeSpells(selfObj):add({
      id = spell.id,
      effects = { 0 },
      name = spell.name,
      caster = selfObj,
   })
   for _, effect in pairs((spell.effects)) do
      local vfx = effect.effect
      selfObj:sendEvent('AddVfx', {
         model = types.Static.record(vfx.castStatic).model,
         options = {
            vfxId = "followerCast" .. effect.id,
            particleTextureOverride = vfx.particle,
            loop = false,
         },
      })

      core.sound.playSound3d(castSound, selfObj, {})
      if duration < effect.duration then
         duration = effect.duration
      end
   end
   return duration
end

local function useEnchantment(itemRecord, effectName, castSound)
   local item = types.Actor.inventory(selfObj):find(itemRecord.id)
   local enchantment = (core.magic.enchantments.records)[itemRecord.enchant]
   local duration = DEFAULT_CD.SCROLL
   if effectName ~= nil then
      for _, effect in pairs((enchantment.effects)) do
         local vfx = effect.effect
         selfObj:sendEvent('AddVfx', {
            model = types.Static.record(vfx.castStatic).model,
            options = {
               vfxId = "followerCast" .. effect.id,
               particleTextureOverride = vfx.particle,
               loop = false,
            },
         })

         core.sound.playSound3d(castSound, selfObj, {})
         if vfx.name == effectName then
            duration = effect.duration
         end
      end
   end
   types.Actor.activeSpells(selfObj):add({
      id = itemRecord.id,
      effects = { 0 },
      name = itemRecord.name,
      caster = selfObj,
   })
   core.sendGlobalEvent("changeEnchCharge", { item, enchantment.cost })
   return duration
end

local function consumePotion(potionID, effectName)
   local potion = types.Actor.inventory(selfObj):find(potionID)
   local potionEffects = types.Potion.record(potion).effects
   local duration = DEFAULT_CD.POTION
   if effectName ~= nil then
      for i = 1, #potionEffects do
         if potionEffects[i].effect.name == effectName then
            duration = potionEffects[i].duration
            break
         end
      end
   end
   core.sendGlobalEvent("UseItem", { object = potion, actor = selfObj })
   return duration
end

local function useScroll(scrollId, effectName, castSound)
   local scroll = types.Actor.inventory(selfObj):find(scrollId)
   local scrollRecord = types.Book.record(scroll)
   local scrollEffects = (core.magic.enchantments.records)[scrollRecord.enchant].effects
   local duration = DEFAULT_CD.SCROLL
   if effectName ~= nil then
      for _, effect in pairs((scrollEffects)) do
         local vfx = effect.effect
         selfObj:sendEvent('AddVfx', {
            model = types.Static.record(vfx.castStatic).model,
            options = {
               vfxId = "followerCast" .. effect.id,
               particleTextureOverride = vfx.particle,
               loop = false,
            },
         })

         core.sound.playSound3d(castSound, selfObj, {})
         if vfx.name == effectName then
            duration = effect.duration
         end
      end
   end
   types.Actor.activeSpells(selfObj):add({
      id = scrollId,
      effects = { 0 },
      name = scrollRecord.name,
      caster = selfObj,
   })
   core.sendGlobalEvent('ConsumeItem', { item = scroll, amount = 1 })

   return duration
end

local function selectRestoreEnch(effectId, attrDiff, itemType)
   local inventory = types.Actor.inventory(selfObj)
   local selectedItem
   local selectedHealQuality
   for _, item in pairs(inventory:getAll(itemType)) do
      local itemRecord = (itemType.record(item))
      if itemRecord.enchant ~= nil then
         local enchant = (core.magic.enchantments.records)[itemRecord.enchant]
         if enchant.type == core.magic.ENCHANTMENT_TYPE.CastOnUse then
            for _, effect in pairs(enchant.effects) do
               if effect.id == effectId then
                  local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration
                  local healQuality = math.abs(attrDiff - magnitude)
                  if (selectedItem == nil) or healQuality < selectedHealQuality then
                     selectedItem = itemRecord
                     selectedHealQuality = healQuality
                  end
               end
            end
         end
      end
   end
   if selectedItem ~= nil and selectedHealQuality ~= nil then
      return { selectedItem, selectedHealQuality }
   else
      return nil
   end
end

local function selectRestoreSpell(effectId, attrDiff)
   local spells = types.Actor.spells(selfObj)
   local currentMagicka = attributes[2](selfObj).current
   local selectedSpell
   local selectedMagnitude
   local selectedHealQuality
   for _, spell in pairs((spells)) do
      if spell.type == core.magic.SPELL_TYPE.Spell or (spell.type == core.magic.SPELL_TYPE.Power and types.Actor.activeSpells(selfObj):canUsePower(spell.id) == true) then
         for _, effect in pairs((spell.effects)) do
            if effect.id == (effectId) and effect.range == core.magic.RANGE.Self then
               if spell.cost < currentMagicka then
                  local costRatio = spell.cost / currentMagicka
                  local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration
                  local healQuality = math.abs(attrDiff - magnitude) * (1 + costRatio)
                  if (selectedSpell == nil) or healQuality < selectedHealQuality then
                     selectedSpell = spell
                     selectedMagnitude = magnitude
                     selectedHealQuality = healQuality
                  end
               end
            end
         end
      end
   end
   if selectedSpell ~= nil and selectedMagnitude ~= nil then
      return { selectedSpell, selectedHealQuality }
   else
      return nil
   end
end

local function selectRestorePotion(effectId, attrDiff, attrMax)
   local inventory = types.Actor.inventory(selfObj)
   local selectedPotion
   local selectedMagnitude
   local selectedHealQuality
   for _, potion in pairs(inventory:getAll(types.Potion)) do
      local potionRecord = types.Potion.record(potion)
      for _, effect in pairs(potionRecord.effects) do
         if effect.id == effectId then
            local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration
            local healQuality = math.abs(attrDiff - magnitude)
            if (selectedPotion == nil) or healQuality < selectedHealQuality then
               selectedPotion = potionRecord
               selectedMagnitude = magnitude
               selectedHealQuality = healQuality
            end
         end
      end
   end
   if selectedPotion ~= nil and selectedMagnitude ~= nil and selectedHealQuality ~= nil and
      (((selectedMagnitude * WASTE_THRESHOLD.POTION) < attrDiff) or
      (attrDiff > (attrMax * ATTRIBUTE_PANIC_THRESHOLD))) then

      return { selectedPotion.id, selectedHealQuality }
   else
      return nil
   end
end

local function selectRestoreScroll(effectId, attrDiff, attrMax)
   local inventory = types.Actor.inventory(selfObj)
   local selectedScroll
   local selectedMagnitude
   local selectedHealQuality
   for _, scroll in pairs(inventory:getAll(types.Book)) do
      local scrollRecord = types.Book.record(scroll)
      if scrollRecord.isScroll == true then
         local enchant = (core.magic.enchantments.records)[scrollRecord.enchant]
         if enchant.type == core.magic.ENCHANTMENT_TYPE.CastOnce then
            for _, effect in pairs(enchant.effects) do
               if effect.id == effectId then
                  local magnitude = (effect.magnitudeMax + effect.magnitudeMin) / 2 * effect.duration
                  local healQuality = math.abs(attrDiff - magnitude)
                  if (selectedScroll == nil) or healQuality < selectedHealQuality then
                     selectedScroll = scrollRecord
                     selectedMagnitude = magnitude
                     selectedHealQuality = healQuality
                  end
               end
            end
         end
      end
   end
   if selectedScroll ~= nil and selectedMagnitude ~= nil and selectedHealQuality ~= nil and
      (((selectedMagnitude * WASTE_THRESHOLD.SCROLL) < attrDiff) or
      (attrDiff > (attrMax * ATTRIBUTE_PANIC_THRESHOLD))) then

      return { selectedScroll.id, selectedHealQuality }
   else
      return nil
   end
end

local function chooseRestoreMethod(iter)














   local methodAction = {
      ["encharmor"] = function(method) restoreAttr[iter].enchantmentTimer = useEnchantment((method.data), restoreAttr[iter].effectName, "restoration cast") end,
      ["enchclothing"] = function(method) restoreAttr[iter].enchantmentTimer = useEnchantment((method.data), restoreAttr[iter].effectName, "restoration cast") end,
      ["enchweapon"] = function(method) restoreAttr[iter].enchantmentTimer = useEnchantment((method.data), restoreAttr[iter].effectName, "restoration cast") end,
      ["spell"] = function(method) restoreAttr[iter].spellTimer = castSpell((method.data), "restoration cast") end,
      ["potion"] = function(method) restoreAttr[iter].potionTimer = consumePotion((method.data), restoreAttr[iter].effectName) end,
      ["scroll"] = function(method) restoreAttr[iter].scrollTimer = useScroll((method.data), restoreAttr[iter].effectName, "restoration cast") end,
   }
   local attrDiff = getAttrDiff(attributes[iter](selfObj))
   local restoreMethods = {}
   if restoreAttr[iter].enchantmentTimer <= 0 then
      local armor = selectRestoreEnch(restoreAttr[iter].effectId, attrDiff, types.Armor)
      if armor ~= nil then
         table.insert(restoreMethods, {
            name = "encharmor",
            data = armor[1],
            weight = armor[2] + (getMaxAttr(attributes[iter](selfObj)) * RESTORE_WEIGHTS.ENCHANTMENT),
         })
      end

      local clothing = selectRestoreEnch(restoreAttr[iter].effectId, attrDiff, types.Clothing)
      if clothing ~= nil then
         table.insert(restoreMethods, {
            name = "enchclothing",
            data = clothing[1],
            weight = clothing[2] + (getMaxAttr(attributes[iter](selfObj)) * RESTORE_WEIGHTS.ENCHANTMENT),
         })
      end
      local weapon = selectRestoreEnch(restoreAttr[iter].effectId, attrDiff, types.Weapon)
      if weapon ~= nil then
         table.insert(restoreMethods, {
            name = "enchweapon",
            data = weapon[1],
            weight = weapon[2] + (getMaxAttr(attributes[iter](selfObj)) * RESTORE_WEIGHTS.ENCHANTMENT),
         })
      end
   end
   if restoreAttr[iter].spellTimer <= 0 and attributes[2](selfObj).current > 0 then
      local spell = selectRestoreSpell(restoreAttr[iter].effectId, attrDiff)
      if spell ~= nil then
         table.insert(restoreMethods, {
            name = "spell",
            data = spell[1],
            weight = spell[2] + (getMaxAttr(attributes[iter](selfObj)) * RESTORE_WEIGHTS.SPELL),
         })
      end
   end
   if restoreAttr[iter].potionTimer <= 0 then
      local potion = selectRestorePotion(restoreAttr[iter].effectId, attrDiff, getMaxAttr(attributes[iter](selfObj)))
      if potion ~= nil then
         table.insert(restoreMethods, {
            name = "potion",
            data = potion[1],
            weight = potion[2] + (getMaxAttr(attributes[iter](selfObj)) * RESTORE_WEIGHTS.POTION),
         })
      end
   end
   if restoreAttr[iter].scrollTimer <= 0 then
      local scroll = selectRestoreScroll(restoreAttr[iter].effectId, attrDiff, getMaxAttr(attributes[iter](selfObj)))
      if scroll ~= nil then
         table.insert(restoreMethods, {
            name = "scroll",
            data = scroll[1],
            weight = scroll[2] + (getMaxAttr(attributes[iter](selfObj)) * RESTORE_WEIGHTS.SCROLL),
         })
      end
   end
   if #restoreMethods == 0 then return end

   local method = restoreMethods[1]
   for i = 2, #restoreMethods do
      if method.weight >= restoreMethods[i].weight then
         method = restoreMethods[i]
      end
   end
   methodAction[method.name](method)
   timers["restorecooldown"] = DEFAULT_CD.RESTORE
end

local function checkAttributes()
   for i = 1, #attributes do
      if checkAttrDamaged(attributes[i](selfObj)) == true and timers["restorecooldown"] <= 0 then
         chooseRestoreMethod(i)
      end
   end
end

local function freeFall()
   if timers["freefall"] > 1 and checkForPotion("p_slowfall_s") then
      timers["freefall"] = -(consumePotion("p_slowfall_s", "SlowFall"))
   end
end


local function shiesIncapacitated(getBackUp)
   local animName = "knockout"
   if anim.isPlaying(selfObj, animName) == false then
      anim.clearAnimationQueue(selfObj, false)
      anim.playQueued(selfObj, animName, {})
   elseif getBackUp == true then
      I.AnimationController.addTextKeyHandler(animName, function(animGroup, key)
         anim.playQueued(selfObj, animGroup, { startkey = 'stop', stopkey = 'stop', loops = 0 })
         if key.sub(key, #key - #'stop') == 'stop' then
            anim.clearAnimationQueue(selfObj, true)
         end
      end)
      checks["incapacitated"] = false
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
      if RecallLoc == SHIES.INIT_DATA.recallLoc and (types.Player.quests(player))["SAFL_ShiesFled"].started == false then
         triggerShiesFledQuest()
      end
      return core.sendGlobalEvent("teleport", {
         actor = actor,
         cell = RecallLoc.cellId,
         position = RecallLoc.cellPos,
      })
   end,
   nil)

   if RecallLoc == SHIES.INIT_DATA.recallLoc and (types.Player.quests(player))["SAFL_ShiesFled"].stage < SHIES.SHIES_FLED_FOUND_STAGE then
      checks["incapacitated"] = true
   end
   time.newSimulationTimer(SHIES.RECALL_TIMEOUT, cb, self, nil)
end

local function shiesCheckAttributes()
   if attributes[1](selfObj).current > 0 and attributes[1](selfObj).current / getMaxAttr(attributes[1](selfObj)) < SHIES.FLEE_THRESHOLD then
      updateMWVar("companion", BOOL.FALSE)
      checks["cMove"] = false
      flee()
      fullHeal()
      return
   end
end



local function forceZLevel()
   local playerPos = (getPlayerCellPos())
   local followerPos = selfObj.position
   if checks["fly"] == true and types.Actor.getStance(selfObj) == types.Actor.STANCE.Weapon then
      core.sendGlobalEvent("teleport", {
         actor = selfObj,
         cell = selfObj.cell.name,
         position = util.vector3(followerPos.x, followerPos.y, playerPos.cellPos.z),
      })
   end
end

local function maintainDistance()
   local followerPos = selfObj.position
   local playerPos = (getPlayerCellPos())
   if playerPos == nil then
      return
   end
   if isFollowing() and MWVars["compmove"] == BOOL.TRUE and checks["cMove"] == false and
      getCoDist(followerPos, playerPos.cellPos) < DISTANCE_THRESHOLD.MAINTAIN_LOWER then

      ai.removePackages("Follow")
      ai.startPackage({
         type = "Wander",
         distance = DISTANCE_THRESHOLD.WANDER,
      })
      checks["cMove"] = true
   end
   if checks["cMove"] == true and getCoDist(followerPos, playerPos.cellPos) > DISTANCE_THRESHOLD.MAINTAIN_UPPER then
      ai.removePackages("Wander")
      makeCompanionFollow()
      checks["cMove"] = false
   end
end

local function nudge(timePassed)
   if MWVars["onetimemove"] == BOOL.TRUE then
      timers["move"] = timers["move"] + timePassed
      if timers["move"] >= NUDGE_DELAY then
         timers["move"] = 0
         makeCompanionFollow()
         updateMWVar("onetimemove", BOOL.FALSE)
      end
   end
end

local function warpToPlayer()
   posA = getPlayerCellPos()
   if posA == nil then return end

   if doOnce == false then
      posB = getPlayerCellPos()
      doOnce = true
   end

   local coDist = getCoDist((posA).cellPos, posB.cellPos)
   if coDist > 360 then doOnce = false end

   if (coDist > 180 and doOnce2 == false) or posC == nil then
      posC = getPlayerCellPos()
      doOnce2 = true
   end

   local coDist2 = getCoDist((posA).cellPos, (posC).cellPos)
   if coDist2 > 360 then doOnce2 = false end

   if timers["warp"] <= 0 and getCoDist(selfObj.position, (getPlayerCellPos()).cellPos) > 680 then
      if coDist > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = (posC).cellId,
            position = (posC).cellPos,
         })
         makeCompanionFollow()
      elseif coDist2 > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = posB.cellId,
            position = posB.cellPos,
         })
         makeCompanionFollow()
      end
   end
end

local function setDefaultSpeed()
   types.Actor.stats.attributes.speed(selfObj).modifier = STAT_MOD.WANDER
end

local function modSpeedAndAthletics()
   local followerSpeed = types.Actor.stats.attributes.speed(selfObj)
   local followerAthletics = types.NPC.stats.skills.athletics(selfObj)
   local cSpeed = types.Actor.stats.attributes.speed(player).modified * STAT_MOD.CATCHUP_MULT
   local cAthletics = types.NPC.stats.skills.athletics(player).modified * STAT_MOD.CATCHUP_MULT
   if (followerSpeed.modifier ~= STAT_MOD.FOLLOW or followerAthletics.modifier ~= STAT_MOD.FOLLOW) and
      (getCoDist(selfObj.position, getPlayerCellPos().cellPos) <= DISTANCE_THRESHOLD.MOD_SPEED) then

      followerSpeed.modifier = STAT_MOD.FOLLOW
      followerAthletics.modifier = STAT_MOD.FOLLOW
   elseif (followerSpeed.modifier ~= cSpeed or followerAthletics.modifier ~= cAthletics) and
      (getCoDist(selfObj.position, getPlayerCellPos().cellPos) > DISTANCE_THRESHOLD.MOD_SPEED) then

      followerSpeed.modifier = cSpeed
      followerAthletics.modifier = cAthletics
   end
end



time.runRepeatedly(
function()
   if isFollowing() then
      modSpeedAndAthletics()
   elseif player ~= nil then
      setDefaultSpeed()
   end
end, DELAY1, {})


time.runRepeatedly(
function()

end, DELAY2, {})


local function onUpdate(dt)
   if core.isWorldPaused() == true then
      return
   end
   getPlayerLeader()
   checkAttributes()
   updateTimers(dt)

   shiesCheckAttributes()
   if checks["incapacitated"] == true then


      shiesIncapacitated((types.Player.quests(player))["SAFL_ShiesFled"].stage >= SHIES.SHIES_FLED_FOUND_STAGE)
   end

   if checks["fly"] == false and types.Actor.isOnGround(selfObj) == false then
      freeFall()
   end
   if isFollowing() then
      setSneak()
      toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate))
      toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking))
      forceZLevel()
      warpToPlayer()
   elseif player ~= nil then
      maintainDistance()
      nudge(dt)
   end
end

local function onInit()
   RecallLoc = SHIES.INIT_DATA.recallLoc
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
   timers["restorecooldown"] = 0
   restoreAttr[1] = {
      potionTimer = 0,
      spellTimer = 0,
      scrollTimer = 0,
      enchantmentTimer = 0,
      effectName = "Restore Health",
      effectId = "restorehealth",
   }
   restoreAttr[2] = {
      potionTimer = 0,
      spellTimer = 0,
      scrollTimer = 0,
      enchantmentTimer = 0,
      effectName = "Restore Magicka",
      effectId = "restoremagicka",
   }
   restoreAttr[3] = {
      potionTimer = 0,
      spellTimer = 0,
      scrollTimer = 0,
      enchantmentTimer = 0,
      effectName = "Restore Fatigue",
      effectId = "restorefatigue",
   }
end

local function onSave()
   for k, v in pairs(MWVars) do
      updateMWVar(k, v)
   end
   return {
      version = SCRIPT_VERSION,
      recallLoc = RecallLoc,
      player = player,
      checks = checks,
      timers = timers,
      restoreAttr = restoreAttr,
      posA = posA,
      posB = posB,
      posC = posC,
      doOnce = doOnce,
      doOnce2 = doOnce2,
   }
end

local function onLoad(data)
   if (not data) or (not data.version) or (data.version < SCRIPT_VERSION) then
      print('Was saved with an old version of the script, initializing to default')
      RecallLoc = SHIES.INIT_DATA.recallLoc
      return
   elseif (data.version > SCRIPT_VERSION) then
      error('Required update to a new version of the script')
   elseif (data.version == SCRIPT_VERSION) then
      RecallLoc = data.recallLoc
      player = data.player
      checks = data.checks
      timers = data.timers
      restoreAttr = data.restoreAttr
      posA = data.posA
      posB = data.posB
      posC = data.posC
      doOnce = data.doOnce
      doOnce2 = data.doOnce2
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
      ["shiesJump"] = function()
         print(types.NPC.stats.skills.acrobatics(selfObj).progress);
         (selfObj).controls.jump = true
         print(types.NPC.stats.skills.acrobatics(selfObj).progress)
      end,
      ["shiesActivated"] = function()
      end,
      ["playerSneak"] = function(sneaking)
         if sneaking ~= nil then
            checks["playerSneak"] = sneaking
         end
      end,
   },
}
