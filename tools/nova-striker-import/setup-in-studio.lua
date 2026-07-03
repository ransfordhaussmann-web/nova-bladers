--[[
  Paste into Roblox Studio Command Bar AFTER importing NovaStriker.glb.
  Or: import GLB → press Play (NovaStrikerAutoImport.server.lua does this automatically).
]]

local ModelImport = require(game:GetService("ReplicatedStorage").NovaBladers.ModelImport)

local sel = game:GetService("Selection"):Get()
local model = (#sel > 0 and sel[1]:IsA("Model")) and sel[1] or ModelImport.findImportedInWorkspace()

if not model then
	warn("[NovaStriker Setup] Import NovaStriker.glb first, or select the model in Workspace.")
	return
end

local ok, result = ModelImport.install(model)
if ok then
	print("[NovaStriker Setup] Done! Model at ReplicatedStorage.NovaBladers.Models.NovaStriker")
	print("[NovaStriker Setup] Save place file, then Play → Nova Striker.")
else
	warn("[NovaStriker Setup]", result)
end
