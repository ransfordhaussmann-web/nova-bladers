--[[
	Places an imported GLB model into ReplicatedStorage.NovaBladers.Models.NovaStriker.
	Used by NovaStrikerAutoImport (Play) and setup-in-studio.lua (Command Bar).
]]

local ModelImport = {}

local TARGET_SIZE = 3.5
local MODEL_NAME = "NovaStriker"

local SKIP_NAMES = {
	Hub = true,
	Arena = true,
	Terrain = true,
	Camera = true,
}

function ModelImport.findImportedInWorkspace()
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and not SKIP_NAMES[child.Name] and not child.Name:match("^Bey_") then
			if child:FindFirstChildWhichIsA("MeshPart", true) or child:FindFirstChildWhichIsA("Part", true) then
				return child
			end
		end
	end
	return nil
end

function ModelImport.install(model, novaFolder)
	if not model or not model:IsA("Model") then
		return false, "No model"
	end

	local nova = novaFolder or game:GetService("ReplicatedStorage"):FindFirstChild("NovaBladers")
	if not nova then
		return false, "NovaBladers folder missing — connect Rojo first"
	end

	local modelsFolder = nova:FindFirstChild("Models")
	if not modelsFolder then
		modelsFolder = Instance.new("Folder")
		modelsFolder.Name = "Models"
		modelsFolder.Parent = nova
	end

	local old = modelsFolder:FindFirstChild(MODEL_NAME)
	if old then
		old:Destroy()
	end

	local clone = model:Clone()

	local _, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > 0.01 then
		local scale = TARGET_SIZE / maxDim
		pcall(function()
			clone:ScaleTo(scale)
		end)
	end

	local cf, _size2 = clone:GetBoundingBox()
	clone:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(math.rad(-90), 0, 0))

	for _, p in clone:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end

	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		clone.PrimaryPart = primary
		if primary.Name ~= "Hull" then
			primary.Name = "Hull"
		end
	end

	clone.Name = MODEL_NAME
	clone.Parent = modelsFolder

	if model.Parent == workspace then
		model:Destroy()
	end

	return true, MODEL_NAME
end

return ModelImport
