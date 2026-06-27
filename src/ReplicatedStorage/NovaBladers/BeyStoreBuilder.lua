local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyCatalog = require(script.Parent.BeyCatalog)
local StoreBeyModels = require(script.Parent.StoreBeyModels)

local BeyStoreBuilder = {}

local PEDESTAL_HEIGHT = 2.2
local SPACING = 5

local function createPedestal(name, position, parent)
	local base = Instance.new("Part")
	base.Name = name .. "_Pedestal"
	base.Size = Vector3.new(3.5, PEDESTAL_HEIGHT, 3.5)
	base.Position = position + Vector3.new(0, PEDESTAL_HEIGHT / 2, 0)
	base.Anchored = true
	base.CanCollide = true
	base.Color = Color3.fromRGB(35, 40, 55)
	base.Material = Enum.Material.Slate
	base.Parent = parent

	local rim = Instance.new("Part")
	rim.Name = name .. "_Rim"
	rim.Size = Vector3.new(3.8, 0.2, 3.8)
	rim.Position = base.Position + Vector3.new(0, PEDESTAL_HEIGHT / 2 + 0.1, 0)
	rim.Anchored = true
	rim.CanCollide = false
	rim.Color = Color3.fromRGB(255, 200, 80)
	rim.Material = Enum.Material.Neon
	rim.Parent = parent

	return base
end

local function addNameTag(bey, pedestal)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StoreLabel"
	billboard.Size = UDim2.fromOffset(180, 56)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pedestal

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = bey.color
	label.TextStrokeTransparency = 0.4
	label.TextSize = 16
	label.Text = bey.name .. "\n" .. bey.special
	label.Parent = billboard
end

function BeyStoreBuilder.buildInZone(shopZoneFolder, origin)
	if shopZoneFolder:FindFirstChild("StoreDisplays") then
		return shopZoneFolder.StoreDisplays
	end

	local displays = Instance.new("Folder")
	displays.Name = "StoreDisplays"
	displays.Parent = shopZoneFolder

	local storeItems = StoreBeyModels.getStoreItems()
	local startX = origin.X - ((#storeItems - 1) * SPACING) / 2

	for index, bey in storeItems do
		local x = startX + (index - 1) * SPACING
		local pedestalPos = Vector3.new(x, origin.Y, origin.Z)
		local pedestal = createPedestal(bey.id, pedestalPos, displays)

		local model = StoreBeyModels.build(bey.id, displays)
		if model and model.PrimaryPart then
			model:PivotTo(pedestal.CFrame * CFrame.new(0, PEDESTAL_HEIGHT / 2 + 0.6, 0))
			addNameTag(bey, pedestal)
		end
	end

	local info = Instance.new("Part")
	info.Name = "StoreInfo"
	info.Size = Vector3.new(8, 0.2, 2)
	info.Position = origin + Vector3.new(0, 0.1, -6)
	info.Anchored = true
	info.CanCollide = false
	info.Transparency = 1
	info.Parent = displays

	local infoGui = Instance.new("BillboardGui")
	infoGui.Size = UDim2.fromOffset(320, 40)
	infoGui.StudsOffset = Vector3.new(0, 2, 0)
	infoGui.Parent = info

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.fromScale(1, 1)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamMedium
	infoLabel.TextColor3 = Color3.fromRGB(255, 220, 140)
	infoLabel.TextSize = 18
	infoLabel.Text = "Creator Store — Neue Beys verfügbar!"
	infoLabel.Parent = infoGui

	return displays
end

function BeyStoreBuilder.ensureTemplatesFolder()
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	local templates = nova:FindFirstChild("StoreBeyTemplates")
	if templates then
		return templates
	end

	templates = Instance.new("Folder")
	templates.Name = "StoreBeyTemplates"
	templates.Parent = nova

	for _, bey in BeyCatalog do
		if bey.storeItem and not templates:FindFirstChild(bey.id) then
			StoreBeyModels.build(bey.id, templates)
		end
	end

	return templates
end

return BeyStoreBuilder
