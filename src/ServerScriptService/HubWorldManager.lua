local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local playerState = {}
local cachedPayload = {}
local enterArenaCallbacks = {}

local function createPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createSign(parent: Instance, text: string, offset: Vector3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function createZone(zoneName: string, zoneConfig: any, parent: Instance)
	local part = createPart(
		zoneName,
		zoneConfig.size,
		zoneConfig.position,
		zoneConfig.color,
		parent
	)
	part.Transparency = 0.25
	part.Material = Enum.Material.Neon
	part.CanCollide = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zoneConfig.prompt
	prompt.ObjectText = zoneName
	prompt.HoldDuration = zoneConfig.holdDuration or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	createSign(part, zoneConfig.prompt, Vector3.new(0, zoneConfig.size.Y * 0.5 + 2, 0))

	return part, prompt
end

local function buildHubWorld()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = HubConfig.HUB_FOLDER_NAME
	folder.Parent = workspace

	local floor = createPart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		HubConfig.SPAWN_POSITION - Vector3.new(0, 3.5, 0),
		HubConfig.FLOOR_COLOR,
		folder
	)
	floor.Material = Enum.Material.Slate

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = folder

	for zoneName, zoneConfig in HubConfig.ZONES do
		createZone(zoneName, zoneConfig, zonesFolder)
	end

	return folder
end

local function getArenaSpawn(): CFrame?
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end
	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return arena:GetPivot() + Vector3.new(0, 5, 0)
end

local function teleportPlayer(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function getModeLabel(playerCount: number): string
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

function HubWorldManager.buildLobbyPayload(player: Player, data: any, leaderboard: { any }): any
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = (data.Wins * 3) - data.Losses,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		useHubWorld = true,
	}
end

function HubWorldManager.sendLobbyReady(player: Player, payload: any)
	cachedPayload[player] = payload
	playerState[player] = "hub"
	Remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.isInArena(player: Player): boolean
	return playerState[player] == "arena"
end

function HubWorldManager.onEnterArena(callback: (Player) -> ())
	table.insert(enterArenaCallbacks, callback)
end

function HubWorldManager.sendToArena(player: Player)
	local spawnCFrame = getArenaSpawn()
	if not spawnCFrame then
		warn("[HubWorldManager] Arena-Ordner nicht gefunden:", HubConfig.ARENA_FOLDER_NAME)
		return false
	end
	playerState[player] = "arena"
	teleportPlayer(player, spawnCFrame)
	return true
end

function HubWorldManager.returnToHub(player: Player)
	playerState[player] = "hub"
	local spawnCFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	teleportPlayer(player, spawnCFrame)

	local payload = cachedPayload[player]
	if payload then
		Remotes.LobbyReady:FireClient(player, payload)
	end
end

function HubWorldManager.requestEnterArena(player: Player)
	if playerState[player] == "arena" then
		return
	end
	for _, callback in enterArenaCallbacks do
		task.spawn(callback, player)
	end
	HubWorldManager.sendToArena(player)
	Remotes.ArenaEntered:FireClient(player)
end

local function handleZoneAction(player: Player, action: string)
	if action == "enterArena" then
		HubWorldManager.requestEnterArena(player)
	elseif action == "openBeySelect" then
		Remotes.OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		local payload = cachedPayload[player]
		if payload then
			Remotes.HubShowStats:FireClient(player, payload)
		end
	end
end

local function connectZonePrompts(folder: Folder)
	local zones = folder:FindFirstChild("Zones")
	if not zones then
		return
	end
	for zoneName, zoneConfig in HubConfig.ZONES do
		local part = zones:FindFirstChild(zoneName)
		if not part then
			continue
		end
		local prompt = part:FindFirstChild("HubPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(triggerPlayer)
				handleZoneAction(triggerPlayer, zoneConfig.action)
			end)
		end
	end
end

function HubWorldManager.init()
	local folder = buildHubWorld()
	connectZonePrompts(folder)

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.requestEnterArena(player)
	end)
end

function HubWorldManager.onPlayerAdded(player: Player)
	playerState[player] = "hub"
	player.CharacterAdded:Connect(function()
		if playerState[player] == "hub" then
			task.defer(function()
				teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
			end)
		end
	end)
end

function HubWorldManager.onPlayerRemoving(player: Player)
	playerState[player] = nil
	cachedPayload[player] = nil
end

return HubWorldManager
