local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local hubFolder
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena") or workspace:FindFirstChild("Bowl")
	if not arena then return nil end

	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	local bowl = arena:FindFirstChild("Bowl", true)
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function getRank(data)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 1
	for _, other in Players:GetPlayers() do
		local otherData = PlayerDataManager.get(other)
		if PlayerDataManager.getRankPoints(otherData) > points then
			rank += 1
		end
	end
	return rank
end

function HubWorldManager.sendLobbyState(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = getRank(data),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	})
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubFolder then return end
	HubWorldBuilder.createLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN)
	end
	HubWorldManager.sendLobbyState(player)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	HubWorldManager.spawnInHub(player)
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Kein Arena-Spawn gefunden — Workspace.Arena/Bowl prüfen")
		return false
	end

	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	inArena[player] = true
	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	return true
end

local function handleZoneAction(player, zoneId)
	if zoneId == "ArenaGate" then
		if teleportToArena(player) then
			local gui = player:FindFirstChild("PlayerGui")
			if gui then
				local lobby = gui:FindFirstChild("Lobby")
				if lobby then lobby.Enabled = false end
			end
		end
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.refreshLeaderboardBoard()
		HubWorldManager.sendLobbyState(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not inArena[player] then
			HubWorldManager.spawnInHub(player)
		end
	end)
	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(30)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
