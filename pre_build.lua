local lfs = require"lfs"

local projDir = lfs.currentdir()
local src = projDir .. "/scripts/scripts/safl_shies/common.tl"
local dest = projDir .. "/scripts/safl_shies"

for file in lfs.dir(dest) do
	if file ~= nil and file ~= "." and file ~= ".." then
		if string.sub(file, -4) == ".lua" then
			os.remove(dest .. "/" .. file)
		end
	end
end

local infile = io.open(src, "r")
if infile ~= nil then
	local instr = infile:read("*a")
	infile:close()
	
	local outfile = io.open(dest .. "/common.tl", "w")
	if outfile ~= nil then
		outfile:write(instr)
		outfile:close()
	end
end