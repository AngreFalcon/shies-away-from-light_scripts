local util = require("openmw.util")
local time = require("openmw_aux.time")
require("scripts.safl_shies.common")

global INIT_DATA: SaveData = {markedPos = {cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251)}}
global RECALL_LOC: CellLoc
global FLEE_THRESHOLD = 0.1
global RECALL_TIMEOUT = 2 * time.second