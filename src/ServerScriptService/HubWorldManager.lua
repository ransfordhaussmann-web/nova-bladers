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
local spawnPart
local playerLocation = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildBillboard(parent, title, subtitle, emoji)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 80)
	billboard.StudsOffset = Vector3.new(0, parent.Size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = string.format("%s %s", emoji or "", title)
	titleLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.Text = subtitle
	subLabel.Parent = billboard
end

local function buildStatsSurface(part)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "StatsDisplay"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Text = "🏆 Ruhmeshalle"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.LayoutOrder = 2
	stats.Size = UDim2.new(1, 0, 0, 72)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 16
	stats.TextColor3 = Color3.fromRGB(220, 230, 245)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Text = "Lade Stats..."
	stats.Parent = frame

	local board = Instance.new("TextLabel")
	board.Name = "LeaderboardLabel"
	board.LayoutOrder = 3
	board.Size = UDim2.new(1, 0, 0, 140)
	board.BackgroundTransparency = 1
	board.Font = Enum.Font.Gotham
	board.TextSize = 14
	board.TextColor3 = Color3.fromRGB(180, 200, 220)
	board.TextXAlignment = Enum.TextXAlignment.Left
	board.TextYAlignment = Enum.TextYAlignment.Top
	board.Text = ""
	board.Parent = frame
end

local function buildZone(zoneId, zoneConfig)
	local part = Instance.new("Part")
	part.Name = zoneId
	part.Anchored = true
	part.CanCollide = true
	part.Size = zoneConfig.size
	part.CFrame = CFrame.new(HubConfig.ORIGIN + zoneConfig.position)
	part.Color = zoneConfig.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25
	part:SetAttribute("HubZone", zoneId)
	part.Parent = hubFolder

	buildBillboard(part, zoneConfig.title, zoneConfig.subtitle, zoneConfig.emoji)

	if zoneId == "StatsBoard" then
		buildStatsSurface(part)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zoneConfig.prompt
	prompt.ObjectText = zoneConfig.title
	prompt.MaxActivationDistance = HubConfig.PROMPT.MaxActivationDistance
	prompt.HoldDuration = HubConfig.PROMPT.HoldDuration
	prompt.KeyboardKeyCode = HubConfig.PROMPT.KeyboardKeyCode
	prompt.GamepadKeyCode = HubConfig.PROMPT.GamepadKeyCode
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	return part
end

local function buildHubWorld()
	if hubFolder then
		return hubFolder
	end

	hubFolder = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hubFolder then
		spawnPart = hubFolder:FindFirstChild("Spawn")
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.ORIGIN + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0)
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	spawnPart = Instance.new("Part")
	spawnPart.Name = "Spawn"
	spawnPart.Anchored = true
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	spawnPart.Size = Vector3.new(6, 1, 6)
	spawnPart.CFrame = CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
	spawnPart.Parent = hubFolder

	for zoneId, zoneConfig in HubConfig.ZONES do
		buildZone(zoneId, zoneConfig)
	end

	local path = Instance.new("Part")
	path.Name = "CenterPath"
	path.Anchored = true
	path.Size = Vector3.new(8, 0.4, 80)
	path.Position = HubConfig.ORIGIN + Vector3.new(0, 0.2, -10)
	path.Color = Color3.fromRGB(60, 64, 78)
	path.Material = Enum.Material.Concrete
	path.Parent = hubFolder

	return hubFolder
end

local function getArenaSpawnCFrame()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + HubConfig.ARENA_SPAWN_OFFSET
		end
		if arena:IsA("BasePart") then
			return arena.CFrame + HubConfig.ARENA_SPAWN_OFFSET
		end
	end
	return CFrame.new(HubConfig.ORIGIN + Vector3.new(0, 10, -120))
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

function HubWorldManager.isInArena(player)
	return playerLocation[player] == "arena"
end

function HubWorldManager.sendToArena(player)
	playerLocation[player] = "arena"
	teleportCharacter(player, getArenaSpawnCFrame())
	remotes.HubState:FireClient(player, { inHub = false, inArena = true })
end

function HubWorldManager.returnToHub(player)
	playerLocation[player] = "hub"
	if spawnPart then
		teleportCharacter(player, spawnPart.CFrame + Vector3.new(0, 3, 0))
	end
	HubWorldManager.pushLobbyState(player)
	remotes.HubState:FireClient(player, { inHub = true, inArena = false })
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
	}
	remotes.LobbyReady:FireClient(player, payload)
	LeaderboardManager.submit(player, rankPoints)
	return payload
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	playerLocation[player] = "hub"

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playerLocation[player] == "hub" and spawnPart then
				teleportCharacter(player, spawnPart.CFrame + Vector3.new(0, 3, 0))
			elseif playerLocation[player] == "arena" then
				teleportCharacter(player, getArenaSpawnCFrame())
			end
		end)
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	else
		HubWorldManager.pushLobbyState(player)
		remotes.HubState:FireClient(player, { inHub = true, inArena = false })
	end
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerLocation[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playerLocation[player] == "arena" then
			return
		end
		HubWorldManager.sendToArena(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		HubWorldManager.pushLobbyState(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
