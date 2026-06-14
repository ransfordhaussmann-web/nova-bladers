local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local function ensureRemote(name)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

ensureRemote("LobbyReady")
ensureRemote("EnterArena")
ensureRemote("HubZoneAction")

local hubPlayers = {}
local hubBuilt = false

local function ensureHub()
	if hubBuilt then
		return workspace:WaitForChild("NovaHub")
	end
	HubWorldBuilder.build()
	hubBuilt = true
	return workspace.NovaHub
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
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

local function sendLobbyReady(player)
	if not hubPlayers[player] then
		return
	end
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function refreshAllLobbyClients()
	for player in hubPlayers do
		sendLobbyReady(player)
	end
end

local function teleportToHub(player)
	local hub = ensureHub()
	local spawn = hub:FindFirstChild("HubSpawn")
	if not spawn or not player.Character then
		return
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	end
end

local function enterArena(player)
	if not hubPlayers[player] then
		return
	end

	hubPlayers[player] = nil
	player:SetAttribute("NovaBladers_InHub", false)
	player:SetAttribute("NovaBladers_InArena", true)

	local hub = workspace:FindFirstChild("NovaHub")
	local arenaSpawn = hub and hub:FindFirstChild("ArenaSpawn")
	if player.Character and arenaSpawn then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = arenaSpawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	refreshAllLobbyClients()
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	hubPlayers[player] = true
	player:SetAttribute("NovaBladers_InHub", true)
	player:SetAttribute("NovaBladers_InArena", false)

	local function onCharacter(character)
		if hubPlayers[player] then
			task.defer(function()
				teleportToHub(player)
				sendLobbyReady(player)
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	else
		sendLobbyReady(player)
	end
end

local function onPlayerRemoving(player)
	hubPlayers[player] = nil
	PlayerDataManager.save(player)
	refreshAllLobbyClients()
end

ensureHub()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(function()
	refreshAllLobbyClients()
end)
Players.PlayerRemoving:Connect(function()
	refreshAllLobbyClients()
end)

Remotes.EnterArena.OnServerEvent:Connect(enterArena)

Remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
	if not hubPlayers[player] then
		return
	end
	if zoneId == "ArenaPortal" then
		enterArena(player)
	elseif zoneId == "StatsKiosk" or zoneId == "Leaderboard" then
		sendLobbyReady(player)
	end
end)

return {
	refreshLobby = refreshAllLobbyClients,
	returnToHub = function(player)
		hubPlayers[player] = true
		player:SetAttribute("NovaBladers_InHub", true)
		player:SetAttribute("NovaBladers_InArena", false)
		teleportToHub(player)
		sendLobbyReady(player)
		refreshAllLobbyClients()
	end,
}
