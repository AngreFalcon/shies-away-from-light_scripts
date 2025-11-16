local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local I = require('openmw.interfaces')
local types = require('openmw.types')
local self = require('openmw.self')
local core = require('openmw.core')
local ai = require('openmw.interfaces').AI
local time = require('openmw_aux.time')
local util = require('openmw.util')













local ScriptVersion = 1
local health = types.Actor.stats.dynamic.health
local selfObj = self



local FLEE_THRESHOLD = 0.1
local RECALL_TIMEOUT = 2 * time.second
local INIT_DATA = { recallLoc = { cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251) } }



local RECALL_LOC
local PlayerLeader = nil



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
      playerLeader = PlayerLeader,
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
      PlayerLeader = data.playerLeader
   else

   end
end

local function triggerShiesFledQuest()
   if PlayerLeader ~= nil then
      (PlayerLeader):sendEvent("shiesFled", nil)
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
   if currentPackage ~= nil and currentPackage.type == "Follow" then
      return true
   else
      return false
   end
end

local function getPlayerLeader()
   if isShiesFollowing() then
      PlayerLeader = ai.getActiveTarget("Follow")
   end
end

local function getPlayerCellPos()
   if PlayerLeader == nil then
      return nil
   elseif (PlayerLeader) then
      return { cellId = (PlayerLeader).cell.name, cellPos = (PlayerLeader).position }
   end
end

local function getCoDist(vector1, vector2)
   local tempVar1 = vector1.x - vector2.x
   local tempVar2 = vector1.y - vector2.y
   return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function maintainDistance()
   local shiesPos = selfObj.position
   local playerPos = (getPlayerCellPos())
   local c_move = false
   if playerPos == nil then
      return
   end
   if isShiesFollowing() and MWVars["compmove"] == 1 and c_move == false and getCoDist(shiesPos, playerPos.cellPos) < 70 then
      ai.startPackage({
         type = "Wander",
         distance = 300,
      })
      c_move = true
   end
   if c_move == true and getCoDist(shiesPos, playerPos.cellPos) > 100 then
      ai.startPackage({
         type = "Follow",
         target = PlayerLeader,
      })
      c_move = false
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

   if MWVars["warp"] == 0 and getCoDist(selfObj.position, (getPlayerCellPos()).cellPos) > 680 then
      if coDist > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = (posC).cellId,
            position = (posC).cellPos,
         })
         ai.startPackage({
            type = "Follow",
            target = PlayerLeader,
         })
      elseif coDist2 > 350 then
         core.sendGlobalEvent("teleport", {
            actor = selfObj,
            cell = posB.cellId,
            position = posB.cellPos,
         })
         ai.startPackage({
            type = "Follow",
            target = PlayerLeader,
         })
      end
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

return {
   engineHandlers = {
      onUpdate = function()
         getPlayerLeader()
         if getCurrentHealth() / getMaxHealth() < FLEE_THRESHOLD then
            updateMWVar("companion", 0)
            updateMWVar("c_move", 0)
            flee()
            heal()
         end
         if isShiesFollowing() then
            warpToPlayer()
         end
         maintainDistance()
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
   },
}
