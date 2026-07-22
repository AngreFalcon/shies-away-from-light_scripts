local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local util = require('openmw.util')
local core = require('openmw.core')
local types = require('openmw.types')

local SCRIPT_VERSION = 1






























































local function getMaxDynStat(attr)
   return attr.base + attr.modifier
end

local function getDynStatDiff(attr)
   return getMaxDynStat(attr) - attr.current
end

local function checkDynStatDamaged(attr)
   return attr.current < getMaxDynStat(attr)
end

local function getDynStatMissingPerc(attr)
   local maxStat = getMaxDynStat(attr)
   return (maxStat - attr.current / maxStat)
end


local function getCoDist(vector1, vector2)
   local tempVar1 = vector1.x - vector2.x
   local tempVar2 = vector1.y - vector2.y
   return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end

local function merge(...)
   local result = {}
   for i = 1, select('#', ...) do
      local t = select(i, ...)
      if type(t) == "table" then
         for k, v in pairs(t) do
            result[k] = v
         end
      end
   end
   return result
end


return {
   SCRIPT_VERSION = SCRIPT_VERSION,
   PlayerQuest = PlayerQuest,
   Flag = Flag,
   Timer = Timer,
   SaveData = SaveData,
   RestoreDynStat = RestoreDynStat,
   CellLoc = CellLoc,
   EnchType = EnchType,
   EnchRecord = EnchRecord,
   getMaxDynStat = getMaxDynStat,
   getDynStatDiff = getDynStatDiff,
   checkDynStatDamaged = checkDynStatDamaged,
   getDynStatMissingPerc = getDynStatMissingPerc,
   getCoDist = getCoDist,
   merge = merge,
}
