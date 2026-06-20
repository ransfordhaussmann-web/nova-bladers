local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes

local function getRemotes()
	if remotes then
		return remotes
	end
	remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	return remotes
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(HubConfig.ARENA_FALLBACK_OFFSET)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = targetCFrame
	return true
end

function HubWorldManager.spawnInHub(player)
	player:SetAttribute("InHub", true)
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.sendLobbyData(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.enterArena(player)
	player:SetAttribute("InHub", false)
	teleportCharacter(player, findArenaSpawnCFrame())
end

local function handleZoneAction(player, zoneId)
	if zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "BeyLab" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		getRemotes().ShowHallPanel:FireClient(player, buildLobbyPayload(player))
	end
end

function HubWorldManager.init()
	HubWorldBuilder.build()

	local remoteFolder = getRemotes()
	remoteFolder.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remoteFolder.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remoteFolder.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)

		local function onCharacter()
			if player:GetAttribute("InHub") ~= false then
				HubWorldManager.spawnInHub(player)
			end
			HubWorldManager.sendLobbyData(player)
		end

		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character and player:GetAttribute("InHub") ~= false then
			HubWorldManager.spawnInHub(player)
		end
		HubWorldManager.sendLobbyData(player)
	end
end

return HubWorldManager
