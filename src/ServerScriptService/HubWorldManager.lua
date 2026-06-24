local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubData
local inHub = {}

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
		inHub = true,
	}
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(0, 10, 120)
end

local function teleportPlayer(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame
end

local function updateLeaderboardBoard()
	if not hubData or not hubData.leaderboardLabel then return end
	local entries = LeaderboardManager.getTop(5)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		hubData.leaderboardLabel.Text = "Noch keine Einträge"
	else
		hubData.leaderboardLabel.Text = table.concat(lines, "\n")
	end
end

local function sendToHub(player, refreshBoard)
	inHub[player] = true
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	if refreshBoard then
		updateLeaderboardBoard()
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	remotes.ReturnToHub:FireClient(player)
	teleportPlayer(player, HubConfig.SPAWN_CFRAME)
end

function HubWorldManager.returnToHub(player)
	if not player or not player.Parent then return end
	sendToHub(player, true)
end

local function enterArena(player)
	inHub[player] = false
	teleportPlayer(player, findArenaSpawnCFrame())
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function viewLeaderboard(player)
	updateLeaderboardBoard()
	remotes.HubZoneHint:FireClient(player, {
		zone = "halloffame",
		title = "Ruhmeshalle",
		hint = "Top 5 auf dem Board rechts",
	})
end

local ZONE_HANDLERS = {
	EnterArena = enterArena,
	OpenBeySelect = openBeySelect,
	ViewLeaderboard = viewLeaderboard,
}

local function onZoneTriggered(player, action)
	local handler = ZONE_HANDLERS[action]
	if handler then
		handler(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	inHub[player] = true

	local function onCharacter(character)
		task.defer(function()
			if inHub[player] then
				teleportPlayer(player, HubConfig.SPAWN_CFRAME)
				remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

local function onPlayerRemoving(player)
	inHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubData = HubWorldBuilder.build()

	for _, zone in hubData.zones do
		zone.prompt.Triggered:Connect(function(player)
			onZoneTriggered(player, zone.config.promptAction)
		end)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inHub[player] then
			enterArena(player)
		end
	end)

	updateLeaderboardBoard()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
