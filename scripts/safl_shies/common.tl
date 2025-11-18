local util = require('openmw.util')
local core = require('openmw.core')

-- get pwned

local type Flag = enum
	"cMove"
	"fly"
	"ww"
	"combat"
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
	types: {PotionArr}
end

local interface SaveData
	version: number
	recallLoc: CellLoc
	player: core.GameObject
	checks: {Flag: boolean}
	playerSneaking: boolean
	doOnce: boolean
	doOnce2: boolean
	moveTimer: number
	sheatheTimer: number
	warpTimer: number
	freeFallTimer: number
	counter: number
	posA: CellLoc
	posB: CellLoc
	posC: CellLoc
	potionsArr: {Potions}
end

return {
	Flag = Flag,
    SaveData = SaveData,
    Potions = Potions,
	PotionArr = PotionArr,
	CellLoc = CellLoc
}