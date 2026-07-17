local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local core = require('openmw.core')
local types = require('openmw.types')
local anim = require('openmw.animation')
local this = require('openmw.self')
local storage = require('openmw.storage')








local MWVars

local DYNAMIC_STATS = {
   ["health"] = types.Actor.stats.dynamic.health,
   ["fatigue"] = types.Actor.stats.dynamic.fatigue,
   ["magicka"] = types.Actor.stats.dynamic.magicka,
}

local argonianTaper = {
   conditions = {
      {
         race = { "argonian" },
         isMale = true,
         werewolf = false,
         dead = false,
         mwvars = {
            companion = { min = 1, max = 1 },


         },
         dynStats = {
            health = { min = 0.5, max = 1, percent = true },

         },
         equipmentslot = {
            ["Ammunition"] = true,
            ["Amulet"] = false,
            "Belt",
            "Boots",
            "CarriedLeft",
            "CarriedRight",
            "Cuirass",
            "Greaves",
            "Helmet",
            "LeftGauntlet",
            "LeftPauldron",
            "LeftRing",
            "Pants",
            "RightGauntlet",
            "RightPauldron",
            "RightRing",
            "Robe",
            "Shirt",
            "Skirt",
         },
      },
   },
   mesh = 'Meshes/bat/shiestaper.nif',
   node = "groin",
   duration = -1,
}

local function compareRange(value, r, valueMax)
   if not r.percent then
      if ((r.min > r.max) and (value < r.min) and (value > r.max)) or ((value < r.min) or (value > r.max)) then
         return false
      end
   elseif valueMax ~= nil and valueMax ~= 0 then
      local ratio = value / valueMax
      if ((r.min > r.max) and (ratio < r.min) and (ratio > r.max)) or ((ratio < r.min) or (ratio > r.max)) then
         return false
      end
   else
      return false
   end
   return true
end

local function applyCosmetic(effectID, node, mesh)
   anim.addVfx(this, mesh, {
      loop = true,
      boneName = node,
      vfxId = effectID,
      useAmbientLight = false,
   })
end

local function removeCosmetic(effectID)
   anim.removeVfx(this, effectID)
end

local function checkEquipmentSlots()

end

local function checkDynStats(attributes)
   for k, range in pairs(attributes) do
      local getStat = DYNAMIC_STATS[k];
      local dynStat = getStat and getStat(this.object)
      if dynStat and compareRange(dynStat.current, range, dynStat.base + dynStat.modifier) == false then
         return false
      end
   end
   return true
end

local function checkMWVars(mwvars)
   local varTable = storage.globalSection(this.object.id)
   if varTable == nil then
      return false
   end
   for k, range in pairs(mwvars) do
      local value = varTable:get(k)
      if value == nil or compareRange(value, range, range.maxValue) == false then
         return false
      end
   end
   return true
end

local function checkDead(actorDead, condDead)
   return actorDead == condDead
end

local function checkWerewolf(actorWerewolf, condWerewolf)
   return actorWerewolf == condWerewolf
end

local function checkSex(actorSex, condSex)
   return actorSex == condSex
end

local function checkRace(actorRace, condRace)
   for i = 1, #condRace do
      if actorRace == condRace[i] then
         return true
      end
   end
   return false
end

local function checkEffectConditions()
   local conditions = argonianTaper.conditions
   local effectID = "taper"

   for i = 1, #conditions do
      if conditions[i].race ~= nil and checkRace(types.NPC.record(this.object).race, conditions[i].race) == false then


         removeCosmetic(effectID)
         return
      end
      if conditions[i].isMale ~= nil and checkSex(types.NPC.record(this.object).isMale, conditions[i].isMale) == false then


         removeCosmetic(effectID)
         return
      end
      if conditions[i].werewolf ~= nil and checkWerewolf(types.NPC.isWerewolf(this.object), conditions[i].werewolf) == false then


         removeCosmetic(effectID)
         return
      end
      if conditions[i].dead ~= nil and checkDead(types.Actor.isDead(this.object), conditions[i].dead) == false then


         removeCosmetic(effectID)
         return
      end
      if conditions[i].mwvars ~= nil and checkMWVars(conditions[i].mwvars) == false then


         removeCosmetic(effectID)
         return
      end
      if conditions[i].dynStats ~= nil and checkDynStats(conditions[i].dynStats) == false then


         removeCosmetic(effectID)
         return
      end






   end
   applyCosmetic(effectID, argonianTaper.node, argonianTaper.mesh)
end

return {
   engineHandlers = {
      onActive = function()
         checkEffectConditions()
      end,
      onUpdate = checkEffectConditions,
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
   },
}
