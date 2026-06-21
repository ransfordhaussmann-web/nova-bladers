local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local NovaFolder = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaFolder:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaFolder
end

local function ensureRemote(name, className)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local LobbyReady = ensureRemote("LobbyReady", "RemoteEvent")
local EnterArena = ensureRemote("EnterArena", "RemoteEvent")

local hub = HubWorldBuilder.getOrCreate()
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

local function formatLeaderboardLines(entries)
	local lines = { "🏆 Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return lines
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(hub, formatLeaderboardLines(leaderboard))
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	}
end

local function getHubSpawnCFrame()
	local spawn = hub:FindFirstChild("Geometry")
		and hub.Geometry:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return HubConfig.SPAWN_CFRAME
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = getHubSpawnCFrame()
	inArena[player] = nil
end

local function sendLobbyReady(player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function refreshAllLobbies()
	local payloadByPlayer = {}
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			payloadByPlayer[player] = buildLobbyPayload(player)
		end
	end
	for player, payload in payloadByPlayer do
		LobbyReady:FireClient(player, payload)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not inArena[player] then
				teleportToHub(player)
				sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end
	sendLobbyReady(player)
	refreshAllLobbies()
end

local function onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
	refreshAllLobbies()
end

EnterArena.OnServerEvent:Connect(function(player)
	inArena[player] = true
	-- Arena-Spawn wird vom GameManager übernommen, sobald exportiert.
	-- Bis dahin: Spieler bleibt markiert als „in Arena“.
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and spawn and spawn:IsA("BasePart") then
			root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
