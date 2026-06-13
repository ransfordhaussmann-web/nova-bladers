local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local inArena = {}

local function getRemotes()
	return ReplicatedStorage:WaitForChild("NovaBladers").Remotes
end

local function setPlayerState(player, inHub, inArenaState)
	player:SetAttribute(HubConfig.PLAYER_ATTR_IN_HUB, inHub)
	player:SetAttribute(HubConfig.PLAYER_ATTR_IN_ARENA, inArenaState)
	inArena[player] = inArenaState
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function createPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = parent
	return prompt
end

local function createSign(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function createStation(hub, name, offset, size, color, material)
	local origin = HubConfig.HUB_ORIGIN
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = origin + offset
	part.Anchored = true
	part.Material = material
	part.Color = color
	part.Parent = hub
	return part
end

function HubWorldManager.buildHubWorld()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local origin = HubConfig.HUB_ORIGIN
	local floorSize = HubConfig.HUB_PLATFORM_SIZE

	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Size = floorSize
	floor.Position = origin + Vector3.new(0, -floorSize.Y / 2, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(42, 48, 62)
	floor.Parent = hub

	local ring = Instance.new("Part")
	ring.Name = "CenterRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1.5, 28, 28)
	ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(70, 120, 255)
	ring.Transparency = 0.35
	ring.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.HUB_SPAWN + Vector3.new(0, -3, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local terminal = createStation(
		hub,
		"LobbyTerminal",
		HubConfig.TERMINAL_OFFSET,
		Vector3.new(10, 8, 6),
		Color3.fromRGB(55, 65, 90),
		Enum.Material.Metal
	)
	createSign(terminal, "Lobby Terminal", Color3.fromRGB(180, 210, 255))
	createPrompt(terminal, "Stats öffnen", "Lobby Terminal").Name = "LobbyPrompt"

	local portal = createStation(
		hub,
		"ArenaPortal",
		HubConfig.PORTAL_OFFSET,
		Vector3.new(10, 10, 3),
		Color3.fromRGB(80, 140, 255),
		Enum.Material.Neon
	)
	createSign(portal, "Arena Gate", Color3.fromRGB(120, 200, 255))
	createPrompt(portal, "Betreten", "Arena Gate").Name = "ArenaPrompt"

	local beyStation = createStation(
		hub,
		"BeyStation",
		HubConfig.BEY_STATION_OFFSET,
		Vector3.new(12, 6, 8),
		Color3.fromRGB(90, 70, 140),
		Enum.Material.SmoothPlastic
	)
	createSign(beyStation, "Bey Bay", Color3.fromRGB(200, 170, 255))
	createPrompt(beyStation, "Auswählen", "Bey Bay").Name = "BeyPrompt"

	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local radius = 38
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar" .. i
		pillar.Size = Vector3.new(3, 14, 3)
		pillar.Position = origin + Vector3.new(math.cos(angle) * radius, 7, math.sin(angle) * radius)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Concrete
		pillar.Color = Color3.fromRGB(60, 66, 78)
		pillar.Parent = hub

		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 18
		light.Color = Color3.fromRGB(100, 160, 255)
		light.Parent = pillar
	end

	return hub
end

function HubWorldManager.bindPrompts(hub)
	local remotes = getRemotes()

	local terminal = hub:FindFirstChild("LobbyTerminal")
	if terminal then
		local prompt = terminal:FindFirstChild("LobbyPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				HubWorldManager.fireLobbyReady(player, true)
			end)
		end
	end

	local portal = hub:FindFirstChild("ArenaPortal")
	if portal then
		local prompt = portal:FindFirstChild("ArenaPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				HubWorldManager.enterArena(player)
			end)
		end
	end

	local beyStation = hub:FindFirstChild("BeyStation")
	if beyStation then
		local prompt = beyStation:FindFirstChild("BeyPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				remotes.OpenBeySelect:FireClient(player)
			end)
		end
	end
end

function HubWorldManager.getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.Position + Vector3.new(0, 3, 0)
		end
	end
	return HubConfig.ARENA_SPAWN
end

function HubWorldManager.getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.fireLobbyReady(player, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local remotes = getRemotes()

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = HubWorldManager.getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		showPanel = showPanel == true,
	})
end

function HubWorldManager.sendToHub(player)
	setPlayerState(player, true, false)
	teleportCharacter(player, HubConfig.HUB_SPAWN)
end

function HubWorldManager.sendToArena(player)
	local position = HubWorldManager.getArenaSpawn()
	setPlayerState(player, false, true)
	teleportCharacter(player, position)
end

function HubWorldManager.enterArena(player)
	if inArena[player] then
		return
	end
	HubWorldManager.sendToArena(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.sendToHub(player)
	HubWorldManager.fireLobbyReady(player, false)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				HubWorldManager.sendToArena(player)
			else
				HubWorldManager.sendToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.sendToHub(player)
	end

	HubWorldManager.fireLobbyReady(player, false)
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	inArena[player] = nil
end

function HubWorldManager.init()
	local hub = HubWorldManager.buildHubWorld()
	HubWorldManager.bindPrompts(hub)

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
end

return HubWorldManager
