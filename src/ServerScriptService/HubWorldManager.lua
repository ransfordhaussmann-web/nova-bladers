local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}
local hubFolder

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function getPlayerRank(player)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 1
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherPoints = PlayerDataManager.getRankPoints(PlayerDataManager.get(other))
			if otherPoints > points then
				rank += 1
			end
		end
	end
	return rank
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function createPart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function createZoneMarker(zoneDef, parent)
	local folder = Instance.new("Folder")
	folder.Name = zoneDef.id
	folder.Parent = parent

	local baseY = zoneDef.position.Y + (zoneDef.size.Y / 2)
	local part = createPart(
		"Marker",
		zoneDef.size,
		zoneDef.position + Vector3.new(0, baseY, 0),
		zoneDef.color,
		folder
	)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.promptAction
	prompt.ObjectText = zoneDef.label
	prompt.KeyboardKeyCode = zoneDef.promptKey
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zoneDef.size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zoneDef.label
	label.Parent = billboard

	return folder, prompt
end

local function buildHubWorld()
	if workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME) then
		return workspace[HubConfig.HUB_FOLDER_NAME]
	end

	local folder = Instance.new("Folder")
	folder.Name = HubConfig.HUB_FOLDER_NAME
	folder.Parent = workspace

	local floor = createPart(
		"Floor",
		Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.FLOOR_HEIGHT, HubConfig.FLOOR_SIZE.Y),
		Vector3.new(0, -HubConfig.FLOOR_HEIGHT / 2, 0),
		Color3.fromRGB(45, 50, 65),
		folder
	)
	floor.Material = Enum.Material.Slate

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 1, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	for _, zoneDef in HubConfig.ZONES do
		createZoneMarker(zoneDef, folder)
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 2
	lighting.Range = 40
	lighting.Parent = floor

	return folder
end

local function getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.Position + Vector3.new(0, 3, 0)
		end
	end
	return HubConfig.SPAWN_POSITION + Vector3.new(0, 0, -50)
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function fireHubState(player, inHub)
	remotes.HubState:FireClient(player, {
		inHub = inHub,
		modeLabel = getModeLabel(),
	})
end

function HubWorldManager.pushLobbyState(player)
	local payload = buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	remotes.HubState:FireClient(player, {
		inHub = not inArena[player],
		stats = {
			wins = payload.wins,
			losses = payload.losses,
			rank = payload.rank,
		},
		modeLabel = payload.modeLabel,
		leaderboard = payload.leaderboard,
	})
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	teleportPlayer(player, getArenaSpawn())
	fireHubState(player, false)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = false
	teleportPlayer(player, HubConfig.SPAWN_POSITION)
	HubWorldManager.pushLobbyState(player)
end

local function onZoneTriggered(player, zoneId)
	if inArena[player] then
		return
	end

	if zoneId == "ArenaGate" then
		HubWorldManager.sendToArena(player)
	elseif zoneId == "BeyShop" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "StatsBoard" then
		HubWorldManager.pushLobbyState(player)
		remotes.RefreshHubStats:FireClient(player, buildLobbyPayload(player))
	end
end

local function wireZonePrompts()
	for zoneId, zoneDef in HubConfig.ZONES do
		local zoneFolder = hubFolder:FindFirstChild(zoneId)
		if zoneFolder then
			local prompt = zoneFolder:FindFirstChild("ZonePrompt", true)
			if prompt then
				prompt.Triggered:Connect(function(player)
					onZoneTriggered(player, zoneDef.id)
				end)
			end
		end
	end
end

local function wireRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not inArena[player] then
			HubWorldManager.sendToArena(player)
		end
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		if not inArena[player] then
			HubWorldManager.pushLobbyState(player)
		end
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	inArena[player] = false

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				teleportPlayer(player, getArenaSpawn())
				fireHubState(player, false)
			else
				teleportPlayer(player, HubConfig.SPAWN_POSITION)
				HubWorldManager.pushLobbyState(player)
			end
		end)
	end)

	if player.Character then
		teleportPlayer(player, HubConfig.SPAWN_POSITION)
	end
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = buildHubWorld()
	wireZonePrompts()
	wireRemotes()

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
