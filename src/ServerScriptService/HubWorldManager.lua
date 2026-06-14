local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local playerState: { [Player]: string } = {}
local hubBuilt = false
local statsBoardGui: SurfaceGui? = nil

local function getModeLabel(): string
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	for key, value in props do
		if key ~= "CanCollide" then
			part[key] = value
		end
	end
	return part
end

local function addBillboard(parent: Instance, title: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 48)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = title
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function addProximityPrompt(parent: Instance, zoneConfig)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zoneConfig.promptText
	prompt.ObjectText = zoneConfig.name
	prompt.KeyboardKeyCode = zoneConfig.promptKey
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function formatStatsText(payload): string
	local lines = {
		string.format("Wins: %d  |  Losses: %d  |  Rang: %d", payload.wins, payload.losses, payload.rank),
		payload.modeLabel or "Modus: Training",
		"",
		"🏆 Top Spieler:",
	}
	for _, entry in payload.leaderboard do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateStatsBoard(payload)
	if not statsBoardGui then
		return
	end
	local label = statsBoardGui:FindFirstChild("StatsLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = formatStatsText(payload)
	end
end

function HubWorldManager.buildHubWorld()
	if hubBuilt then
		return Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	end

	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubBuilt = true
		local statsBoard = existing:FindFirstChild("StatsBoard", true)
		if statsBoard then
			statsBoardGui = statsBoard:FindFirstChild("BoardGui")
		end
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.HUB_SIZE,
		Position = HubConfig.HUB_CENTER,
		Color = Color3.fromRGB(45, 50, 65),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local spawn = makePart({
		Name = "Spawn",
		Size = Vector3.new(6, 1, 6),
		Position = HubConfig.HUB_CENTER + HubConfig.SPAWN_OFFSET,
		Color = Color3.fromRGB(90, 200, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.4,
	})
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	local zoneTitles = {
		ArenaGate = "Arena",
		BeyShop = "Bey Shop",
		StatsBoard = "Ruhmeshalle",
	}

	for zoneKey, zoneConfig in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zoneConfig.name,
			Size = zoneConfig.size,
			Position = zoneConfig.position,
			Color = zoneConfig.color,
			Material = Enum.Material.SmoothPlastic,
		})
		zonePart:SetAttribute("ZoneId", zoneKey)
		addBillboard(zonePart, zoneTitles[zoneKey] or zoneConfig.name, zoneConfig.color)
		addProximityPrompt(zonePart, zoneConfig)
		zonePart.Parent = zones

		if zoneKey == "StatsBoard" then
			local boardGui = Instance.new("SurfaceGui")
			boardGui.Name = "BoardGui"
			boardGui.Face = Enum.NormalId.Front
			boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			boardGui.PixelsPerStud = 40
			boardGui.Parent = zonePart

			local statsLabel = Instance.new("TextLabel")
			statsLabel.Name = "StatsLabel"
			statsLabel.Size = UDim2.fromScale(1, 1)
			statsLabel.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
			statsLabel.BackgroundTransparency = 0.15
			statsLabel.TextColor3 = Color3.new(1, 1, 1)
			statsLabel.Font = Enum.Font.GothamMedium
			statsLabel.TextSize = 22
			statsLabel.TextXAlignment = Enum.TextXAlignment.Left
			statsLabel.TextYAlignment = Enum.TextYAlignment.Top
			statsLabel.TextWrapped = true
			statsLabel.Text = "Statistiken werden geladen…"
			statsLabel.Parent = boardGui

			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 12)
			padding.PaddingLeft = UDim.new(0, 12)
			padding.PaddingRight = UDim.new(0, 12)
			padding.Parent = statsLabel

			statsBoardGui = boardGui
		end
	end

	hubBuilt = true
	return hub
end

function HubWorldManager.isInArena(player: Player): boolean
	return playerState[player] == "arena"
end

function HubWorldManager.getHubSpawnCFrame(): CFrame
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	local spawn = hub and hub:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_CENTER + HubConfig.SPAWN_OFFSET)
end

function HubWorldManager.getArenaSpawnCFrame(): CFrame
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 2, 0)
		end
		if arena:IsA("BasePart") then
			return arena.CFrame + HubConfig.ARENA_SPAWN_OFFSET
		end
		local bowl = arena:FindFirstChildWhichIsA("BasePart", true)
		if bowl then
			return bowl.CFrame + HubConfig.ARENA_SPAWN_OFFSET
		end
	end
	return CFrame.new(0, 5, 50)
end

local function teleportPlayer(player: Player, target: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = target
	end
end

function HubWorldManager.pushLobbyState(player: Player)
	local data = PlayerDataManager.get(player)
	local rank = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}

	updateStatsBoard(payload)
	Remotes.LobbyReady:FireClient(player, payload)
	Remotes.RefreshHubStats:FireClient(player, payload)
end

function HubWorldManager.sendToArena(player: Player)
	playerState[player] = "arena"
	teleportPlayer(player, HubWorldManager.getArenaSpawnCFrame())
	Remotes.HubState:FireClient(player, "arena")
end

function HubWorldManager.returnToHub(player: Player)
	playerState[player] = "hub"
	teleportPlayer(player, HubWorldManager.getHubSpawnCFrame())
	HubWorldManager.pushLobbyState(player)
	Remotes.HubState:FireClient(player, "hub")
end

function HubWorldManager.onPlayerAdded(player: Player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playerState[player] == "arena" then
				teleportPlayer(player, HubWorldManager.getArenaSpawnCFrame())
				Remotes.HubState:FireClient(player, "arena")
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	HubWorldManager.returnToHub(player)
end

function HubWorldManager.onPlayerRemoving(player: Player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

local function onEnterArena(player: Player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end

local function onOpenBeySelect(player: Player)
	if HubWorldManager.isInArena(player) then
		return
	end
	Remotes.OpenBeySelect:FireClient(player)
end

local function onRefreshHubStats(player: Player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.init()
	HubWorldManager.buildHubWorld()

	Remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	Remotes.OpenBeySelect.OnServerEvent:Connect(onOpenBeySelect)
	Remotes.RefreshHubStats.OnServerEvent:Connect(onRefreshHubStats)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function()
		for _, player in Players:GetPlayers() do
			if playerState[player] == "hub" then
				HubWorldManager.pushLobbyState(player)
			end
		end
	end)
end

return HubWorldManager
