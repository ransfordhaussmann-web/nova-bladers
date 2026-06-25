local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerState = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena") or workspace:FindFirstChild("Bowl")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
			or arena:FindFirstChild("ArenaSpawn", true)
			or arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		if arena:IsA("Model") and arena.PrimaryPart then
			return arena.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
		end
	end
	return CFrame.new(0, 5, 200)
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function buildLobbyPayload(player, inHub, inArena)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
		inArena = inArena,
	}
end

local function sendLobbyReady(player)
	local state = playerState[player]
	if not state then
		return
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, state.inHub, state.inArena))
end

local function setPlayerInHub(player)
	local state = playerState[player]
	if not state then
		return
	end
	state.inHub = true
	state.inArena = false
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	local state = playerState[player]
	if not state or state.inArena then
		return
	end
	state.inHub = false
	state.inArena = true
	teleportCharacter(player, getArenaSpawnCFrame())
	sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	local state = playerState[player]
	if not state then
		return
	end
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	PlayerDataManager.persist(player)
	setPlayerInHub(player)
end

local function handleZoneInteract(player, zoneId)
	if not zoneId then
		return
	end
	local state = playerState[player]
	if not state or not state.inHub or state.inArena then
		return
	end

	if zoneId == "arena_gate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "bey_lab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "hall_of_fame" then
		sendLobbyReady(player)
		remotes.HubZoneHint:FireClient(player, {
			title = "Ruhmeshalle",
			body = "Die Top-5 findest du am Lobby-Panel (R-Taste) oder in der Statistik.",
		})
	end
end

local function onCharacterAdded(player, character)
	local state = playerState[player]
	if not state then
		return
	end
	task.defer(function()
		if state.inHub then
			teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
		elseif state.inArena then
			teleportCharacter(player, getArenaSpawnCFrame())
		end
	end)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	_G.NovaBladersEnterArena = function(player)
		HubWorldManager.enterArena(player)
	end
	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubInteract.OnServerEvent:Connect(function(player, zoneId)
		handleZoneInteract(player, zoneId)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		playerState[player] = { inHub = true, inArena = false }

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end

		task.defer(function()
			setPlayerInHub(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerState[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not playerState[player] then
			PlayerDataManager.load(player)
			playerState[player] = { inHub = true, inArena = false }
			setPlayerInHub(player)
		end
	end
end

return HubWorldManager
