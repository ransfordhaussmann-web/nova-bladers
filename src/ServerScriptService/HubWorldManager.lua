local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("HubConfig"))
local HubWorldBuilder = require(ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("HubWorldBuilder"))
local RemotesSetup = require(ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("RemotesSetup"))
local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
local LeaderboardManager = require(script.Parent:WaitForChild("LeaderboardManager"))

local HubWorldManager = {}

local remotes
local hubModel
local playersInArena = {}
local modeLabel = "Modus: Training"

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = folder:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
		end
	end

	local fallback = workspace:FindFirstChild("ArenaSpawn") or workspace:FindFirstChild("BowlSpawn")
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end
	return nil
end

local function updateLeaderboardBoard(entries)
	if not hubModel then return end
	local hall = hubModel:FindFirstChild("Zones") and hubModel.Zones:FindFirstChild("HallOfFame")
	if not hall then return end
	local board = hall:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChild("LeaderboardGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = leaderboard,
		inHub = true,
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPart = hubModel and hubModel:FindFirstChild("HubSpawn")
	local position = spawnPart and spawnPart.Position or HubConfig.SPAWN_POSITION
	root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	playersInArena[player] = nil
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPart = findArenaSpawn()
	if spawnPart then
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 10, 80)
	end
	playersInArena[player] = true
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function refreshAllPlayers()
	modeLabel = getModeLabel()
	local leaderboard = LeaderboardManager.getTop(5)
	updateLeaderboardBoard(leaderboard)

	for _, player in Players:GetPlayers() do
		if not playersInArena[player] then
			sendLobbyReady(player)
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if playersInArena[player] then
				teleportToArena(player)
			else
				teleportToHub(player)
				sendLobbyReady(player)
			end
		end)

		refreshAllPlayers()
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playersInArena[player] = nil
		refreshAllPlayers()
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	for _, zone in hubModel.Zones:GetChildren() do
		local prompt = zone:FindFirstChild("ZonePrompt", true)
		if not prompt then continue end

		prompt.Triggered:Connect(function(player)
			if zone.Name == "ArenaGate" then
				teleportToArena(player)
			elseif zone.Name == "BeyLab" then
				remotes.OpenBeySelect:FireClient(player)
			elseif zone.Name == "HallOfFame" then
				remotes.HubZoneAction:FireClient(player, {
					zoneId = zone.Name,
					leaderboard = LeaderboardManager.getTop(5),
				})
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
	end
	refreshAllPlayers()
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player)
	refreshAllPlayers()
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

return HubWorldManager
