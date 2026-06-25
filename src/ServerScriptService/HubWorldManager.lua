local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"ReturnToHub",
	"ShowLeaderboard",
}

local HubWorldManager = {}
local remotes = {}
local playersInArena = {}
local initialized = false

local function getRemotesFolder()
	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = ReplicatedStorage
	end
	local folder = root:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root
	end
	return folder
end

local function ensureRemotes()
	local folder = getRemotesFolder()
	for _, name in REMOTE_NAMES do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		remotes[name] = remote
	end
	return remotes
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_DISPLAY_COUNT),
	}
end

local function sendLobbyReady(player)
	if remotes.LobbyReady then
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	end
end

local function getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn then
			return spawn.CFrame + Vector3.new(0, 2, 0)
		end
		local floor = arena:FindFirstChild("Floor") or arena:FindFirstChildWhichIsA("BasePart")
		if floor and floor:IsA("BasePart") then
			return floor.CFrame * CFrame.new(0, HubConfig.ARENA_SPAWN_OFFSET.Y, 0)
		end
	end
	return CFrame.new(0, 10, 40)
end

local function getHubSpawn()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn then
			return spawn.CFrame + Vector3.new(0, 2, 0)
		end
	end
	return CFrame.new(HubConfig.HUB_SPAWN)
end

local function teleportPlayer(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function createZoneMarker(parent, zone)
	local marker = Instance.new("Part")
	marker.Name = zone.id .. "Zone"
	marker.Size = Vector3.new(10, 0.5, 10)
	marker.Anchored = true
	marker.CanCollide = true
	marker.Material = Enum.Material.Neon
	marker.Color = zone.color
	marker.CFrame = CFrame.new(zone.offset) * CFrame.new(0, marker.Size.Y * 0.5, 0)
	marker.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.name
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Parent = marker

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	prompt.Triggered:Connect(function(triggerPlayer)
		if playersInArena[triggerPlayer] then
			return
		end
		if zone.action == "EnterArena" then
			HubWorldManager.sendToArena(triggerPlayer)
		elseif zone.action == "OpenBeySelect" then
			if remotes.OpenBeySelect then
				remotes.OpenBeySelect:FireClient(triggerPlayer)
			end
		elseif zone.action == "ShowLeaderboard" then
			if remotes.ShowLeaderboard then
				remotes.ShowLeaderboard:FireClient(triggerPlayer, buildLobbyPayload(triggerPlayer).leaderboard)
			end
		end
	end)

	return marker
end

function HubWorldManager.buildHubWorld()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(45, 48, 58)
	floor.CFrame = CFrame.new(0, 0, 0)
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = 10
	local wallT = 2

	local walls = {
		{ pos = Vector3.new(0, wallH * 0.5, -halfZ - wallT * 0.5), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ pos = Vector3.new(0, wallH * 0.5, halfZ + wallT * 0.5), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ pos = Vector3.new(-halfX - wallT * 0.5, wallH * 0.5, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ pos = Vector3.new(halfX + wallT * 0.5, wallH * 0.5, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for i, wall in walls do
		local part = Instance.new("Part")
		part.Name = "Wall" .. i
		part.Size = wall.size
		part.Anchored = true
		part.CanCollide = true
		part.Material = Enum.Material.Concrete
		part.Color = Color3.fromRGB(60, 65, 80)
		part.CFrame = CFrame.new(wall.pos)
		part.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(HubConfig.HUB_SPAWN)
	spawn.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZoneMarker(hub, zone)
	end

	local sign = Instance.new("Part")
	sign.Name = "WelcomeSign"
	sign.Size = Vector3.new(14, 6, 1)
	sign.Anchored = true
	sign.CanCollide = false
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(30, 32, 40)
	sign.CFrame = CFrame.new(0, 5, -28)
	sign.Parent = hub

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	signLabel.TextSize = 28
	signLabel.Text = "Nova Bladers Hub"
	signLabel.Parent = signGui

	return hub
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true
	player:SetAttribute("InArena", true)
	teleportPlayer(player, getArenaSpawn())
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	player:SetAttribute("InArena", false)
	teleportPlayer(player, getHubSpawn())
	sendLobbyReady(player)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				teleportPlayer(player, getArenaSpawn())
			else
				teleportPlayer(player, getHubSpawn())
				sendLobbyReady(player)
			end
		end)
	end)
	if player.Character then
		teleportPlayer(player, getHubSpawn())
		sendLobbyReady(player)
	end
end

function HubWorldManager.init()
	if initialized then
		return
	end
	initialized = true

	ensureRemotes()

	if HubConfig.USE_3D_HUB then
		HubWorldManager.buildHubWorld()
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInArena[player] then
			return
		end
		HubWorldManager.sendToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		playersInArena[player] = nil
		PlayerDataManager.save(player)
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
