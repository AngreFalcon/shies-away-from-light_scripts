local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table; local types = require('openmw.types')
local core = require('openmw.core')
local time = require('openmw_aux.time')
local util = require('openmw.util')
local cmn = require('scripts.follower.common')





































































































































































local Const = {
   Delay1 = 0.5 * time.second,
   Delay2 = 10 * time.second,


   FeatureFlags = {
      Rapport = {
         Enable = true,
         Race = true,
         Sex = true,
         Guilds = true,
         BirthSign = true,
         Class = true,
         Disp = true,
         Bounty = true,
      },
      RestoreDynStats = {
         Enable = true,
         Enchant = true,
         Spell = true,
         Potion = true,
         Scroll = true,
      },
   },
   Rapport = {
      Preferences = {
         Races = {
            ["argonian"] = 0.005,
            ["khajiit"] = 0.002,
         },
         Sexes = {
            [true] = 0.005,
         },
         Guilds = {
            ["morag tong"] = 0.002,
            ["mages guild"] = 0.003,
            ["telvanni"] = 0.003,
         },
         BirthSigns = {
            ["moonshadow sign"] = 0.001,
         },
         Classes = {
            ["nightblade"] = 0.001,
         },
      },
      BaseModifier = 0.01,
      DispModifier = -80,
      DispDivisor = 10000,
      BountyModifier = -0.1,
      BountyMultiplier = -0.0,
      ExpelledModifier = -10,
      GrowthThreshold = 1,
      DecayThreshold = -1,
      Min = -1000,
      Max = 1000,
   },
   Restore = {
      CDs = {
         General = 10,
         Enchantment = 10,
         Spell = 10,
         Potion = 60,
         Scroll = 60,
      },
      Thresholds = {
         Trigger = 0.15,
         Panic = 0.75,
         PotionWaste = 0.25,
         ScrollWaste = 0.50,
      },
      Weights = {
         Enchantment = 0.75,
         Spell = 1,
         Potion = 1.25,
         Scroll = 1.5,
      },
   },
   CDs = {
      Warp = 6,
      Sheathe = 4.4,
      NudgeDelay = 4,
   },
   StatMods = {
      CatchupMultiplier = 2.25,
      DefaultSpeed = 15,
      WanderSpeed = 40,
   },
   Thresholds = {
      ModifySpeed = 300,
      MaintainDistLower = 70,
      MaintainDistUpper = 100,
      Wander = 300,
   },
}


local handler = {}

function handler.delayUpdate1(self)
   if core.isWorldPaused() == true then return end

   if self:isFollowing() == true then
      self:toggleEffect("fly", (core.magic.EFFECT_TYPE.Levitate))
      self:toggleEffect("ww", (core.magic.EFFECT_TYPE.WaterWalking))
      self:forceZLevel()
      self:modSpeedAndAthletics()
   elseif self.player ~= nil then
      self:setDefaultSpeed()
   end
end

function handler.delayUpdate2(self)
   if core.isWorldPaused() == true then return end

   if self:isFollowing() == true then
      self:incrementRapport()
   end
end

function handler.onUpdate(self, dt)
   self:getPlayerLeader()
   self:resetDialogueVars()
   self:checkDynStats()
   self:updateTimers(dt)
   if types.Actor.isOnGround(self.selfObj) == false and self.checks["fly"] == false then
      self:freeFall()
   end
   if self:isFollowing() == true then
      self:setSneak()
      self:warpToPlayer()
   elseif self.player ~= nil then
      self:maintainDistance()
      self:nudge(dt)
   end
end

function handler.onSave(self, payload)
   for k, v in pairs(self.MWVars) do
      self:updateMWVars({ [k] = v })
   end
   return cmn.merge(
   {
      player = self.player,
      rapportCounter = self.rapportCounter,
      doOnce = self.doOnce,
      doOnce2 = self.doOnce2,
      checks = self.checks,
      timers = self.timers,
      restoreAttr = self.restoreDynStat,
      posA = self.posA,
      posB = self.posB,
      posC = self.posC,
   },
   payload)

end

function handler.onLoad(self, data)
   self.player = data.player
   self.rapportCounter = data.rapportCounter
   self.doOnce = data.doOnce
   self.doOnce2 = data.doOnce2
   self.checks = data.checks
   self.timers = data.timers
   self.restoreDynStat = data.restoreDynStat
   self.posA = data.posA
   self.posB = data.posB
   self.posC = data.posC
end

function handler.onActivated(_, _)
end


local utility = {}

function utility.updateMWVars(self, data)
   core.sendGlobalEvent("updateMWVar", { data, self.selfObj })
end

function utility.isFollowing(self)
   local currentPackage = self.ai.getActivePackage()
   return ((currentPackage ~= nil) and (currentPackage.type == "Follow"))
end

function utility.getPlayerLeader(self)
   if self:isFollowing() then
      self.player = self.ai.getActiveTarget("Follow")
   end
end

function utility.fullHeal(self)
   self.dynamicStats[1](self.selfObj).current = cmn.getMaxDynStat(self.dynamicStats[1](self.selfObj))
end

function utility.checkForPotion(self, potionName)
   local inventory = types.Actor.inventory(self.selfObj)
   return inventory:countOf(potionName) > 0
end

function utility.getPlayerCellPos(self)
   return { cellId = self.player.cell.name, cellPos = self.player.position }
end

function utility.setSheatheWarpTimers(self, dt)
   if self.checks["combat"] == true then
      self.timers["warp"] = self.defaultCd.WARP
      self.timers["sheathe"] = self.timers["sheathe"] - dt
      if core.sound.isSoundPlaying("Weapon Swish", self.selfObj) == true or
         core.sound.isSoundPlaying("crossbowShoot", self.selfObj) == true or
         core.sound.isSoundPlaying("bowShoot", self.selfObj) == true or
         core.sound.isSoundPlaying("mysticism cast", self.selfObj) == true or
         core.sound.isSoundPlaying("restoration cast", self.selfObj) == true or
         core.sound.isSoundPlaying("destruction cast", self.selfObj) == true or
         core.sound.isSoundPlaying("illusion cast", self.selfObj) == true then

         self.timers["sheathe"] = self.defaultCd.SHEATHE
      elseif self.timers["sheathe"] <= 0 then
         self.checks["combat"] = false
         if types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Spell then

         else
            types.Actor.setStance(self.selfObj, types.Actor.STANCE.Nothing)
         end
      end
   elseif types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Weapon or
      types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Spell then

      self.checks["combat"] = true
      self.timers["warp"] = self.defaultCd.WARP
      self.timers["sheathe"] = self.defaultCd.SHEATHE
   end
end

function utility.updateTimers(self, dt)
   for i = 1, #self.restoreDynStat do
      if self.restoreDynStat[i].spellTimer > 0 then
         self.restoreDynStat[i].spellTimer = self.restoreDynStat[i].spellTimer - dt
      end
      if self.restoreDynStat[i].enchantmentTimer > 0 then
         self.restoreDynStat[i].enchantmentTimer = self.restoreDynStat[i].enchantmentTimer - dt
      end
      if self.restoreDynStat[i].potionTimer > 0 then
         self.restoreDynStat[i].potionTimer = self.restoreDynStat[i].potionTimer - dt
      end
      if self.restoreDynStat[i].scrollTimer > 0 then
         self.restoreDynStat[i].scrollTimer = self.restoreDynStat[i].scrollTimer - dt
      end
   end
   if self.timers["restorecooldown"] > 0 then
      self.timers["restorecooldown"] = self.timers["restorecooldown"] - dt
   end
   if self.timers["warp"] > 0 then
      self.timers["warp"] = self.timers["warp"] - dt
   end
   if ((self.checks["fly"] == false) and (types.Actor.isOnGround(self.selfObj) == false)) or self.timers["freefall"] < 0 then
      self.timers["freefall"] = self.timers["freefall"] + dt
   elseif self.timers["freefall"] > 0 then
      self.timers["freefall"] = 0
   end
   self:setSheatheWarpTimers(dt)
end

function utility.resetDialogueVars(self)
   local vars = {
      ["locationThoughts"] = self.mwBool.FALSE,
      ["npcThoughts"] = self.mwBool.FALSE,
      ["mainquestThoughts"] = self.mwBool.FALSE,
      ["magequestThoughts"] = self.mwBool.FALSE,
      ["moragquestThoughts"] = self.mwBool.FALSE,
      ["thiefquestThoughts"] = self.mwBool.FALSE,
      ["fighterquestThoughts"] = self.mwBool.FALSE,
      ["legionquestThoughts"] = self.mwBool.FALSE,
      ["cultquestThoughts"] = self.mwBool.FALSE,
      ["templequestThoughts"] = self.mwBool.FALSE,
      ["housequestThoughts"] = self.mwBool.FALSE,
   }
   self:updateMWVars(vars)
end



local gameplay = {}

function gameplay.setSneak(self)
   if self.player ~= nil then
      self.player:sendEvent("getSneakVal", self.selfObj)
   end
   if self.controls.sneak ~= self.checks["playerSneak"] then
      self.controls.sneak = self.checks["playerSneak"]
   end
end

function gameplay.makeCompanionFollow(self)
   self.ai.startPackage({
      type = "Follow",
      target = self.player,
   })
end

function gameplay.toggleEffect(self, flag, effectType)
   local playerEffect = types.Actor.activeEffects(self.player):getEffect(effectType, nil).magnitude
   if playerEffect > 0 and self.checks[flag] == false then
      types.Actor.activeEffects(self.selfObj):modify(playerEffect, effectType, nil)
      self.checks[flag] = true
   elseif playerEffect <= 0 and self.checks[flag] == true then
      local companionEffect = types.Actor.activeEffects(self.selfObj):getEffect(effectType, nil).magnitude
      types.Actor.activeEffects(self.selfObj):modify(-(companionEffect), effectType, nil)
      self.checks[flag] = false
   end
end

function gameplay.freeFall(self)
   if self.timers["freefall"] > 1 and self:checkForPotion("p_slowfall_s") then
      self.timers["freefall"] = -(self:consumePotion("p_slowfall_s", "SlowFall"))
   end
end

function gameplay.incrementRapport(self)
   if self.rapportCounter >= 1 and self.MWVars["rapport"] < self.rapportMods.MAX then
      self:updateMWVars({ ["rapport"] = 1 })
   elseif self.rapportCounter <= -1 and self.MWVars["rapport"] > self.rapportMods.MIN then
      self:updateMWVars({ ["rapport"] = -1 })
   end
end

function gameplay.checkRapportGrowth(self)
   if self.features.RAPP_EN == false then return end
   local playerRecord = types.NPC.record(self.player)
   local birthsign = types.Player.getBirthSign(self.player)
   local rapportGrowth = self.rapportMods.BASE
   local bounty = types.Player.getCrimeLevel(self.player)

   if self.features.RAPP_RACE == true and self.followerPrefs.RACE[playerRecord.race] ~= nil then
      rapportGrowth = rapportGrowth + self.followerPrefs.RACE[playerRecord.race]
   end

   if self.features.RAPP_SEX == true and self.followerPrefs.SEX[playerRecord.isMale] ~= nil then
      rapportGrowth = rapportGrowth + self.followerPrefs.SEX[playerRecord.isMale]
   end

   if self.features.RAPP_GUILDS == true then
      local playerFactions = types.NPC.getFactions(self.player)
      for _, v in ipairs(playerFactions) do
         if self.followerPrefs.GUILDS[v] ~= nil then
            if types.NPC.isExpelled(self.player, v) == false then
               rapportGrowth = rapportGrowth + (self.followerPrefs.GUILDS[v] * types.NPC.getFactionRank(self.player, v))
            else
               rapportGrowth = rapportGrowth + (self.followerPrefs.GUILDS[v] * self.rapportMods.EXPELLED_MULT)
            end
         end
      end
   end

   if self.features.RAPP_BIRTH_SIGN == true and self.followerPrefs.BIRTH_SIGN[birthsign] ~= nil then
      rapportGrowth = rapportGrowth + self.followerPrefs.BIRTH_SIGN[birthsign]
   end

   if self.features.RAPP_CLASS == true and self.followerPrefs.CLASS[playerRecord.class] ~= nil then
      rapportGrowth = rapportGrowth + self.followerPrefs.CLASS[playerRecord.class]
   end

   if self.features.RAPP_DISP == true then
      local dispositionMod = ((types.NPC.getDisposition(self.selfObj, self.player) + self.rapportMods.DISP_MOD) / self.rapportMods.DISP_DIV)
      rapportGrowth = rapportGrowth + dispositionMod
   end

   if self.features.RAPP_BOUNTY == true and bounty > 0 then
      self.rapportCounter = self.rapportCounter + self.rapportMods.BOUNTY_MOD + (bounty * self.rapportMods.BOUNTY_MULT)
   end

   self.rapportCounter = self.rapportCounter + rapportGrowth
   if (self.rapportCounter >= self.rapportMods.GROWTH_THRESHOLD or self.rapportCounter <= self.rapportMods.DECAY_THRESHOLD) then
      self:incrementRapport()
      self.rapportCounter = 0
   end
end


function gameplay.castSpell(self, spell, castSound)
   local duration = self.defaultCd.SPELL


   self.dynamicStats[2](self.selfObj).current = self.dynamicStats[2](self.selfObj).current - spell.cost
   if false then
      return 0
   end
   types.Actor.activeSpells(self.selfObj):add({
      id = spell.id,
      effects = { 0 },
      name = spell.name,
      caster = self.selfObj,
   })
   for _, effect in pairs((spell.effects)) do
      local vfx = effect.effect
      self.selfObj:sendEvent('AddVfx', {
         model = types.Static.record(vfx.castStatic).model,
         options = {
            vfxId = "followerCast" .. effect.id,
            particleTextureOverride = vfx.particle,
            loop = false,
         },
      })

      core.sound.playSound3d(castSound, self.selfObj, {})
      if duration < effect.duration then
         duration = effect.duration
      end
   end
   return duration
end

function gameplay.useEnchantment(self, itemRecord, effectName, castSound)
   local item = types.Actor.inventory(self.selfObj):find(itemRecord.id)
   local enchantment = (core.magic.enchantments.records)[itemRecord.enchant]
   local duration = self.defaultCd.SCROLL
   if effectName ~= nil then
      for _, effect in pairs((enchantment.effects)) do
         local vfx = effect.effect
         self.selfObj:sendEvent('AddVfx', {
            model = types.Static.record(vfx.castStatic).model,
            options = {
               vfxId = "followerCast" .. effect.id,
               particleTextureOverride = vfx.particle,
               loop = false,
            },
         })

         core.sound.playSound3d(castSound, self.selfObj, {})
         if vfx.name == effectName then
            duration = effect.duration
         end
      end
   end
   types.Actor.activeSpells(self.selfObj):add({
      id = itemRecord.id,
      effects = { 0 },
      name = itemRecord.name,
      caster = self.selfObj,
   })
   core.sendGlobalEvent("changeEnchCharge", { item, enchantment.cost })
   return duration
end

function gameplay.consumePotion(self, potionID, effectName)
   local potion = types.Actor.inventory(self.selfObj):find(potionID)
   local potionEffects = types.Potion.record(potion).effects
   local duration = self.defaultCd.POTION
   if effectName ~= nil then
      for i = 1, #potionEffects do
         if potionEffects[i].effect.name == effectName then
            duration = potionEffects[i].duration
            break
         end
      end
   end
   core.sendGlobalEvent("UseItem", { object = potion, actor = self.selfObj })
   return duration
end

function gameplay.useScroll(self, scrollId, effectName, castSound)
   local scroll = types.Actor.inventory(self.selfObj):find(scrollId)
   local scrollRecord = types.Book.record(scroll)
   local scrollEffects = (core.magic.enchantments.records)[scrollRecord.enchant].effects
   local duration = self.defaultCd.SCROLL
   if effectName ~= nil then
      for _, effect in pairs((scrollEffects)) do
         local vfx = effect.effect
         self.selfObj:sendEvent('AddVfx', {
            model = types.Static.record(vfx.castStatic).model,
            options = {
               vfxId = "followerCast" .. effect.id,
               particleTextureOverride = vfx.particle,
               loop = false,
            },
         })

         core.sound.playSound3d(castSound, self.selfObj, {})
         if vfx.name == effectName then
            duration = effect.duration
         end
      end
   end
   types.Actor.activeSpells(self.selfObj):add({
      id = scrollId,
      effects = { 0 },
      name = scrollRecord.name,
      caster = self.selfObj,
   })
   core.sendGlobalEvent('ConsumeItem', { item = scroll, amount = 1 })

   return duration
end

function gameplay.selectRestoreEnch(self, effectId, attrDiff, itemType)
   local inventory = types.Actor.inventory(self.selfObj)
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

function gameplay.selectRestoreSpell(self, effectId, attrDiff)
   local spells = types.Actor.spells(self.selfObj)
   local currentMagicka = self.dynamicStats[2](self.selfObj).current
   local selectedSpell
   local selectedMagnitude
   local selectedHealQuality
   for _, spell in pairs((spells)) do
      if spell.type == core.magic.SPELL_TYPE.Spell or (spell.type == core.magic.SPELL_TYPE.Power and types.Actor.activeSpells(self.selfObj):canUsePower(spell.id) == true) then
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

function gameplay.selectRestorePotion(self, effectId, attrDiff, attrMax)
   local inventory = types.Actor.inventory(self.selfObj)
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
      (((selectedMagnitude * self.restoreConsts.POTION_WASTE) < attrDiff) or
      (attrDiff > (attrMax * self.restoreConsts.PANIC_THRESHOLD))) then

      return { selectedPotion.id, selectedHealQuality }
   else
      return nil
   end
end

function gameplay.selectRestoreScroll(self, effectId, attrDiff, attrMax)
   local inventory = types.Actor.inventory(self.selfObj)
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
      (((selectedMagnitude * self.restoreConsts.SCROLL_WASTE) < attrDiff) or
      (attrDiff > (attrMax * self.restoreConsts.PANIC_THRESHOLD))) then

      return { selectedScroll.id, selectedHealQuality }
   else
      return nil
   end
end

function gameplay.chooseRestoreMethod(self, iter)













   local methodAction = {
      ["encharmor"] = function(method) self.restoreDynStat[iter].enchantmentTimer = self:useEnchantment((method.data), self.restoreDynStat[iter].effectName, "restoration cast") end,
      ["enchclothing"] = function(method) self.restoreDynStat[iter].enchantmentTimer = self:useEnchantment((method.data), self.restoreDynStat[iter].effectName, "restoration cast") end,
      ["enchweapon"] = function(method) self.restoreDynStat[iter].enchantmentTimer = self:useEnchantment((method.data), self.restoreDynStat[iter].effectName, "restoration cast") end,
      ["spell"] = function(method) self.restoreDynStat[iter].spellTimer = self:castSpell((method.data), "restoration cast") end,
      ["potion"] = function(method) self.restoreDynStat[iter].potionTimer = self:consumePotion((method.data), self.restoreDynStat[iter].effectName) end,
      ["scroll"] = function(method) self.restoreDynStat[iter].scrollTimer = self:useScroll((method.data), self.restoreDynStat[iter].effectName, "restoration cast") end,
   }
   local attrDiff = cmn.getDynStatDiff(self.dynamicStats[iter](self.selfObj))
   local restoreMethods = {}
   if self.features.REST_ENCHANT_USE == true and self.restoreDynStat[iter].enchantmentTimer <= 0 then
      local armor = self:selectRestoreEnch(self.restoreDynStat[iter].effectId, attrDiff, types.Armor)
      if armor ~= nil then
         table.insert(restoreMethods, {
            name = "encharmor",
            data = armor[1],
            weight = armor[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.ENCHANTMENT_WEIGHT),
         })
      end
      local clothing = self:selectRestoreEnch(self.restoreDynStat[iter].effectId, attrDiff, types.Clothing)
      if clothing ~= nil then
         table.insert(restoreMethods, {
            name = "enchclothing",
            data = clothing[1],
            weight = clothing[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.ENCHANTMENT_WEIGHT),
         })
      end
      local weapon = self:selectRestoreEnch(self.restoreDynStat[iter].effectId, attrDiff, types.Weapon)
      if weapon ~= nil then
         table.insert(restoreMethods, {
            name = "enchweapon",
            data = weapon[1],
            weight = weapon[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.ENCHANTMENT_WEIGHT),
         })
      end
   end
   if self.features.REST_SPELL_USE == true and self.restoreDynStat[iter].spellTimer <= 0 and self.dynamicStats[2](self.selfObj).current > 0 then
      local spell = self:selectRestoreSpell(self.restoreDynStat[iter].effectId, attrDiff)
      if spell ~= nil then
         table.insert(restoreMethods, {
            name = "spell",
            data = spell[1],
            weight = spell[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.SPELL_WEIGHT),
         })
      end
   end
   if self.features.REST_POTION_USE == true and self.restoreDynStat[iter].potionTimer <= 0 then
      local potion = self:selectRestorePotion(self.restoreDynStat[iter].effectId, attrDiff, cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)))
      if potion ~= nil then
         table.insert(restoreMethods, {
            name = "potion",
            data = potion[1],
            weight = potion[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.POTION_WEIGHT),
         })
      end
   end
   if self.features.REST_SCROLL_USE == true and self.restoreDynStat[iter].scrollTimer <= 0 then
      local scroll = self:selectRestoreScroll(self.restoreDynStat[iter].effectId, attrDiff, cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)))
      if scroll ~= nil then
         table.insert(restoreMethods, {
            name = "scroll",
            data = scroll[1],
            weight = scroll[2] + (cmn.getMaxDynStat(self.dynamicStats[iter](self.selfObj)) * self.restoreConsts.SCROLL_WEIGHT),
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
   self.timers["restorecooldown"] = self.defaultCd.RESTORE
end

function gameplay.checkDynStats(self)
   for i = 1, #self.dynamicStats do
      if self.features.REST_DYN_STATS == true and cmn.getDynStatMissingPerc(self.dynamicStats[i](self.selfObj)) <= self.restoreConsts.TRIGGER_PERC and self.timers["restorecooldown"] <= 0 then
         self:chooseRestoreMethod(i)
      end
   end
end



local movement = {}

function movement.forceZLevel(self)
   local playerPos = (self:getPlayerCellPos())
   local followerPos = self.selfObj.position
   if self.checks["fly"] == true and types.Actor.getStance(self.selfObj) == types.Actor.STANCE.Weapon then
      core.sendGlobalEvent("teleport", {
         actor = self.selfObj,
         cell = self.selfObj.cell.name,
         position = util.vector3(followerPos.x, followerPos.y, playerPos.cellPos.z),
      })
   end
end

function movement.maintainDistance(self)
   local followerPos = self.selfObj.position
   local playerPos = (self:getPlayerCellPos())
   if playerPos == nil then
      return
   end
   if self:isFollowing() and self.MWVars["compmove"] == self.mwBool.TRUE and self.checks["cMove"] == false and
      cmn.getCoDist(followerPos, playerPos.cellPos) < self.distanceThreshold.MAINTAIN_LOWER then

      self.ai.removePackages("Follow")
      self.ai.startPackage({
         type = "Wander",
         distance = self.distanceThreshold.WANDER,
      })
      self.checks["cMove"] = true
   end
   if self.checks["cMove"] == true and cmn.getCoDist(followerPos, playerPos.cellPos) > self.distanceThreshold.MAINTAIN_UPPER then
      self.ai.removePackages("Wander")
      self:makeCompanionFollow()
      self.checks["cMove"] = false
   end
end

function movement.nudge(self, timePassed)
   if self.MWVars["onetimemove"] == self.mwBool.TRUE then
      self.timers["move"] = self.timers["move"] + timePassed
      if self.timers["move"] >= self.NUDGE_DELAY then
         self.timers["move"] = 0
         self:makeCompanionFollow()
         self:updateMWVars({ ["onetimemove"] = self.mwBool.FALSE })
      end
   end
end

function movement.warpToPlayer(self)
   self.posA = self:getPlayerCellPos()
   if self.posA == nil then return end
   if self.doOnce == false then
      self.posB = self:getPlayerCellPos()
      self.doOnce = true
   end
   local coDist = cmn.getCoDist((self.posA).cellPos, self.posB.cellPos)
   if coDist > 360 then self.doOnce = false end
   if (coDist > 180 and self.doOnce2 == false) or self.posC == nil then
      self.posC = self:getPlayerCellPos()
      self.doOnce2 = true
   end
   local coDist2 = cmn.getCoDist((self.posA).cellPos, (self.posC).cellPos)
   if coDist2 > 360 then self.doOnce2 = false end
   if self.timers["warp"] <= 0 and cmn.getCoDist(self.selfObj.position, (self:getPlayerCellPos()).cellPos) > 680 then
      if coDist > 350 then
         core.sendGlobalEvent("teleport", {
            actor = self.selfObj,
            cell = (self.posC).cellId,
            position = (self.posC).cellPos,
         })
         self:makeCompanionFollow()
      elseif coDist2 > 350 then
         core.sendGlobalEvent("teleport", {
            actor = self.selfObj,
            cell = self.posB.cellId,
            position = self.posB.cellPos,
         })
         self:makeCompanionFollow()
      end
   end
end

function movement.setDefaultSpeed(self)
   types.Actor.stats.attributes.speed(self.selfObj).modifier = self.statMod.WANDER
end

function movement.modSpeedAndAthletics(self)
   local followerSpeed = types.Actor.stats.attributes.speed(self.selfObj)
   local followerAthletics = types.NPC.stats.skills.athletics(self.selfObj)
   local cSpeed = types.Actor.stats.attributes.speed(self.player).modified * self.statMod.CATCHUP_MULT
   local cAthletics = types.NPC.stats.skills.athletics(self.player).modified * self.statMod.CATCHUP_MULT
   if (followerSpeed.modifier ~= self.statMod.FOLLOW or followerAthletics.modifier ~= self.statMod.FOLLOW) and
      (cmn.getCoDist(self.selfObj.position, self:getPlayerCellPos().cellPos) <= self.distanceThreshold.MOD_SPEED) then

      followerSpeed.modifier = self.statMod.FOLLOW
      followerAthletics.modifier = self.statMod.FOLLOW
   elseif (followerSpeed.modifier ~= cSpeed or followerAthletics.modifier ~= cAthletics) and
      (cmn.getCoDist(self.selfObj.position, self:getPlayerCellPos().cellPos) > self.distanceThreshold.MOD_SPEED) then

      followerSpeed.modifier = cSpeed
      followerAthletics.modifier = cAthletics
   end
end



local function defaultFollower()
   return {

      selfObj = nil,
      dynamicStats = { types.Actor.stats.dynamic.health, types.Actor.stats.dynamic.magicka, types.Actor.stats.dynamic.fatigue },
      ai = nil,
      mwBool = {
         TRUE = 1,
         FALSE = 0,
      },



      RAPPORT_GROWTH_THRESHOLD = Const.Rapport.GrowthThreshold,
      NUDGE_DELAY = Const.CDs.NudgeDelay,
      DELAY1 = Const.Delay1,
      DELAY2 = Const.Delay2,
      features = {
         REST_DYN_STATS = Const.FeatureFlags.RestoreDynStats.Enable,
         REST_ENCHANT_USE = Const.FeatureFlags.RestoreDynStats.Enchant,
         REST_SPELL_USE = Const.FeatureFlags.RestoreDynStats.Spell,
         REST_POTION_USE = Const.FeatureFlags.RestoreDynStats.Potion,
         REST_SCROLL_USE = Const.FeatureFlags.RestoreDynStats.Scroll,
         RAPP_EN = Const.FeatureFlags.Rapport.Enable,
         RAPP_RACE = Const.FeatureFlags.Rapport.Race,
         RAPP_SEX = Const.FeatureFlags.Rapport.Sex,
         RAPP_GUILDS = Const.FeatureFlags.Rapport.Guilds,
         RAPP_BIRTH_SIGN = Const.FeatureFlags.Rapport.BirthSign,
         RAPP_CLASS = Const.FeatureFlags.Rapport.Class,
         RAPP_DISP = Const.FeatureFlags.Rapport.Disp,
         RAPP_BOUNTY = Const.FeatureFlags.Rapport.Bounty,
      },
      statMod = {
         CATCHUP_MULT = Const.StatMods.CatchupMultiplier,
         FOLLOW = Const.StatMods.DefaultSpeed,
         WANDER = Const.StatMods.WanderSpeed,
      },
      defaultCd = {
         RESTORE = Const.Restore.CDs.General,
         ENCHANTMENT = Const.Restore.CDs.Enchantment,
         SPELL = Const.Restore.CDs.Spell,
         POTION = Const.Restore.CDs.Potion,
         SCROLL = Const.Restore.CDs.Scroll,
         WARP = Const.CDs.Warp,
         SHEATHE = Const.CDs.Sheathe,
      },
      restoreConsts = {
         TRIGGER_PERC = Const.Restore.Thresholds.Trigger,
         PANIC_THRESHOLD = Const.Restore.Thresholds.Panic,
         ENCHANTMENT_WEIGHT = Const.Restore.Weights.Enchantment,
         SPELL_WEIGHT = Const.Restore.Weights.Spell,
         POTION_WEIGHT = Const.Restore.Weights.Potion,
         POTION_WASTE = Const.Restore.Thresholds.PotionWaste,
         SCROLL_WEIGHT = Const.Restore.Weights.Scroll,
         SCROLL_WASTE = Const.Restore.Thresholds.ScrollWaste,
      },
      distanceThreshold = {
         MOD_SPEED = Const.Thresholds.ModifySpeed,
         MAINTAIN_LOWER = Const.Thresholds.MaintainDistLower,
         MAINTAIN_UPPER = Const.Thresholds.MaintainDistUpper,
         WANDER = Const.Thresholds.Wander,
      },
      followerPrefs = {
         RACE = Const.Rapport.Preferences.Races,
         SEX = Const.Rapport.Preferences.Sexes,
         GUILDS = Const.Rapport.Preferences.Guilds,
         BIRTH_SIGN = Const.Rapport.Preferences.BirthSigns,
         CLASS = Const.Rapport.Preferences.Classes,
      },
      rapportMods = {
         BASE = Const.Rapport.BaseModifier,
         DISP_MOD = Const.Rapport.DispModifier,
         DISP_DIV = Const.Rapport.DispDivisor,
         EXPELLED_MULT = Const.Rapport.ExpelledModifier,
         GROWTH_THRESHOLD = Const.Rapport.GrowthThreshold,
         DECAY_THRESHOLD = Const.Rapport.DecayThreshold,
         MAX = Const.Rapport.Max,
         MIN = Const.Rapport.Min,
      },


      player = nil,
      rapportCounter = 0,
      checks = {
         ["cMove"] = false,
         ["fly"] = false,
         ["ww"] = false,
         ["combat"] = false,
         ["incapacitated"] = false,
         ["playerSneak"] = false,
      },
      restoreDynStat = {
         [1] = {
            potionTimer = 0,
            spellTimer = 0,
            scrollTimer = 0,
            enchantmentTimer = 0,
            effectName = "Restore Health",
            effectId = "restorehealth",
         },
         [2] = {
            potionTimer = 0,
            spellTimer = 0,
            scrollTimer = 0,
            enchantmentTimer = 0,
            effectName = "Restore Magicka",
            effectId = "restoremagicka",
         },
         [3] = {
            potionTimer = 0,
            spellTimer = 0,
            scrollTimer = 0,
            enchantmentTimer = 0,
            effectName = "Restore Fatigue",
            effectId = "restorefatigue",
         },
      },
      timers = {
         ["move"] = 0,
         ["sheathe"] = 0,
         ["warp"] = 0,
         ["freefall"] = 0,
         ["restorecooldown"] = 0,
      },


      posA = nil,
      posB = nil,
      posC = nil,
      doOnce = false,
      doOnce2 = false,




      MWVars = {},













      delayUpdate1 = handler.delayUpdate1,
      delayUpdate2 = handler.delayUpdate2,
      onUpdate = handler.onUpdate,
      onSave = handler.onSave,
      onLoad = handler.onLoad,
      onActivated = handler.onActivated,

      updateMWVars = utility.updateMWVars,
      isFollowing = utility.isFollowing,
      getPlayerLeader = utility.getPlayerLeader,
      fullHeal = utility.fullHeal,
      checkForPotion = utility.checkForPotion,
      getPlayerCellPos = utility.getPlayerCellPos,
      setSheatheWarpTimers = utility.setSheatheWarpTimers,
      updateTimers = utility.updateTimers,
      resetDialogueVars = utility.resetDialogueVars,

      setSneak = gameplay.setSneak,
      makeCompanionFollow = gameplay.makeCompanionFollow,
      toggleEffect = gameplay.toggleEffect,
      freeFall = gameplay.freeFall,
      incrementRapport = gameplay.incrementRapport,
      checkRapportGrowth = gameplay.checkRapportGrowth,
      castSpell = gameplay.castSpell,
      useEnchantment = gameplay.useEnchantment,
      consumePotion = gameplay.consumePotion,
      useScroll = gameplay.useScroll,
      selectRestoreEnch = gameplay.selectRestoreEnch,
      selectRestoreSpell = gameplay.selectRestoreSpell,
      selectRestorePotion = gameplay.selectRestorePotion,
      selectRestoreScroll = gameplay.selectRestoreScroll,
      chooseRestoreMethod = gameplay.chooseRestoreMethod,
      checkDynStats = gameplay.checkDynStats,

      forceZLevel = movement.forceZLevel,
      maintainDistance = movement.maintainDistance,
      nudge = movement.nudge,
      warpToPlayer = movement.warpToPlayer,
      setDefaultSpeed = movement.setDefaultSpeed,
      modSpeedAndAthletics = movement.modSpeedAndAthletics,
   }
end






local function constructor(_, child)
   child.base = defaultFollower()
   return setmetatable(child,
   { __index = setmetatable(child.base,
{ __index = {
   selfObj = child.self,
   controls = child.self.controls,
}, }),
   })
end

return setmetatable({}, { __call = constructor })
