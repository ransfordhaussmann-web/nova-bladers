local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local zonePrompts = {}
local playersInArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildSign(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

local function buildZone(name, config)
	local zone = Instance.new("Part")
	zone.Name = name
	zone.Size = config.size
	zone.Position = config.position
	zone.Anchored = true
	zone.CanCollide = true
	zone.Color = config.color
	zone.Material = Enum.Material.Neon
	zone.Transparency = 0.35
	zone.Parent = hubFolder

	buildSign(zone, config.label, config.size.Y * 0.6)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = config.promptText
	prompt.ObjectText = config.label
	prompt.KeyboardKeyCode = config.promptKey
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone

	zonePrompts[config.action] = prompt
	return zone
end

local function buildHubWorld()
	if workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME) then
		hubFolder = workspace[HubConfig.HUB_FOLDER_NAME]
		for _, child in hubFolder:GetChildren() do
			if child:IsA("BasePart") then
				local prompt = child:FindFirstChild("HubPrompt")
				if prompt then
					for zoneName, config in HubConfig.ZONES do
						if child.Name == zoneName then
							zonePrompts[config.action] = prompt
						end
					end
				end
			end
		end
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = Vector3.new(0, 0.5, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

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

	for name, config in HubConfig.ZONES do
		buildZone(name, config)
	end

	local title = Instance.new("Part")
	title.Name = "HubTitle"
	title.Size = Vector3.new(1, 1, 1)
	title.Position = Vector3.new(0, 10, -10)
	title.Anchored = true
	title.CanCollide = false
	title.Transparency = 1
	title.Parent = hubFolder
	buildSign(title, "Nova Bladers Hub", 0)

	return hubFolder
end

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + HubConfig.ARENA_SPAWN_OFFSET
		end
		local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChildWhichIsA("BasePart")
		if bowl then
			return bowl.CFrame * CFrame.new(HubConfig.ARENA_SPAWN_OFFSET)
		end
	end
	return CFrame.new(0, 5, 0)
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.pushLobbyState(player)
	if not remotes then return end

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	LeaderboardManager.submit(player, rankPoints)

	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		use3DHub = HubConfig.USE_3D_HUB,
		inHub = not HubWorldManager.isInArena(player),
	}

	remotes.LobbyReady:FireClient(player, payload)
	remotes.HubState:FireClient(player, payload)
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = getArenaSpawnCFrame()
		end
	end

	if remotes then
		remotes.HubState:FireClient(player, {
			inHub = false,
			use3DHub = HubConfig.USE_3D_HUB,
		})
	end
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
		end
	end

	HubWorldManager.pushLobbyState(player)
end

local function onZoneTriggered(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "arena" then
		HubWorldManager.sendToArena(player)
	elseif action == "beySelect" then
		if remotes then
			remotes.OpenBeySelect:FireClient(player)
		end
	elseif action == "stats" then
		HubWorldManager.pushLobbyState(player)
	end
end

local function connectZonePrompts()
	for action, prompt in zonePrompts do
		prompt.Triggered:Connect(function(player)
			onZoneTriggered(player, action)
		end)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				HubWorldManager.sendToArena(player)
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	task.defer(function()
		HubWorldManager.pushLobbyState(player)
	end)
end

function HubWorldManager.init()
	remotes = require(script.Parent.RemotesSetup)()

	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if root then
		root:SetAttribute("Use3DHub", HubConfig.USE_3D_HUB)
	end

	buildHubWorld()
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		HubWorldManager.pushLobbyState(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		playersInArena[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
