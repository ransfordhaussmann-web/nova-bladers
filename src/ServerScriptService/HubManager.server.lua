local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local function ensureRemotes()
	local remotes = NovaBladers:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = NovaBladers
	end

	local function remote(name)
		local existing = remotes:FindFirstChild(name)
		if existing then return existing end
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
		return r
	end

	return {
		LobbyReady = remote("LobbyReady"),
		EnterArena = remote("EnterArena"),
		ReturnToHub = remote("ReturnToHub"),
	}
end

local remotes = ensureRemotes()
local hub, zones = HubWorldBuilder.build()
local inHub = {}
local gateCooldown = {}
local spawnIndex = 0

local function modeLabelFor(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function nextSpawnIndex()
	spawnIndex = (spawnIndex % #HubConfig.SPAWN_POINTS) + 1
	return spawnIndex
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local cf = HubWorldBuilder.getSpawnCFrame(nextSpawnIndex())
	root.CFrame = cf
	inHub[player] = true
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function enterArena(player)
	if not inHub[player] then return end
	local now = os.clock()
	if gateCooldown[player] and now - gateCooldown[player] < HubConfig.GATE_COOLDOWN then
		return
	end
	gateCooldown[player] = now
	inHub[player] = false

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(HubConfig.ARENA_SPAWN)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inHub[player] ~= false then
				inHub[player] = true
				teleportToHub(player)
				sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		inHub[player] = true
		teleportToHub(player)
	end

	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	inHub[player] = nil
	gateCooldown[player] = nil
	PlayerDataManager.save(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

remotes.EnterArena.OnServerEvent:Connect(enterArena)

if zones and zones.ArenaGate then
	zones.ArenaGate.prompt.Triggered:Connect(function(player)
		enterArena(player)
	end)
end

remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	inHub[player] = true
	teleportToHub(player)
	sendLobbyReady(player)
end)

return {
	teleportToHub = teleportToHub,
	sendLobbyReady = sendLobbyReady,
	enterArena = enterArena,
}
