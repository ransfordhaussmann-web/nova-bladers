local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local HubManager = {}
local hubFolder
local inArena = {}
local spawnIndex = 0
local enterArenaBindable

local function countHubPlayers()
	local count = 0
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			count += 1
		end
	end
	return count
end

local function getModeLabel()
	local hubCount = countHubPlayers()
	if hubCount <= 1 then
		return "Modus: Training"
	elseif hubCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", hubCount)
end

function HubManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	}
end

function HubManager.sendLobbyReady(player)
	Remotes.LobbyReady:FireClient(player, HubManager.buildLobbyPayload(player))
end

function HubManager.broadcastLobbyReady()
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			HubManager.sendLobbyReady(player)
		end
	end
end

local function getNextSpawnCFrame()
	local spawns = hubFolder:WaitForChild("Spawns"):GetChildren()
	if #spawns == 0 then
		return CFrame.new(HubConfig.ZONES.SpawnCenter + Vector3.new(0, HubConfig.SPAWN_HEIGHT, 0))
	end
	spawnIndex = (spawnIndex % #spawns) + 1
	return spawns[spawnIndex].CFrame
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	inArena[player] = false
	player:SetAttribute("InHub", true)

	humanoid.WalkSpeed = HubConfig.WALK_SPEED
	humanoid.JumpPower = 50
	root.CFrame = getNextSpawnCFrame()
end

function HubManager.enterArena(player)
	inArena[player] = true
	player:SetAttribute("InHub", false)
end

function HubManager.returnToHub(player)
	HubManager.teleportToHub(player)
	task.defer(function()
		HubManager.sendLobbyReady(player)
		HubManager.broadcastLobbyReady()
	end)
end

function HubManager.isInArena(player)
	return inArena[player] == true
end

local function requestEnterArena(player)
	if inArena[player] then
		return
	end
	HubManager.enterArena(player)
	if enterArenaBindable then
		enterArenaBindable:Fire(player)
	end
end

local function onCharacterReady(player)
	if inArena[player] then
		return
	end
	HubManager.teleportToHub(player)
	task.defer(function()
		HubManager.sendLobbyReady(player)
		HubManager.broadcastLobbyReady()
	end)
end

local function bindArenaPortal()
	local portal = hubFolder:WaitForChild("ArenaPortal")
	local gate = portal:WaitForChild("GateTrigger")
	local prompt = gate:WaitForChild("ArenaPrompt")

	prompt.Triggered:Connect(requestEnterArena)
end

local function bindStatsKiosk()
	local kiosk = hubFolder:WaitForChild("LeaderboardKiosk")
	local trigger = kiosk:WaitForChild("StatsTrigger")
	local prompt = trigger:WaitForChild("StatsPrompt")

	prompt.Triggered:Connect(function(player)
		if inArena[player] then
			return
		end
		HubManager.sendLobbyReady(player)
	end)
end

function HubManager.init()
	hubFolder = HubWorldBuilder.build()

	enterArenaBindable = NovaBladers:FindFirstChild("EnterArenaBindable")
	if not enterArenaBindable then
		enterArenaBindable = Instance.new("BindableEvent")
		enterArenaBindable.Name = "EnterArenaBindable"
		enterArenaBindable.Parent = NovaBladers
	end

	Remotes.EnterArena.OnServerEvent:Connect(requestEnterArena)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			onCharacterReady(player)
		end)
		if player.Character then
			onCharacterReady(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
		task.defer(HubManager.broadcastLobbyReady)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			onCharacterReady(player)
		end)
		if player.Character then
			onCharacterReady(player)
		end
	end

	bindArenaPortal()
	bindStatsKiosk()
end

return HubManager
