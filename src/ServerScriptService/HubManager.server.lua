local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubBuilder = require(NovaBladers.HubBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")
local LobbyReady = Remotes:WaitForChild("LobbyReady")
local EnterArena = Remotes:WaitForChild("EnterArena")

local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function formatLeaderboard(entries)
	local lines = { "Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function getHubSpawnCFrame()
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
end

local function teleportToHub(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = getHubSpawnCFrame()
	end
end

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ORIGIN + Vector3.new(0, 3, 80))
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local lobbyPlayers = 0
	for _, p in Players:GetPlayers() do
		if not inArena[p] then
			lobbyPlayers += 1
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(lobbyPlayers),
		leaderboard = leaderboard,
		leaderboardText = formatLeaderboard(leaderboard),
		use3DHub = true,
	}
end

local function updateHubDisplays()
	local label = HubBuilder.getLeaderboardLabel()
	if label then
		label.Text = formatLeaderboard(LeaderboardManager.getTop(5))
	end
end

local function sendLobbyReady(player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	inArena[player] = false

	player.CharacterAdded:Connect(function(character)
		if inArena[player] then
			return
		end
		task.defer(function()
			teleportToHub(character)
		end)
	end)

	if player.Character then
		teleportToHub(player.Character)
	end

	sendLobbyReady(player)
end

local function onEnterArena(player)
	if inArena[player] then
		return
	end

	inArena[player] = true
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = getArenaSpawnCFrame()
		end
	end

	for _, p in Players:GetPlayers() do
		if not inArena[p] then
			sendLobbyReady(p)
		end
	end
end

local function onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

HubBuilder.ensureBuilt()
updateHubDisplays()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
EnterArena.OnServerEvent:Connect(onEnterArena)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(HubConfig.LEADERBOARD_REFRESH)
		updateHubDisplays()
	end
end)

return {
	sendLobbyReady = sendLobbyReady,
	returnToHub = function(player)
		inArena[player] = false
		local character = player.Character
		if character then
			teleportToHub(character)
		end
		sendLobbyReady(player)
	end,
}
