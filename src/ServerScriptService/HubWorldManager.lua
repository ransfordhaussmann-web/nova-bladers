local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local arenaPlayers = {}
local enterArenaCallbacks = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
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
		leaderboard = LeaderboardManager.getTop(5),
		hubMode = true,
	}
end

local function getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.HUB_SPAWN_POSITION + Vector3.new(0, 5, 0)
	end

	local spawn = arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 3, 0)
	end

	local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChild("Floor")
	if bowl and bowl:IsA("BasePart") then
		return bowl.Position + Vector3.new(0, bowl.Size.Y * 0.5 + 4, 0)
	end

	return arena:GetPivot().Position + Vector3.new(0, 5, 0)
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

local function createZonePart(zoneId, zoneConfig)
	local part = Instance.new("Part")
	part.Name = zoneId
	part.Anchored = true
	part.CanCollide = true
	part.Size = zoneConfig.size
	part.Position = zoneConfig.position
	part.Color = zoneConfig.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	part.Parent = hubFolder

	local label = Instance.new("BillboardGui")
	label.Name = "ZoneLabel"
	label.Size = UDim2.fromOffset(200, 50)
	label.StudsOffset = Vector3.new(0, zoneConfig.size.Y * 0.5 + 2, 0)
	label.AlwaysOnTop = true
	label.Parent = part

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Text = zoneConfig.displayName
	text.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zoneConfig.promptText
	prompt.ObjectText = zoneConfig.displayName
	prompt.KeyboardKeyCode = zoneConfig.promptKey
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(triggerPlayer)
		HubWorldManager.handleZoneAction(triggerPlayer, zoneId)
	end)

	return part
end

function HubWorldManager.buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	hubFolder = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hubFolder then
		hubFolder = Instance.new("Folder")
		hubFolder.Name = HubConfig.HUB_FOLDER_NAME
		hubFolder.Parent = workspace
	end

	if not hubFolder:FindFirstChild("Floor") then
		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Anchored = true
		floor.Size = HubConfig.HUB_FLOOR_SIZE
		floor.Position = Vector3.new(0, 0, 0)
		floor.Color = HubConfig.HUB_FLOOR_COLOR
		floor.Material = Enum.Material.Slate
		floor.Parent = hubFolder
	end

	if not hubFolder:FindFirstChild("HubSpawn") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "HubSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = HubConfig.HUB_SPAWN_POSITION
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Parent = hubFolder
	end

	for zoneId, zoneConfig in HubConfig.ZONES do
		if not hubFolder:FindFirstChild(zoneId) then
			createZonePart(zoneId, zoneConfig)
		end
	end

	return hubFolder
end

function HubWorldManager.isInArena(player)
	return arenaPlayers[player] == true
end

function HubWorldManager.sendLobbyReady(player)
	if remotes then
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	end
end

function HubWorldManager.returnToHub(player)
	arenaPlayers[player] = nil
	teleportCharacter(player, HubConfig.HUB_SPAWN_POSITION)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.sendToArena(player)
	arenaPlayers[player] = true
	teleportCharacter(player, getArenaSpawn())
end

function HubWorldManager.onEnterArena(callback)
	table.insert(enterArenaCallbacks, callback)
end

function HubWorldManager.requestEnterArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end

	HubWorldManager.sendToArena(player)
	for _, callback in enterArenaCallbacks do
		callback(player)
	end
	remotes.EnterArena:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if HubWorldManager.isInArena(player) then
		return
	end

	if zoneId == "ArenaGate" then
		HubWorldManager.requestEnterArena(player)
	elseif zoneId == "BeyShop" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "StatsBoard" then
		remotes.HubZoneAction:FireClient(player, "ShowStats", buildLobbyPayload(player))
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	arenaPlayers[player] = nil

	local function onCharacter()
		if not HubWorldManager.isInArena(player) then
			teleportCharacter(player, HubConfig.HUB_SPAWN_POSITION)
		end
		task.defer(function()
			HubWorldManager.sendLobbyReady(player)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	arenaPlayers[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.requestEnterArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
