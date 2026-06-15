local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name
	part.Parent = props.Parent
	return part
end

local function createZone(parent, zoneKey, offset)
	local color = HubConfig.ZONE_COLORS[zoneKey]
	local label = HubConfig.ZONE_LABELS[zoneKey]
	local action = HubConfig.ZONE_ACTIONS[zoneKey]

	local zone = Instance.new("Model")
	zone.Name = zoneKey .. "Zone"
	zone.Parent = parent

	local pad = createPart({
		Name = "Pad",
		Parent = zone,
		Size = HubConfig.ZONE_SIZE,
		Position = offset + Vector3.new(0, HubConfig.ZONE_SIZE.Y / 2, 0),
		Color = color,
		Material = Enum.Material.Neon,
	})
	pad.Transparency = 0.35

	local ring = createPart({
		Name = "Ring",
		Parent = zone,
		Size = Vector3.new(HubConfig.ZONE_SIZE.X + 2, 0.2, HubConfig.ZONE_SIZE.Z + 2),
		Position = offset + Vector3.new(0, 0.15, 0),
		Color = color,
		Material = Enum.Material.Metal,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = ring

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.TextSize = 20
	text.Text = label
	text.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = label
	prompt.ObjectText = "Nova Hub"
	prompt.MaxActivationDistance = HubConfig.PROMPT_DISTANCE
	prompt.HoldDuration = HubConfig.PROMPT_HOLD
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", action)
	prompt.Parent = pad

	zone.PrimaryPart = pad
	return zone
end

function HubWorldManager.buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	hubFolder = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hubFolder then
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	createPart({
		Name = "Floor",
		Parent = hubFolder,
		Size = HubConfig.FLOOR_SIZE,
		Position = HubConfig.FLOOR_POSITION + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
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
	spawn.Parent = hubFolder

	createZone(hubFolder, "Arena", HubConfig.ARENA_ENTRY_OFFSET)
	createZone(hubFolder, "BeySelect", HubConfig.BEY_SELECT_OFFSET)
	createZone(hubFolder, "Leaderboard", HubConfig.LEADERBOARD_OFFSET)

	return hubFolder
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	local position = spawn and spawn.Position or HubConfig.SPAWN_POSITION
	root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	inArena[player] = nil
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	if remotes then
		remotes.EnterArena:FireClient(player)
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	if remotes then
		remotes.ReturnToHub:FireClient(player)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not HubWorldManager.isInArena(player) then
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	else
		HubWorldManager.sendLobbyReady(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInArena(player) then return end
		HubWorldManager.sendToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
