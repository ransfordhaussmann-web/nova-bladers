local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local HubWorldManager = {}

local hubFolder = nil
local spawnPart = nil
local zoneParts = {}
local playersInArena = {}

local function getOrigin()
	return HubWorldConfig.HUB_ORIGIN
end

local function makePart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function addBillboard(part, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.TextSize = 20
	titleLabel.Text = title
	titleLabel.Parent = gui

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Position = UDim2.fromScale(0, 0.5)
	hintLabel.Size = UDim2.new(1, 0, 0.5, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	hintLabel.TextStrokeTransparency = 0.6
	hintLabel.TextSize = 14
	hintLabel.Text = subtitle
	hintLabel.Parent = gui
end

local function addZoneLight(part, color)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = part
end

function HubWorldManager.build()
	if hubFolder then
		return hubFolder
	end

	local origin = getOrigin()
	hubFolder = Instance.new("Folder")
	hubFolder.Name = "NovaHub"
	hubFolder.Parent = Workspace

	local floor = makePart(
		"HubFloor",
		HubWorldConfig.FLOOR_SIZE,
		CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color3.fromRGB(35, 38, 48),
		hubFolder
	)
	floor.Material = Enum.Material.Slate

	spawnPart = makePart(
		"HubSpawn",
		Vector3.new(6, 1, 6),
		CFrame.new(origin + HubWorldConfig.SPAWN_OFFSET),
		Color3.fromRGB(60, 65, 80),
		hubFolder
	)
	spawnPart.Transparency = 0.4
	spawnPart.CanCollide = false

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawnLocation"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = spawnPart.CFrame
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hubFolder

	for zoneKey, zone in HubWorldConfig.ZONES do
		local pad = makePart(
			zone.id .. "Pad",
			zone.size,
			CFrame.new(origin + zone.offset),
			zone.color,
			hubFolder
		)
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.25
		addBillboard(pad, zone.label, zone.hint)
		addZoneLight(pad, zone.color)
		zoneParts[zoneKey] = pad
	end

	local centerPillar = makePart(
		"HubCenter",
		Vector3.new(4, 12, 4),
		CFrame.new(origin + Vector3.new(0, 6, 0)),
		Color3.fromRGB(90, 100, 130),
		hubFolder
	)
	centerPillar.Material = Enum.Material.Metal

	local sign = makePart(
		"HubSign",
		Vector3.new(16, 3, 1),
		CFrame.new(origin + Vector3.new(0, 14, 0)),
		Color3.fromRGB(50, 55, 70),
		hubFolder
	)
	addBillboard(sign, "Nova Bladers", "Wähle eine Zone")

	return hubFolder
end

function HubWorldManager.getZonePart(zoneKey)
	return zoneParts[zoneKey]
end

function HubWorldManager.getSpawnCFrame()
	local origin = getOrigin()
	if spawnPart then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(origin + HubWorldConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

function HubWorldManager.getArenaEntryCFrame()
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChildWhichIsA("BasePart")
		if bowl then
			return bowl.CFrame * CFrame.new(0, HubWorldConfig.ARENA_ENTRY_OFFSET.Y, 0)
		end
	end
	return CFrame.new(getOrigin() + Vector3.new(0, 6, -80))
end

function HubWorldManager.teleportToHub(player)
	playersInArena[player] = nil
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubWorldManager.getSpawnCFrame()
	end
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubWorldManager.getArenaEntryCFrame()
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.onPlayerRemoving(player)
	playersInArena[player] = nil
end

return HubWorldManager
