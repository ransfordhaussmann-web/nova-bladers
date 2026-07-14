--[[
  Paste into Roblox Studio Command Bar AFTER importing NovaStriker.glb.
  Run once per import. Requires ReplicatedStorage.NovaBladers.Models folder (from Rojo).
]]

local TARGET_SIZE = 3.5
local MODEL_NAME = "NovaStriker"

local function getImportedModel()
	local sel = game:GetService("Selection"):Get()
	if #sel > 0 and sel[1]:IsA("Model") then return sel[1] end
	for _, c in workspace:GetChildren() do
		if c:IsA("Model") and not c.Name:match("^Bey_") then return c end
	end
	return nil
end

local model = getImportedModel()
if not model then
	warn("[NovaStriker Setup] Select the imported model in Workspace first, then run again.")
	return
end

local nova = game:GetService("ReplicatedStorage"):FindFirstChild("NovaBladers")
if not nova then
	warn("[NovaStriker Setup] NovaBladers not found — connect Rojo first.")
	return
end

local modelsFolder = nova:FindFirstChild("Models")
if not modelsFolder then
	modelsFolder = Instance.new("Folder")
	modelsFolder.Name = "Models"
	modelsFolder.Parent = nova
end

local old = modelsFolder:FindFirstChild(MODEL_NAME)
if old then old:Destroy() end

-- Scale to arena size
local _, size = model:GetBoundingBox()
local maxDim = math.max(size.X, size.Y, size.Z)
if maxDim > 0.01 then
	local scale = TARGET_SIZE / maxDim
	pcall(function() model:ScaleTo(scale) end)
end

-- Lay flat (Sketchfab imports often stand upright)
local cf, _ = model:GetBoundingBox()
model:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(math.rad(-90), 0, 0))

for _, p in model:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = false
	end
end

local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
if primary then
	model.PrimaryPart = primary
	local hull = primary
	if not hull:FindFirstChild("Hull") then
		hull.Name = "Hull"
	end
end

model.Name = MODEL_NAME
model.Parent = modelsFolder

print("[NovaStriker Setup] Done! Model placed in ReplicatedStorage.NovaBladers.Models.NovaStriker")
print("[NovaStriker Setup] Press Play and pick Nova Striker to test.")
