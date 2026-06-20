local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local inArena = {}

local function getRemotes()
	return RemotesSetup.ensure()
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name, true)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end
	return nil
end

local function teleportTo(character, targetCFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(targetCFrame)
	end
end

function HubWorldManager.getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	local spawnPart = hub and hub:FindFirstChild("HubSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN)
end

function HubWorldManager.sendLobbyData(player)
	local remotes = getRemotes()
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local character = player.Character
	if character then
		teleportTo(character, HubWorldManager.getHubSpawnCFrame())
	end
	HubWorldManager.sendLobbyData(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	local remotes = getRemotes()
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	local character = player.Character
	if not character then return end

	local arenaSpawn = findArenaSpawn()
	local target = arenaSpawn and (arenaSpawn.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(0, 5, 0)
	teleportTo(character, target)
end

function HubWorldManager.handleZoneAction(player, action)
	if action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "openBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif action == "showHall" then
		HubWorldManager.sendLobbyData(player)
		getRemotes().ShowHallPanel:FireClient(player)
	end
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.init()
	RemotesSetup.ensure()
	HubWorldBuilder.build()

	local remotes = getRemotes()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			HubWorldManager.handleZoneAction(player, action)
		end
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not HubWorldManager.isInArena(player) then
					HubWorldManager.spawnInHub(player)
				end
			end)
		end)

		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
