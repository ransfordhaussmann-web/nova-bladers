local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}
local statsBoardGui

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildZonePart(parent, zoneId, zone)
	local part = Instance.new("Part")
	part.Name = zoneId
	part.Anchored = true
	part.CanCollide = true
	part.Size = zone.size
	part.Position = zone.position + Vector3.new(0, zone.size.Y * 0.5, 0)
	part.Color = zone.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	part.Parent = parent

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(200, 60)
	label.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	label.AlwaysOnTop = true
	label.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = zone.label
	title.Parent = label

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(220, 220, 220)
	hint.TextScaled = true
	hint.Text = zone.hint
	hint.Parent = label

	if zone.promptAction then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = zone.promptText
		prompt.ObjectText = zone.label
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.Parent = part

		prompt.Triggered:Connect(function(player)
			HubWorldManager.handleZoneAction(player, zone.promptAction)
		end)
	end

	return part
end

local function updateStatsBoard(payload)
	if not statsBoardGui then
		return
	end
	local lines = {
		string.format("Wins: %d  |  Losses: %d", payload.wins, payload.losses),
		string.format("Rang: %d", payload.rank),
		"",
		"Top Spieler:",
	}
	for _, entry in payload.leaderboard do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	statsBoardGui.TextLabel.Text = table.concat(lines, "\n")
end

local function buildStatsSurface(statsPart)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "StatsSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = statsPart

	local label = Instance.new("TextLabel")
	label.Name = "TextLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = false
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "Lade Stats..."
	label.Parent = surface

	statsBoardGui = label
end

function HubWorldManager.buildHub()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		local statsPart = existing:FindFirstChild("StatsBoard")
		if statsPart and not statsPart:FindFirstChild("StatsSurface") then
			buildStatsSurface(statsPart)
		elseif statsPart then
			statsBoardGui = statsPart.StatsSurface.TextLabel
		end
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0)
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local part = buildZonePart(hub, zoneId, zone)
		if zoneId == "StatsBoard" then
			buildStatsSurface(part)
		end
	end

	return hub
end

function HubWorldManager.getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.SPAWN_POSITION + Vector3.new(0, 2, 0)
	end
	local spawn = arena:FindFirstChild("Spawn", true)
		or arena:FindFirstChild("ArenaSpawn", true)
		or arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return arena:GetPivot().Position + Vector3.new(0, 5, 0)
end

function HubWorldManager.getHubSpawn()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.Position + Vector3.new(0, 3, 0)
		end
	end
	return HubConfig.SPAWN_POSITION
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.pushLobbyState(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
	}
	remotes.LobbyReady:FireClient(player, payload)
	remotes.HubState:FireClient(player, {
		inHub = payload.inHub,
		modeLabel = payload.modeLabel,
	})
	updateStatsBoard(payload)
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(HubWorldManager.getArenaSpawn())
		end
	end
	remotes.HubState:FireClient(player, { inHub = false, modeLabel = getModeLabel() })
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(HubWorldManager.getHubSpawn())
		end
	end
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.handleZoneAction(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end
	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "RefreshStats" then
		HubWorldManager.pushLobbyState(player)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				HubWorldManager.sendToArena(player)
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	else
		HubWorldManager.pushLobbyState(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildHub()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInArena(player) then
			return
		end
		HubWorldManager.sendToArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(HubWorldManager.onPlayerAdded, player)
	end
end

return HubWorldManager
