local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}
local hubFolder

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

local function createZone(zoneId, zoneConfig)
	local platform = Instance.new("Part")
	platform.Name = zoneId .. "Zone"
	platform.Size = zoneConfig.size
	platform.Position = zoneConfig.position
	platform.Anchored = true
	platform.CanCollide = true
	platform.Color = zoneConfig.color
	platform.Material = Enum.Material.Neon
	platform.Parent = hubFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.promptText
	prompt.ObjectText = zoneConfig.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = platform

	buildLabel(platform, zoneConfig.label)

	prompt.Triggered:Connect(function(player)
		HubWorldManager.handleZoneAction(player, zoneConfig.promptAction)
	end)

	return platform
end

function HubWorldManager.buildHubWorld()
	if hubFolder then
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Size = HubConfig.HUB_FLOOR_SIZE
	floor.Position = Vector3.new(0, 0.5, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = HubConfig.HUB_FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.HUB_SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hubFolder

	for zoneId, zoneConfig in HubConfig.ZONES do
		createZone(zoneId, zoneConfig)
	end

	local centerSign = Instance.new("Part")
	centerSign.Name = "HubSign"
	centerSign.Size = Vector3.new(8, 1, 4)
	centerSign.Position = Vector3.new(0, 1.5, 8)
	centerSign.Anchored = true
	centerSign.CanCollide = false
	centerSign.Color = Color3.fromRGB(50, 55, 75)
	centerSign.Material = Enum.Material.SmoothPlastic
	centerSign.Parent = hubFolder
	buildLabel(centerSign, "Nova Bladers Hub", Vector3.new(0, 3, 0))

	return hubFolder
end

function HubWorldManager.getArenaFolder()
	return Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
end

function HubWorldManager.getArenaSpawnCFrame()
	local arena = HubWorldManager.getArenaFolder()
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 6, -60)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		hubMode = HubConfig.USE_3D_HUB,
	})
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

	root.CFrame = HubConfig.HUB_SPAWN
	inArena[player] = nil

	if hubFolder then
		hubFolder.Parent = Workspace
	end

	local arena = HubWorldManager.getArenaFolder()
	if arena then
		arena.Parent = Workspace
	end

	HubWorldManager.sendLobbyPayload(player)
end

function HubWorldManager.sendToArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	inArena[player] = true
	root.CFrame = HubWorldManager.getArenaSpawnCFrame()

	if hubFolder then
		hubFolder.Parent = nil
	end

	remotes.EnterArena:FireClient(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowLeaderboard" then
		HubWorldManager.sendLobbyPayload(player)
		remotes.HubZoneHint:FireClient(player, {
			zone = "Leaderboard",
			message = "Rangliste aktualisiert",
		})
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				HubWorldManager.sendToArena(player)
			else
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder
	HubWorldManager.buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
