local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local playersInArena = {}
local hubFolder = nil
local remotes = nil

local function getRemotes()
	if remotes then
		return remotes
	end
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	local folder = nova:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = nova
	end
	local names = { "LobbyReady", "EnterArena", "OpenBeySelect", "ReturnToHub", "HubZoneHint" }
	for _, name in names do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	remotes = folder
	return folder
end

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		if arena.PrimaryPart then
			return arena.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
		end
	end
	return CFrame.new(0, 8, 0)
end

local function getHubSpawnCFrame()
	if hubFolder then
		local spawn = hubFolder:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
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

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildZoneLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

local function buildZone(zoneConfig)
	local part = Instance.new("Part")
	part.Name = zoneConfig.id
	part.Size = zoneConfig.size
	part.Position = zoneConfig.position
	part.Anchored = true
	part.CanCollide = true
	part.Color = zoneConfig.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25
	part.Parent = hubFolder

	buildZoneLabel(part, zoneConfig.label)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.label
	prompt.ObjectText = "Nova Hub"
	prompt.MaxActivationDistance = HubConfig.PROMPT_DISTANCE
	prompt.HoldDuration = HubConfig.PROMPT_HOLD
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	return part, prompt
end

local function buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = Vector3.new(0, 0, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("Part")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Parent = hubFolder

	for _, zoneConfig in pairs(HubConfig.ZONES) do
		buildZone(zoneConfig)
	end

	return hubFolder
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local playerCount = #Players:GetPlayers()
	getRemotes().LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		hubMode = true,
	})
end

local function handleZoneAction(player, action)
	if playersInArena[player] then
		return
	end

	if action == "enterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "openBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		sendLobbyReady(player)
		getRemotes().HubZoneHint:FireClient(player, {
			zone = "HallOfFame",
			hint = "Top-Spieler — siehe Stats-HUD",
			showLeaderboard = true,
		})
	end
end

local function wireZonePrompts()
	for _, zoneConfig in pairs(HubConfig.ZONES) do
		local part = hubFolder:FindFirstChild(zoneConfig.id)
		if part then
			local prompt = part:FindFirstChild("ZonePrompt")
			if prompt then
				prompt.Triggered:Connect(function(triggerPlayer)
					handleZoneAction(triggerPlayer, zoneConfig.action)
				end)
			end
		end
	end
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.sendToArena(player)
	if playersInArena[player] then
		return
	end
	playersInArena[player] = true
	teleportPlayer(player, getArenaSpawnCFrame())
	getRemotes().EnterArena:FireClient(player)
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	teleportPlayer(player, getHubSpawnCFrame())
	getRemotes().ReturnToHub:FireClient(player)
	sendLobbyReady(player)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not playersInArena[player] then
				teleportPlayer(player, getHubSpawnCFrame())
			end
		end)
	end)

	if player.Character then
		teleportPlayer(player, getHubSpawnCFrame())
	end

	sendLobbyReady(player)
end

function HubWorldManager.init()
	getRemotes()
	buildHubWorld()
	wireZonePrompts()

	local remoteFolder = getRemotes()
	remoteFolder.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
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
