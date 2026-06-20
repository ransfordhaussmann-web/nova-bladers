local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local inArena = {}

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end

	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	}
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(entries)
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil

	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawn = hubModel and hubModel:FindFirstChild("HubSpawn")
	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET)
	end

	sendLobbyReady(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawn = findArenaSpawn()
	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(HubConfig.ARENA_FALLBACK)
	end

	inArena[player] = true

	local hud = player:FindFirstChild("PlayerGui")
	if hud then
		local lobby = hud:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function onEnterArena(player)
	if inArena[player] then return end
	HubWorldManager.teleportToArena(player)
end

local function onOpenBeySelect(player)
	if inArena[player] then return end
	remotes.OpenBeySelect:FireClient(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				HubWorldManager.teleportToArena(player)
			else
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	refreshLeaderboardBoard()
end

local function onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.OpenBeySelect.OnServerEvent:Connect(onOpenBeySelect)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(30)
			refreshLeaderboardBoard()
			for _, player in Players:GetPlayers() do
				if not inArena[player] then
					sendLobbyReady(player)
				end
			end
		end
	end)
end

return HubWorldManager
