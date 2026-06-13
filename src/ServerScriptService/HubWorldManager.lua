local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local HUB_ZONE_TAG = "NovaBladersHubZone"

local HubWorldManager = {}

local remotes
local playerState = {}
local playerDataManager
local leaderboardManager

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function applyLighting()
	for key, value in HubConfig.LIGHTING do
		if Lighting[key] ~= nil then
			Lighting[key] = value
		end
	end
end

local function createPrompt(part, promptText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = promptText
	prompt.ObjectText = "Nova Bladers"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = part
	return prompt
end

local function createZone(parent, zoneName, zoneData)
	local part = Instance.new("Part")
	part.Name = zoneName
	part.Size = zoneData.size
	part.CFrame = CFrame.new(HubConfig.HUB_ORIGIN + zoneData.offset)
	part.Anchored = true
	part.CanCollide = true
	part.Color = zoneData.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25
	part:SetAttribute("HubAction", zoneData.action)
	part.Parent = parent

	CollectionService:AddTag(part, HUB_ZONE_TAG)
	createPrompt(part, zoneData.promptText)
	return part
end

local function ensureHubSpawn(hubWorld)
	local spawn = hubWorld:FindFirstChild(HubConfig.HUB_SPAWN_NAME, true)
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end

	spawn = Instance.new("Part")
	spawn.Name = HubConfig.HUB_SPAWN_NAME
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.HUB_ORIGIN + Vector3.new(0, 3, 0))
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Parent = hubWorld
	return spawn
end

local function buildHubWorld()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_WORLD_NAME)
	if existing and not HubConfig.AUTO_BUILD_HUB then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local hubWorld = Instance.new("Model")
	hubWorld.Name = HubConfig.HUB_WORLD_NAME
	hubWorld.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.CFrame = CFrame.new(HubConfig.HUB_ORIGIN)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(45, 50, 65)
	floor.Material = Enum.Material.Slate
	floor.Parent = hubWorld

	for zoneName, zoneData in HubConfig.ZONES do
		createZone(hubWorld, zoneName, zoneData)
	end

	local sign = Instance.new("Part")
	sign.Name = "HubSign"
	sign.Size = Vector3.new(20, 4, 1)
	sign.CFrame = CFrame.new(HubConfig.HUB_ORIGIN + Vector3.new(0, 10, -30))
	sign.Anchored = true
	sign.Color = Color3.fromRGB(80, 140, 255)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Parent = hubWorld

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = "NOVA BLADERS HUB"
	title.Parent = billboard

	ensureHubSpawn(hubWorld)
	hubWorld.PrimaryPart = floor
	return hubWorld
end

local function getHubSpawnCFrame()
	local hubWorld = Workspace:FindFirstChild(HubConfig.HUB_WORLD_NAME)
	if not hubWorld then
		return CFrame.new(HubConfig.HUB_ORIGIN + Vector3.new(0, 4, 0))
	end

	local spawn = ensureHubSpawn(hubWorld)
	return spawn.CFrame + Vector3.new(0, 3, 0)
end

local function getArenaSpawnCFrame(playerIndex)
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_NAME)
	if not arena then
		return CFrame.new(0, 4, 0)
	end

	local spawns = {}
	for _, child in arena:GetDescendants() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #HubConfig.ARENA_SPAWN_PREFIX) == HubConfig.ARENA_SPAWN_PREFIX then
			table.insert(spawns, child)
		end
	end

	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)

	local spawn = spawns[playerIndex] or spawns[1]
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end

	return CFrame.new(0, 4, 0)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(5)
	local rank = 0

	for _, entry in leaderboard do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	}
end

local function setHubState(player, inHub)
	playerState[player] = inHub and "hub" or "arena"
	remotes.HubStateChanged:FireClient(player, { inHub = inHub })
end

function HubWorldManager.isInArena(player)
	return playerState[player] == "arena"
end

function HubWorldManager.sendLobbyData(player, showPanel)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player), showPanel == true)
end

function HubWorldManager.sendToArena(player)
	local playerIndex = math.clamp(#Players:GetPlayers(), 1, 4)
	setHubState(player, false)
	teleportPlayer(player, getArenaSpawnCFrame(playerIndex))
end

function HubWorldManager.returnToHub(player)
	setHubState(player, true)
	teleportPlayer(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyData(player, false)
end

function HubWorldManager.onPlayerAdded(player)
	playerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playerState[player] == "arena" then
				teleportPlayer(player, getArenaSpawnCFrame(1))
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	end
end

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager
	remotes = RemotesSetup.getRemotes()

	applyLighting()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.RequestLobbyData.OnServerEvent:Connect(function(player)
		HubWorldManager.sendLobbyData(player, true)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		remotes.OpenBeySelect:FireClient(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerDataManager.save(player)
		playerState[player] = nil
	end)
end

return HubWorldManager
