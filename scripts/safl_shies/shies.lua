
local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')
local nearby = require('openmw.nearby')















local scriptVersion = 1
local INIT_DATA = { markedPos = { recallCellId = "Balmora, Council Club", recallPos = util.vector3(-5, -218, -251) } }
local RECALL_LOC
local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local health = types.Actor.stats.dynamic.health
local selfObj = self




local function onInit()
   RECALL_LOC = INIT_DATA.markedPos
end


local function onSave()
   return {
      version = scriptVersion,
      markedPos = RECALL_LOC,
   }
end


local function onLoad(data)
   if (not data) or (not data.version) or (data.version < scriptVersion) then
      print('Was saved with an old version of the script, initializing to default')
      RECALL_LOC = INIT_DATA.markedPos
      return
   elseif (data.version > scriptVersion) then
      error('Required update to a new version of the script')
   elseif (data.version == scriptVersion) then
      RECALL_LOC = data.markedPos
   else

   end
end



local function triggerShiesFledQuest()
   local players = nearby.players
   for i = 1, #players do
      print("shies fled 0")
      players[i]:sendEvent("shiesFled", nil)
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
      if RECALL_LOC == INIT_DATA.markedPos then

         triggerShiesFledQuest()
      end
      return core.sendGlobalEvent("teleport", {
         actor = actor,
         cell = RECALL_LOC.recallCellId,
         position = RECALL_LOC.recallPos,
      })
   end,
   nil)

   time.newSimulationTimer(RECALL_TIMEOUT, cb, self, nil)
end

return {
   engineHandlers = {
      onUpdate = function()
         if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then

            flee()

            heal()
         end
      end,
      onInit = onInit,
      onSave = onSave,
      onLoad = onLoad,
   },
   eventHandlers = {

      ["Hit"] = function(attack)
         local attackerObj = attack.attacker
         attackerObj:sendEvent("shiesAttacked", "Why did you do that :(\nincremdibly rude...")
      end,

      ["hurtShies"] = function()
         health(selfObj).current = 1
      end,
   },
}
