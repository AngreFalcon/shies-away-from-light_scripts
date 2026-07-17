local core = require("openmw.core")
local world = require("openmw.world")
local storage = require("openmw.storage")

local function syncMWVars(actor: core.GameObject) -- Get the current state of all local mwscript variables associated with the provided actor
	if actor ~= nil then
		local localScript: world.MWScript = world.mwscript.getLocalScript(actor, nil)
		if localScript ~= nil then
            local varTable = storage.globalSection(actor.id)
			varTable:setLifeTime(storage.LIFE_TIME.GameSession as storage.LifeTime)
			varTable:set("skree", "skree")
            for k, v in pairs((localScript.variables as {string: number})) do
                varTable:set(k, v)
			end
		end
	end
end

return {
   	engineHandlers = {
      	onActorActive = function(actor: core.GameObject) 
         	syncMWVars(actor)
      	end,
		onUpdate = function()
			for i = 1, #world.activeActors do
				syncMWVars(world.activeActors[i])
			end
		end
   	},
}