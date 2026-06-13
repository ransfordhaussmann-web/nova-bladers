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
local playerState = {}

local function getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		local bowl = arena:FindFirstChild("Bowl", true) or arena:FindFirstChildWhichIsA("BasePart", true)
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + Vector3.new(0, HubConfig.ARENA_SPAWN_OFFSET.Y, 0)
		end
	end
	return CFrame.new(HubConfig.HUB_SPAWN + Vector3.new(80, 0, 0))
end

local function getHubSpawn()
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_SPAWN)
end

local function teleportPlayer(player, cf)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end

local function setCharacterVisible(player, visible)
	local character = player.Character
	if not character then return end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = visible and 0 or 1
			part.CanCollide = visible
		elseif part:IsA("Decal") then
			part.Transparency = visible and 0 or 1
		end
	end
end

local function buildBillboard(parent, title, hint)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 80)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 0.45, 0)
	hintLabel.Position = UDim2.fromScale(0, 0.55)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 13
	hintLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	hintLabel.TextStrokeTransparency = 0.6
	hintLabel.Text = hint
	hintLabel.Parent = billboard
end

local function buildZone(zoneDef)
	local zone = Instance.new("Part")
	zone.Name = "Zone_" .. zoneDef.id
	zone.Anchored = true
	zone.CanCollide = true
	zone.Size = zoneDef.size
	zone.Position = zoneDef.position + Vector3.new(0, zoneDef.size.Y * 0.5, 0)
	zone.Color = zoneDef.color
	zone.Material = Enum.Material.Neon
	zone.Transparency = 0.35
	zone.Parent = hubFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.promptText
	prompt.ObjectText = zoneDef.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone

	buildBillboard(zone, zoneDef.name, zoneDef.hint)

	prompt.Triggered:Connect(function(player)
		HubWorldManager.handleZoneAction(player, zoneDef.action)
	end)
end

local function buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	if not HubConfig.BUILD_HUB_IF_MISSING then
		return nil
	end

	hubFolder = Instance.new("Model")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = Vector3.new(0, -0.5, 0)
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("Part")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.Position = HubConfig.HUB_SPAWN
	spawn.Parent = hubFolder

	for _, zoneDef in HubConfig.ZONES do
		buildZone(zoneDef)
	end

	local centerSign = Instance.new("Part")
	centerSign.Name = "WelcomeSign"
	centerSign.Anchored = true
	centerSign.Size = Vector3.new(8, 1, 4)
	centerSign.Position = Vector3.new(0, 0.5, -8)
	centerSign.Color = Color3.fromRGB(60, 65, 80)
	centerSign.Material = Enum.Material.Metal
	centerSign.Parent = hubFolder
	buildBillboard(centerSign, "Nova Bladers", "Laufe zu einer Zone")

	return hubFolder
end

function HubWorldManager.isInArena(player)
	local state = playerState[player]
	return state and state.inArena == true
end

function HubWorldManager.sendLobbyPayload(player, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	local playerCount = #Players:GetPlayers()
	local modeLabel = "Modus: Training"
	if playerCount >= 3 then
		modeLabel = "Modus: FFA"
	elseif playerCount == 2 then
		modeLabel = "Modus: 1v1 PvP"
	end

	local inHub = not HubWorldManager.isInArena(player)
	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = leaderboard,
		inHub = inHub,
		showPanel = showPanel == true or not inHub,
	})
end

function HubWorldManager.sendHubState(player)
	remotes.HubState:FireClient(player, {
		inHub = not HubWorldManager.isInArena(player),
	})
end

function HubWorldManager.returnToHub(player)
	playerState[player] = { inArena = false }
	setCharacterVisible(player, true)
	teleportPlayer(player, getHubSpawn())
	HubWorldManager.sendHubState(player)
	HubWorldManager.sendLobbyPayload(player)
end

function HubWorldManager.sendToArena(player)
	playerState[player] = { inArena = true }
	teleportPlayer(player, getArenaSpawn())
	HubWorldManager.sendHubState(player)
end

function HubWorldManager.enterArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end

function HubWorldManager.handleZoneAction(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showLobby" then
		HubWorldManager.sendLobbyPayload(player, true)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	playerState[player] = { inArena = false }

	local function setupCharacter(character)
		task.defer(function()
			if not HubWorldManager.isInArena(player) then
				teleportPlayer(player, getHubSpawn())
				setCharacterVisible(player, true)
			end
		end)
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	HubWorldManager.sendHubState(player)
	HubWorldManager.sendLobbyPayload(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(HubWorldManager.enterArena)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(HubWorldManager.onPlayerAdded, player)
	end
end

return HubWorldManager
