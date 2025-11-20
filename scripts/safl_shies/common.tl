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
	"restorespell"
end

local interface CellLoc
	cellId: string
	cellPos: util.Vector3
end

local interface PotionArr
	name: string
	count: number
	magnitude: number
end

local interface Potions
	check: boolean
	timer: number
	effectName: string
	effectId: string
	types: {PotionArr}
end

local interface SaveData
	version: number
	recallLoc: CellLoc
	player: core.GameObject
	checks: {Flag: boolean}
	timers: {Timer: number}
	potionsArr: {Potions}
	posA: CellLoc
	posB: CellLoc
	posC: CellLoc
	doOnce: boolean
	doOnce2: boolean
end

return {
	PlayerQuest = PlayerQuest,
	Flag = Flag,
	Timer = Timer,
    SaveData = SaveData,
    Potions = Potions,
	PotionArr = PotionArr,
	CellLoc = CellLoc
}