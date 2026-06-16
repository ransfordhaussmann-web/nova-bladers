local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playersInArena = {}

local function getRemotes()
	if remotes then return remotes end
	local folder = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	remotes = {
		LobbyReady = folder:WaitForChild("LobbyReady"),
		EnterArena = folder:WaitForChild("EnterArena"),
		OpenBeySelect = folder:WaitForChild("OpenBeySelect"),
		ReturnToHub = folder:WaitForChild("ReturnToHub"),
		ShowLeaderboard = folder:WaitForChild("ShowLeaderboard"),
	}
	return remotes
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildZonePart(zoneId, zoneDef)
	local part = Instance.new("Part")
	part.Name = zoneId
	part.Anchored = true
	part.CanCollide = true
	part.Size = zoneDef.size
	part.Position = zoneDef.position
	part.Color = zoneDef.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zoneDef.promptText
	prompt.ObjectText = zoneDef.name
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt:SetAttribute("Action", zoneDef.promptAction)
	prompt.Parent = part

	local label = Instance.new("BillboardGui")
	label.Name = "ZoneLabel"
	label.Size = UDim2.fromOffset(200, 50)
	label.StudsOffset = Vector3.new(0, zoneDef.size.Y / 2 + 2, 0)
	label.AlwaysOnTop = true
	label.Parent = part

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.TextSize = 18
	text.Text = zoneDef.name
	text.Parent = label

	return part
end

function HubWorldManager.buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 2, 0)
	floor.Color = Color3.fromRGB(35, 40, 55)
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Color = Color3.fromRGB(60, 180, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Neutral = true
	spawn.Parent = hubFolder

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubFolder

	for zoneId, zoneDef in HubConfig.ZONES do
		buildZonePart(zoneId, zoneDef).Parent = zonesFolder
	end

	return hubFolder
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
end

local function getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then return HubConfig.SPAWN_POSITION end
	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return HubConfig.SPAWN_POSITION
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(getArenaSpawn())
end

local function sendLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()

	getRemotes().LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		use3DHub = HubConfig.USE_3D_HUB,
	})
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true
	teleportToArena(player)
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	teleportToHub(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	getRemotes().ReturnToHub:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		use3DHub = HubConfig.USE_3D_HUB,
	})
	sendLobbyPayload(player)
end

local function onPromptTriggered(player, action)
	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
		getRemotes().EnterArena:FireClient(player)
	elseif action == "OpenBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif action == "ShowLeaderboard" then
		getRemotes().ShowLeaderboard:FireClient(player, {
			leaderboard = LeaderboardManager.getTop(5),
		})
	end
end

local function wireZonePrompts()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, part in zones:GetChildren() do
		local prompt = part:FindFirstChild("HubPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onPromptTriggered(player, prompt:GetAttribute("Action"))
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		if HubWorldManager.isInArena(player) then
			teleportToArena(player)
		else
			teleportToHub(player)
		end
	end)

	sendLobbyPayload(player)
end

function HubWorldManager.init()
	getRemotes()
	HubWorldManager.buildHubWorld()
	wireZonePrompts()

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	getRemotes().ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		playersInArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
