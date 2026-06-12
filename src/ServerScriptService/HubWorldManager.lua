local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldConfig = require(NovaBladers.HubWorldConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
end

local function ensureRemote(name)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local EnterArena = ensureRemote("EnterArena")
local LobbyReady = ensureRemote("LobbyReady")
local OpenBeySelect = ensureRemote("OpenBeySelect")
local ReturnToHub = ensureRemote("ReturnToHub")
local RefreshLobby = ensureRemote("RefreshLobby")

local playerStates = {}
local hubFolder

local HubWorldManager = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.MaxActivationDistance = HubWorldConfig.PROMPT_RANGE
	prompt.HoldDuration = HubWorldConfig.PROMPT_HOLD
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(60, 60, 60)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	if props.Shape then
		part.Shape = props.Shape
	end
	if props.CFrame then
		part.CFrame = props.CFrame
	end
	part.Parent = props.Parent
	return part
end

local function createLabel(parent, text, size)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

function HubWorldManager.isInArena(player)
	return playerStates[player] == "arena"
end

function HubWorldManager.getLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.sendLobbyUpdate(player)
	LobbyReady:FireClient(player, HubWorldManager.getLobbyPayload(player))
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
	root.CFrame = CFrame.new(HubWorldConfig.HUB_SPAWN)
end

function HubWorldManager.returnToHub(player)
	playerStates[player] = "hub"
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyUpdate(player)
	RefreshLobby:FireClient(player, HubWorldManager.getLobbyPayload(player))
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubWorldConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end
	local spawn = arena:FindFirstChild(HubWorldConfig.ARENA_SPAWN_NAME, true)
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	return arena:FindFirstChildWhichIsA("SpawnLocation", true)
end

function HubWorldManager.sendToArena(player)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local spawn = findArenaSpawn()
	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 10, 0)
	end

	playerStates[player] = "arena"
	HubWorldManager.sendLobbyUpdate(player)
	return true
end

local function buildHubWorld()
	if hubFolder then
		hubFolder:Destroy()
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubWorldConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local platform = createPart({
		Name = "HubPlatform",
		Size = HubWorldConfig.PLATFORM_SIZE,
		Position = HubWorldConfig.PLATFORM_POSITION + Vector3.new(0, -1, 0),
		Color = HubWorldConfig.COLORS.Platform,
		Material = Enum.Material.Slate,
		Parent = hubFolder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubWorldConfig.HUB_SPAWN - Vector3.new(0, 3, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hubFolder

	createPart({
		Name = "CenterRing",
		Size = Vector3.new(16, 0.4, 16),
		Position = Vector3.new(0, 0.2, 0),
		Color = HubWorldConfig.COLORS.Accent,
		Material = Enum.Material.Neon,
		Parent = hubFolder,
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})

	local gateBase = createPart({
		Name = "ArenaGate",
		Size = Vector3.new(14, 10, 2),
		Position = HubWorldConfig.ARENA_GATE_POSITION,
		Color = HubWorldConfig.COLORS.Gate,
		Material = Enum.Material.Metal,
		Parent = hubFolder,
	})
	createPart({
		Name = "GateArchLeft",
		Size = Vector3.new(2, 12, 2),
		Position = gateBase.Position + Vector3.new(-6, 1, 0),
		Color = HubWorldConfig.COLORS.Gate,
		Material = Enum.Material.Metal,
		Parent = hubFolder,
	})
	createPart({
		Name = "GateArchRight",
		Size = Vector3.new(2, 12, 2),
		Position = gateBase.Position + Vector3.new(6, 1, 0),
		Color = HubWorldConfig.COLORS.Gate,
		Material = Enum.Material.Metal,
		Parent = hubFolder,
	})
	createLabel(gateBase, "ARENA", 50)
	buildPrompt(gateBase, HubWorldConfig.PROMPT_ACTION_TEXT.ARENA, "Kampf starten")

	local beyPedestal = createPart({
		Name = "BeySelectPedestal",
		Size = Vector3.new(6, 3, 6),
		Position = HubWorldConfig.BEY_SELECT_POSITION,
		Color = HubWorldConfig.COLORS.Pedestal,
		Material = Enum.Material.Glass,
		Parent = hubFolder,
	})
	createLabel(beyPedestal, "BEY", 50)
	buildPrompt(beyPedestal, HubWorldConfig.PROMPT_ACTION_TEXT.BEY_SELECT, "Auswahl")

	local leaderboardBoard = createPart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 1),
		Position = HubWorldConfig.LEADERBOARD_POSITION,
		Color = HubWorldConfig.COLORS.Board,
		Material = Enum.Material.SmoothPlastic,
		Parent = hubFolder,
	})
	createLabel(leaderboardBoard, "TOP 5", 50)

	local statsBoard = createPart({
		Name = "StatsBoard",
		Size = Vector3.new(10, 6, 1),
		Position = HubWorldConfig.STATS_BOARD_POSITION,
		Color = HubWorldConfig.COLORS.Board,
		Material = Enum.Material.SmoothPlastic,
		Parent = hubFolder,
	})
	createLabel(statsBoard, "STATS", 50)
	buildPrompt(statsBoard, HubWorldConfig.PROMPT_ACTION_TEXT.STATS, "Deine Werte")

	for _, offset in { Vector3.new(-40, 2, -20), Vector3.new(40, 2, -20), Vector3.new(-40, 2, 20), Vector3.new(40, 2, 20) } do
		createPart({
			Name = "Pillar",
			Size = Vector3.new(3, 8, 3),
			Position = HubWorldConfig.PLATFORM_POSITION + offset,
			Color = HubWorldConfig.COLORS.Accent,
			Material = Enum.Material.Neon,
			Parent = hubFolder,
		})
	end

	local sign = createPart({
		Name = "WelcomeSign",
		Size = Vector3.new(20, 4, 1),
		Position = Vector3.new(0, 7, 35),
		Color = HubWorldConfig.COLORS.Accent,
		Material = Enum.Material.Neon,
		Parent = hubFolder,
	})
	createLabel(sign, "NOVA BLADERS", 50)

	return hubFolder
end

local function bindHubPrompts()
	if not hubFolder then
		return
	end

	local gate = hubFolder:FindFirstChild("ArenaGate")
	if gate then
		local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if HubWorldManager.isInArena(player) then
					return
				end
				HubWorldManager.sendToArena(player)
			end)
		end
	end

	local pedestal = hubFolder:FindFirstChild("BeySelectPedestal")
	if pedestal then
		local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				OpenBeySelect:FireClient(player)
			end)
		end
	end

	local statsBoard = hubFolder:FindFirstChild("StatsBoard")
	if statsBoard then
		local prompt = statsBoard:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				RefreshLobby:FireClient(player, HubWorldManager.getLobbyPayload(player))
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	playerStates[player] = "hub"
	PlayerDataManager.load(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if playerStates[player] == "hub" then
			HubWorldManager.teleportToHub(player)
		end
	end)

	task.defer(function()
		HubWorldManager.sendLobbyUpdate(player)
	end)
end

function HubWorldManager.init()
	buildHubWorld()
	bindHubPrompts()

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)

	EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerStates[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		HubWorldManager.onPlayerAdded(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
