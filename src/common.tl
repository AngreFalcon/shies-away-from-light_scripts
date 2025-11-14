local core = require("openmw.core")
local util = require("openmw.util")

global ScriptVersion = 1 -- increment whenever onSave is changed

-- custom types and interfaces
global interface CellLoc
	cellId: string
	cellPos: util.Vector3
end

global interface SaveData
	version: number
	markedPos: CellLoc
end

global interface TeleportData
	actor: core.GameObject
	cellLoc: CellLoc
end
--