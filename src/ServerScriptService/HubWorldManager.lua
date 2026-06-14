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
local playersInArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end

	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end

	local spawnLocation = arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end

	local floor = arena:FindFirstChildWhichIsA("BasePart", true)
	if floor then
		return floor.CFrame + Vector3.new(0, floor.Size.Y / 2 + 4, 0)
	end

	return nil
end

local function createZoneLabel(part, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

local function createZone(name, zone)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = zone.size
	part.Position = zone.position
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = zone.color
	part.Transparency = 0.35
	part.Parent = hubFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.label
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = part

	createZoneLabel(part, zone.label)

	return prompt
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

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	local spawnPos = HubConfig.HUB_SPAWN.Position
	floor.Position = Vector3.new(spawnPos.X, HubConfig.FLOOR_SIZE.Y / 2, spawnPos.Z)
	floor.Anchored = true
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.HUB_SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hubFolder

	for name, zone in HubConfig.ZONES do
		local prompt = createZone(name, zone)
		prompt.Triggered:Connect(function(player)
			HubWorldManager.handleZoneAction(player, zone.action)
		end)
	end

	local centerPillar = Instance.new("Part")
	centerPillar.Name = "CenterMarker"
	centerPillar.Shape = Enum.PartType.Cylinder
	centerPillar.Size = Vector3.new(2, 8, 8)
	centerPillar.CFrame = CFrame.new(HubConfig.HUB_SPAWN.Position - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	centerPillar.Anchored = true
	centerPillar.Color = Color3.fromRGB(120, 130, 180)
	centerPillar.Material = Enum.Material.Metal
	centerPillar.Parent = hubFolder

	return hubFolder
end

function HubWorldManager.buildLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 0

	local top = LeaderboardManager.getTop(100)
	for _, entry in top do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		rankPoints = points,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		showOverlay = options.showOverlay == true,
	}
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	player:SetAttribute("InArena", false)

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and hubFolder then
		local hubSpawn = hubFolder:FindFirstChild("HubSpawn")
		if hubSpawn then
			root.CFrame = hubSpawn.CFrame + Vector3.new(0, 3, 0)
		else
			root.CFrame = HubConfig.HUB_SPAWN
		end
	end

	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.sendToArena(player)
	local arenaCFrame = findArenaSpawn()
	if not arenaCFrame then
		warn("[NovaBladers] Arena-Ordner nicht gefunden:", HubConfig.ARENA_FOLDER_NAME)
		return false
	end

	playersInArena[player] = true
	player:SetAttribute("InArena", true)

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = arenaCFrame
		end
	end

	return true
end

function HubWorldManager.handleZoneAction(player, action)
	if action == "enterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player, { showOverlay = true }))
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if HubWorldManager.isInArena(player) then
			HubWorldManager.sendToArena(player)
		else
			HubWorldManager.returnToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	else
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInArena[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
