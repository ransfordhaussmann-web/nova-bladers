local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)
local BeyModelBuilder = require(ReplicatedStorage.NovaBladers.BeyModelBuilder)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubBeyLabor = {}

local function makePedestal(parent, position, color)
	local base = Instance.new("Part")
	base.Name = "Pedestal"
	base.Anchored = true
	base.CanCollide = true
	base.Size = Vector3.new(3.5, HubConfig.BEY_LABOR.pedestalHeight, 3.5)
	base.CFrame = CFrame.new(position + Vector3.new(0, HubConfig.BEY_LABOR.pedestalHeight / 2, 0))
	base.Color = Color3.fromRGB(40, 45, 58)
	base.Material = Enum.Material.Slate
	base.Parent = parent

	local ring = Instance.new("Part")
	ring.Name = "PedestalRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 4, 4)
	ring.CFrame = base.CFrame * CFrame.new(0, HubConfig.BEY_LABOR.pedestalHeight / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Parent = parent

	return base
end

function HubBeyLabor.build(hubFolder, origin)
	local laborFolder = Instance.new("Folder")
	laborFolder.Name = "BeyLabor"
	laborFolder.Parent = hubFolder

	local center = origin + HubConfig.BEY_LABOR.offset
	local radius = HubConfig.BEY_LABOR.radius
	local displayModels = {}

	local sign = Instance.new("Part")
	sign.Name = "BeyLaborSign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Size = Vector3.new(8, 0.5, 1)
	sign.CFrame = CFrame.new(center + Vector3.new(0, 6, -radius - 2))
	sign.Color = Color3.fromRGB(50, 55, 70)
	sign.Material = Enum.Material.Metal
	sign.Parent = laborFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(180, 220, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = "Bey-Labor"
	label.Parent = billboard

	for i, bey in ipairs(BeyCatalog) do
		local angle = (i - 1) * (math.pi * 2 / #BeyCatalog) - math.pi / 2
		local pos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		makePedestal(laborFolder, pos, bey.color)

		local spawnCFrame = CFrame.new(pos + Vector3.new(0, HubConfig.BEY_LABOR.pedestalHeight + 1.5, 0))
		local built = BeyModelBuilder.build(bey, spawnCFrame)
		local model = built.model
		model.Name = "Display_" .. bey.id

		for _, desc in model:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
			end
		end

		model.Parent = laborFolder
		table.insert(displayModels, model)

		local nameGui = Instance.new("BillboardGui")
		nameGui.Size = UDim2.fromOffset(140, 36)
		nameGui.StudsOffset = Vector3.new(0, 3, 0)
		nameGui.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.fromScale(1, 1)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = bey.color
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Text = bey.name
		nameLabel.Parent = nameGui
	end

	local spinSpeed = HubConfig.BEY_LABOR.spinSpeed
	RunService.Heartbeat:Connect(function(dt)
		for _, model in displayModels do
			if model.Parent then
				local pivot = model:GetPivot()
				model:PivotTo(pivot * CFrame.Angles(0, dt * spinSpeed, 0))
			end
		end
	end)

	return laborFolder
end

return HubBeyLabor
