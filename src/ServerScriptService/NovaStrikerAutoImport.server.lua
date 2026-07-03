--[[
	Studio auto-import: after File → Import 3D (NovaStriker.glb), press Play once.
	Moves the mesh from Workspace into ReplicatedStorage.NovaBladers.Models.NovaStriker.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local ModelImport = require(ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("ModelImport"))

task.defer(function()
	local imported = ModelImport.findImportedInWorkspace()
	if not imported then
		return
	end

	local ok, result = ModelImport.install(imported)
	if ok then
		print("[NovaBladers] 3D model installed:", result)
		print("[NovaBladers] Save your place file (File → Save to File) to keep the model.")
	else
		warn("[NovaBladers] 3D import failed:", result)
	end
end)
