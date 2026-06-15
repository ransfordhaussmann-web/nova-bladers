local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldManager = {}

local remotes
local playerDataManager
local leaderboardManager
local inArena = {}
local hubFolder

local function getRemotes()
	local root = ReplicatedStorage:WaitForChild("NovaBladers")
	local folder = root:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root
	end

	local function ensure(name, className)
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	end

	return {
		EnterArena = ensure("EnterArena", "RemoteEvent"),
		LobbyReady = ensure("LobbyReady", "RemoteEvent"),
		OpenBeySelect = ensure("OpenBeySelect", "RemoteEvent"),
		HubState = ensure("HubState", "RemoteEvent"),
		RefreshHubStats = ensure("RefreshHubStats", "RemoteEvent"),
	}
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size or Vector3.new(4, 4, 4)
	part.Position = props.position or Vector3.new()
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function attachPrompt(part, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function buildZone(parent, zoneId, zone)
	local marker = makePart({
		name = zoneId,
		parent = parent,
		position = zone.position + Vector3.new(0, zone.size.Y * 0.5, 0),
		size = zone.size,
		color = zone.color,
		material = Enum.Material.Neon,
	})
	marker.Transparency = 0.25

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(180, 48)
	label.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	label.AlwaysOnTop = true
	label.Parent = marker

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = zone.objectText
	text.Parent = label

	local prompt = attachPrompt(marker, zone)
	prompt:SetAttribute("HubAction", zone.action)
	return marker, prompt
end

local function buildHubWorld()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		position = HubConfig.SPAWN_POSITION - Vector3.new(0, HubConfig.FLOOR_SIZE.Y * 0.5 + 3, 0),
		size = HubConfig.FLOOR_SIZE,
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		buildZone(zonesFolder, zoneId, zone)
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 60
	light.Parent = floor

	return hub
end

local function getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.SPAWN_POSITION + HubConfig.ARENA_SPAWN_OFFSET
	end
	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + HubConfig.ARENA_SPAWN_OFFSET
	end
	return arena:GetPivot().Position + HubConfig.ARENA_SPAWN_OFFSET
end

local function getHubSpawn()
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + HubConfig.HUB_CAMERA_OFFSET
	end
	return HubConfig.SPAWN_POSITION + HubConfig.HUB_CAMERA_OFFSET
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	local modeLabel = "Modus: Training"
	if playerCount >= 3 then
		modeLabel = "Modus: FFA"
	elseif playerCount == 2 then
		modeLabel = "Modus: 1v1 PvP"
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = leaderboardManager.getTop(5),
		inHub = not inArena[player],
	}
end

function HubWorldManager.pushLobbyState(player)
	local payload = buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	remotes.HubState:FireClient(player, {
		location = inArena[player] and "arena" or "hub",
		stats = payload,
	})
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	teleportPlayer(player, getArenaSpawn())
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = false
	teleportPlayer(player, getHubSpawn())
	HubWorldManager.pushLobbyState(player)
end

local function onZonePrompt(prompt, player)
	local action = prompt:GetAttribute("HubAction")
	if not action or inArena[player] then return end

	if action == "enterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		remotes.RefreshHubStats:FireClient(player, buildLobbyPayload(player))
	end
end

local function connectZonePrompts()
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, marker in zones:GetChildren() do
		local prompt = marker:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZonePrompt(prompt, player)
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				teleportPlayer(player, getArenaSpawn())
			else
				teleportPlayer(player, getHubSpawn())
			end
			HubWorldManager.pushLobbyState(player)
		end)
	end)
end

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager
	remotes = getRemotes()
	hubFolder = buildHubWorld()
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)
end

return HubWorldManager
