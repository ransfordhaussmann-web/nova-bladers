local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local inArena = {}
local remotes = nil
local hubFolder = nil

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count >= 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = points,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = HubConfig.USE_3D_HUB and not HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.sendLobbyUpdate(player)
	if remotes and remotes:FindFirstChild("LobbyReady") then
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end
end

function HubWorldManager.broadcastLobbyUpdates()
	for _, player in Players:GetPlayers() do
		if not HubWorldManager.isInArena(player) then
			HubWorldManager.sendLobbyUpdate(player)
		end
	end
end

function HubWorldManager.teleportToHub(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN)
	end
end

function HubWorldManager.returnToHub(player)
	inArena[player] = false
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyUpdate(player)
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if not arena then
		warn("[HubWorldManager] Arena folder not found:", HubConfig.ARENA_FOLDER)
		return
	end

	local spawn = arena:FindFirstChild("Spawn")
		or arena:FindFirstChildWhichIsA("SpawnLocation", true)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and spawn then
		local offset = Vector3.new(0, 3, 0)
		if spawn:IsA("BasePart") then
			root.CFrame = spawn.CFrame + offset
		elseif spawn:IsA("SpawnLocation") then
			root.CFrame = spawn.CFrame + offset
		end
	end
end

local function createSign(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function createZone(zoneKey, zoneData)
	local zone = Instance.new("Part")
	zone.Name = zoneKey
	zone.Size = zoneData.size
	zone.Position = HubConfig.HUB_ORIGIN + zoneData.position
	zone.Anchored = true
	zone.CanCollide = true
	zone.Color = zoneData.color
	zone.Material = Enum.Material.Neon
	zone.Parent = hubFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneData.promptText
	prompt.ObjectText = zoneData.name
	prompt.HoldDuration = zoneData.holdDuration or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone

	createSign(zone, zoneData.name)

	prompt.Triggered:Connect(function(player)
		if HubWorldManager.isInArena(player) then
			return
		end
		if zoneData.action == "EnterArena" then
			HubWorldManager.sendToArena(player)
		elseif zoneData.action == "OpenBeySelect" and remotes:FindFirstChild("OpenBeySelect") then
			remotes.OpenBeySelect:FireClient(player)
		elseif zoneData.action == "RefreshLeaderboard" then
			HubWorldManager.sendLobbyUpdate(player)
		end
	end)

	return zone
end

local function createLeaderboardBoard()
	local board = Instance.new("Part")
	board.Name = "LeaderboardBoard"
	board.Size = Vector3.new(12, 8, 0.5)
	board.Position = HubConfig.HUB_ORIGIN + Vector3.new(0, 6, -52)
	board.Anchored = true
	board.CanCollide = false
	board.Color = Color3.fromRGB(30, 32, 42)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = hubFolder

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = HubConfig.LEADERBOARD_BOARD_SIZE
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Text = "🏆 Top Spieler"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 44)
	list.Size = UDim2.new(1, 0, 1, -44)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 18
	list.TextColor3 = Color3.fromRGB(220, 220, 230)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.Parent = surface

	return board
end

function HubWorldManager.updateLeaderboardBoard()
	if not hubFolder then
		return
	end
	local board = hubFolder:FindFirstChild("LeaderboardBoard")
	local gui = board and board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end

	local entries = LeaderboardManager.getTop(5)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

function HubWorldManager.buildHubWorld()
	hubFolder = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if hubFolder then
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER
	hubFolder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.HUB_ORIGIN + Vector3.new(0, -0.5, 0)
	floor.Anchored = true
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hubFolder

	for zoneKey, zoneData in HubConfig.ZONES do
		createZone(zoneKey, zoneData)
	end

	createLeaderboardBoard()
	createSign(floor, "Nova Bladers Hub", Vector3.new(0, 8, 0))

	return hubFolder
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	inArena[player] = false

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not HubWorldManager.isInArena(player) then
			HubWorldManager.teleportToHub(player)
		end
	end)

	HubWorldManager.sendLobbyUpdate(player)
	HubWorldManager.updateLeaderboardBoard()
	HubWorldManager.broadcastLobbyUpdates()
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
	HubWorldManager.broadcastLobbyUpdates()
end

function HubWorldManager.init()
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	remotes = nova:WaitForChild("Remotes")

	if HubConfig.USE_3D_HUB then
		HubWorldManager.buildHubWorld()
		HubWorldManager.updateLeaderboardBoard()
	end

	if remotes:FindFirstChild("EnterArena") then
		remotes.EnterArena.OnServerEvent:Connect(function(player)
			HubWorldManager.sendToArena(player)
		end)
	end
end

return HubWorldManager
