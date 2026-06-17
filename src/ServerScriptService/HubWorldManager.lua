local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldManager = {}

local hubFolder = nil
local spawnPart = nil
local playerInArena = {}

local function getRemotes()
	return ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
end

local function createSign(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

local function createZone(zoneConfig, origin, onTriggered)
	local part = Instance.new("Part")
	part.Name = zoneConfig.id
	part.Anchored = true
	part.CanCollide = true
	part.Size = zoneConfig.size
	part.Position = origin + zoneConfig.offset + Vector3.new(0, zoneConfig.size.Y * 0.5, 0)
	part.Color = zoneConfig.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	part.Parent = hubFolder

	createSign(part, zoneConfig.label, zoneConfig.color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = HubConfig.PROXIMITY.ActionText
	prompt.ObjectText = zoneConfig.label
	prompt.MaxActivationDistance = HubConfig.PROXIMITY.MaxActivationDistance
	prompt.HoldDuration = HubConfig.PROXIMITY.HoldDuration
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		onTriggered(player, zoneConfig)
	end)

	part.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or playerInArena[player] then
			return
		end
		getRemotes().HubZoneHint:FireClient(player, zoneConfig.hint, zoneConfig.label)
	end)
end

function HubWorldManager.getHubFolder()
	return hubFolder
end

function HubWorldManager.getSpawnCFrame()
	if spawnPart then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

function HubWorldManager.isInArena(player)
	return playerInArena[player] == true
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubWorldManager.getSpawnCFrame()
	playerInArena[player] = false
end

function HubWorldManager.sendToArena(player)
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		warn("[HubWorldManager] Arena folder not found:", HubConfig.ARENA_FOLDER_NAME)
		return false
	end

	local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChildWhichIsA("SpawnLocation", true)
	local targetCFrame = HubConfig.HUB_ORIGIN + Vector3.new(0, 5, 0)
	if spawn and spawn:IsA("BasePart") then
		targetCFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	elseif spawn and spawn:IsA("SpawnLocation") then
		targetCFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	end

	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	root.CFrame = targetCFrame
	playerInArena[player] = true
	return true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	getRemotes().ReturnToHub:FireClient(player)
end

function HubWorldManager.init(onZoneAction)
	if hubFolder then
		return hubFolder
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
	else
		hubFolder = Instance.new("Folder")
		hubFolder.Name = HubConfig.HUB_FOLDER_NAME
		hubFolder.Parent = workspace
	end

	if not hubFolder:FindFirstChild("Floor") then
		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Anchored = true
		floor.CanCollide = true
		floor.Size = HubConfig.FLOOR_SIZE
		floor.Position = HubConfig.HUB_ORIGIN + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0)
		floor.Color = HubConfig.FLOOR_COLOR
		floor.Material = Enum.Material.Slate
		floor.Parent = hubFolder

		local spawn = Instance.new("Part")
		spawn.Name = "HubSpawn"
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET
		spawn.Parent = hubFolder
		spawnPart = spawn

		createSign(spawn, "Nova Bladers Hub", Color3.fromRGB(200, 220, 255))
	end

	spawnPart = hubFolder:FindFirstChild("HubSpawn")

	for _, zoneConfig in HubConfig.ZONES do
		if not hubFolder:FindFirstChild(zoneConfig.id) then
			createZone(zoneConfig, HubConfig.HUB_ORIGIN, function(player, config)
				onZoneAction(player, config.action, config)
			end)
		end
	end

	return hubFolder
end

function HubWorldManager.onPlayerAdded(player, onReady)
	playerInArena[player] = false

	local function spawnInHub()
		task.defer(function()
			HubWorldManager.teleportToHub(player)
			if onReady then
				onReady(player)
			end
		end)
	end

	player.CharacterAdded:Connect(spawnInHub)
	if player.Character then
		spawnInHub()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playerInArena[player] = nil
end

return HubWorldManager
