local lfs = require"lfs"

local projDir = lfs.currentdir()
local src = projDir .. "/scripts/scripts/follower"
local dest = projDir .. "/scripts/follower"
local fileNames = {}

for file in lfs.dir(dest) do -- Deletes all .lua files in build directory
	if file ~= nil and file ~= "." and file ~= ".." then
		if string.sub(file, -4) == ".lua" then
			os.remove(dest .. "/" .. file)
		end
	end
end

for file in lfs.dir(src) do
	if file ~= nil and file ~= "." and file ~= ".." then
		if string.sub(file, -3) == ".tl" then
			table.insert(fileNames, file)
		end
	end
end
for _, fileName in ipairs(fileNames) do
	local infile = io.open(src .. "/" .. fileName, "r")
	if infile ~= nil then
		local instr = infile:read("*a")
		infile:close()

		local outfile = io.open(dest .. "/" .. fileName, "w")
		if outfile ~= nil then
			outfile:write(instr)
			outfile:close()
		end
	end
end