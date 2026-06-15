local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local Remotes = NovaBladers:WaitForChild("Remotes")
local LobbyReady = Remotes:WaitForChild("LobbyReady")
local EnterArena = Remotes:WaitForChild("EnterArena")

local hubState = {}
local hubFolder

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

local function updateLeaderboardSurface(leaderboard)
	if not hubFolder then return end
	local hall = hubFolder:FindFirstChild("Zones")
		and hubFolder.Zones:FindFirstChild("HallOfFame")
	if not hall then return end
	local pillar = hall:FindFirstChild("LeaderboardPillar")
	if not pillar then return end
	local surface = pillar:FindFirstChild("LeaderboardSurface")
	if not surface then return end
	local label = surface:FindFirstChild("LeaderboardLabel")
	if not label then return end

	local lines = {"🏆 Top Spieler:"}
	for _, entry in leaderboard do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

local function broadcastLobbyReady()
	local leaderboard = LeaderboardManager.getTop(5)
	updateLeaderboardSurface(leaderboard)

	for _, activePlayer in Players:GetPlayers() do
		if hubState[activePlayer] == "hub" then
			local personal = buildLobbyPayload(activePlayer)
			personal.leaderboard = leaderboard
			LobbyReady:FireClient(activePlayer, personal)
		end
	end
end

local function bindArenaPrompt()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end
	local gate = zones:FindFirstChild("ArenaGate")
	if not gate then return end
	local portal = gate:FindFirstChild("Portal")
	if not portal then return end
	local prompt = portal:FindFirstChild("EnterArenaPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(triggerPlayer)
		enterArena(triggerPlayer)
	end)
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.ARENA_SPAWN)
end

local function setHubMovement(player, enabled)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
		humanoid.JumpPower = enabled and 50 or 0
	end
end

local function enterHub(player)
	hubState[player] = "hub"
	setHubMovement(player, true)
	teleportToHub(player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function enterArena(player)
	if hubState[player] ~= "hub" then return end
	hubState[player] = "arena"
	setHubMovement(player, true)
	teleportToArena(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if hubState[player] == "arena" then
			teleportToArena(player)
			setHubMovement(player, true)
		else
			enterHub(player)
		end
	end)

	if player.Character then
		enterHub(player)
	end
end

local function onPlayerRemoving(player)
	hubState[player] = nil
	PlayerDataManager.save(player)
	broadcastLobbyReady()
end

hubFolder = HubWorldBuilder.build()
bindArenaPrompt()

EnterArena.OnServerEvent:Connect(function(player)
	enterArena(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(function()
	task.defer(broadcastLobbyReady)
end)

Players.PlayerRemoving:Connect(function()
	task.defer(broadcastLobbyReady)
end)

return {
	enterHub = enterHub,
	enterArena = enterArena,
	returnToHub = function(player)
		enterHub(player)
		broadcastLobbyReady()
	end,
}
