local util = require('openmw.util')
local core = require('openmw.core')
local types = require('openmw.types')

local interface PlayerQuest is types.PlayerQuest, types.PLAYERQuest end

local type Flag = enum
	"cMove"
	"fly"
	"ww"
	"combat"
	"incapacitated"
	"playerSneak"
end

local type Timer = enum
	"move"
	"sheathe"
	"warp"
	"freefall"
	"restorecooldown"
end

local interface CellLoc
	cellId: string
	cellPos: util.Vector3
end

local interface RestoreAttr
	potionTimer: number
	spellTimer: number
	scrollTimer: number
	enchantmentTimer: number
	effectName: string
	effectId: string
end

local interface SaveData
	version: number
	recallLoc: CellLoc
	player: core.GameObject
	checks: {Flag: boolean}
	timers: {Timer: number}
	restoreAttr: {RestoreAttr}
	posA: CellLoc
	posB: CellLoc
	posC: CellLoc
	doOnce: boolean
	doOnce2: boolean
end

local interface EnchType is types.Item
	record: function(
		id: any
	): EnchRecord
end

local interface EnchRecord
	id: string
	name: string
	enchant: string
end

-- Attribute functions
local function getMaxAttr(attr: types.DynamicStat): number -- Get the maximum value of the specified dynamic stat
	return attr.base + attr.modifier
end
local function getAttrDiff(attr: types.DynamicStat): number -- Get the missing value of the specified dynamic stat
	return getMaxAttr(attr) - attr.current
end
local function checkAttrDamaged(attr: types.DynamicStat): boolean -- Returns true if the provided attribute is not currently full
	return attr.current < getMaxAttr(attr)
end

-- Utility functions
local function getCoDist(vector1: util.Vector3, vector2: util.Vector3): number -- Get cosine distance between two vectors
	local tempVar1 = vector1.x - vector2.x
	local tempVar2 = vector1.y - vector2.y
	return math.sqrt((tempVar1 * tempVar1) + (tempVar2 * tempVar2))
end
local function merge<T>(...: {any: any}): T
    local result = {}
    for i = 1, select('#', ...) do
        local t = select(i, ...)
        if type(t) == "table" then
            for k, v in pairs(t) do
                result[k] = v
            end
        end
    end
    return result as T
end


return {
	PlayerQuest = PlayerQuest,
	Flag = Flag,
	Timer = Timer,
    SaveData = SaveData,
	RestoreAttr = RestoreAttr,
	CellLoc = CellLoc,
	EnchType = EnchType,
	EnchRecord = EnchRecord,
	getMaxAttr = getMaxAttr,
	getAttrDiff = getAttrDiff,
	checkAttrDamaged = checkAttrDamaged,
	getCoDist = getCoDist,
	merge = merge,
}