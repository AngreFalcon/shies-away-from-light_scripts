local util = require("openmw.util")
local time = require("openmw_aux.time")
require('./common')

INIT_DATA = { markedPos = { cellId = "Balmora, Council Club", cellPos = util.vector3(-5, -218, -251) } }

FLEE_THRESHOLD = 0.1
RECALL_TIMEOUT = 2 * time.second
