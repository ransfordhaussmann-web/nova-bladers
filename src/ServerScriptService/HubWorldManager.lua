local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local hub
local remotes
local playerZones = {}
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_PATHS do
		local node = workspace
		local ok = true
		for _, name in path do
			node = node:FindFirstChild(name)
			if not node then
				ok = false
				break
			end
		end
		if ok and node:IsA("BasePart") then
			return node
		end
	end

	local arena = workspace:FindFirstChild("Arena")
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

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
end

local function buildLobbyPayload(player, deps)
	local data = deps.PlayerDataManager.get(player)
	local rankPoints = deps.PlayerDataManager.getRankPoints(data)
	local leaderboard = deps.LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.init(deps)
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	local leaderboard = deps.LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.updateLeaderboard(hub, leaderboard)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inArena[player] then return end
		local spawn = findArenaSpawn()
		if not spawn then
			warn("[NovaBladers] Arena-Spawn nicht gefunden")
			return
		end
		inArena[player] = true
		teleportCharacter(player, spawn.Position + Vector3.new(0, 3, 0))
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "EnterArena" then
			if inArena[player] then return end
			local spawn = findArenaSpawn()
			if not spawn then
				warn("[NovaBladers] Arena-Spawn nicht gefunden")
				return
			end
			inArena[player] = true
			teleportCharacter(player, spawn.Position + Vector3.new(0, 3, 0))
		elseif action == "OpenBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		end
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player, deps)
	end
	Players.PlayerAdded:Connect(function(player)
		HubWorldManager.onPlayerAdded(player, deps)
	end)
	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		inArena[player] = nil
	end)
end

function HubWorldManager.onPlayerAdded(player, deps)
	player.CharacterAdded:Connect(function()
		if inArena[player] then return end
		task.defer(function()
			teleportCharacter(player, HubConfig.SPAWN)
			local payload = buildLobbyPayload(player, deps)
			remotes.LobbyReady:FireClient(player, payload)
		end)
	end)

	if player.Character and not inArena[player] then
		teleportCharacter(player, HubConfig.SPAWN)
	end

	local payload = buildLobbyPayload(player, deps)
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.returnToHub(player, deps)
	inArena[player] = false
	teleportCharacter(player, HubConfig.SPAWN)
	local payload = buildLobbyPayload(player, deps)
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.refreshLeaderboard(deps)
	if not hub then return end
	local leaderboard = deps.LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.updateLeaderboard(hub, leaderboard)
end

function HubWorldManager.getHub()
	return hub
end

return HubWorldManager
