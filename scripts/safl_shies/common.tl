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

return {
	PlayerQuest = PlayerQuest,
	Flag = Flag,
	Timer = Timer,
    SaveData = SaveData,
	RestoreAttr = RestoreAttr,
	CellLoc = CellLoc
}