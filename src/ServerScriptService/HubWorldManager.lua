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
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function getPlayerRank(player, data)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 1
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherData = PlayerDataManager.get(other)
			if PlayerDataManager.getRankPoints(otherData) > points then
				rank += 1
			end
		end
	end
	return rank
end

local function buildZoneMarker(zoneId, zone)
	local marker = Instance.new("Part")
	marker.Name = zoneId
	marker.Anchored = true
	marker.CanCollide = true
	marker.Size = zone.size
	marker.Position = zone.position
	marker.Color = zone.color
	marker.Material = Enum.Material.Neon
	marker.Parent = hubFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.actionText
	prompt.ObjectText = zone.objectText
	prompt.HoldDuration = zone.holdDuration or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zoneId)
	prompt.Parent = marker

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	return marker
end

local function buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	hubFolder = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hubFolder then
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.SPAWN - Vector3.new(0, HubConfig.FLOOR_SIZE.Y * 0.5 + 3, 0)
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hubFolder

	for zoneId, zone in HubConfig.ZONES do
		buildZoneMarker(zoneId, zone)
	end

	return hubFolder
end

local function getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.SPAWN + Vector3.new(0, 2, 0)
	end

	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end

	return arena:GetPivot().Position + Vector3.new(0, 5, 0)
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player, data),
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inArena = HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.pushLobbyState(player)
	if not remotes then
		return
	end
	local payload = HubWorldManager.buildLobbyPayload(player)
	remotes.HubState:FireClient(player, payload)
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = false
	teleportCharacter(player, HubConfig.SPAWN)
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	teleportCharacter(player, getArenaSpawn())
	HubWorldManager.pushLobbyState(player)
end

local function onEnterArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end

local function onRefreshHubStats(player)
	HubWorldManager.pushLobbyState(player)
end

local function onOpenBeySelect(player)
	if not remotes then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	inArena[player] = false

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				teleportCharacter(player, getArenaSpawn())
			else
				teleportCharacter(player, HubConfig.SPAWN)
				HubWorldManager.pushLobbyState(player)
			end
		end)
	end)

	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.RefreshHubStats.OnServerEvent:Connect(onRefreshHubStats)
	remotes.OpenBeySelect.OnServerEvent:Connect(onOpenBeySelect)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function()
		for _, player in Players:GetPlayers() do
			HubWorldManager.pushLobbyState(player)
		end
	end)
	Players.PlayerRemoving:Connect(function()
		for _, player in Players:GetPlayers() do
			HubWorldManager.pushLobbyState(player)
		end
	end)
end

return HubWorldManager
