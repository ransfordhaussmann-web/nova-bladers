local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
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
local HubState = ensureRemote("HubState", "RemoteEvent")

local hub = HubWorldBuilder.build()
local playersInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function updateWorldBoards(payload)
	local statsZone = HubWorldBuilder.getZone(hub, "StatsTerminal")
	if statsZone then
		local gui = statsZone:FindFirstChild("Label", true)
		local label = gui and gui:FindFirstChild("StatsLabel")
		if label then
			label.Text = string.format(
				"Deine Stats\nWins: %d  Losses: %d\nRank: %d",
				payload.wins,
				payload.losses,
				payload.rank
			)
		end
	end

	local boardZone = HubWorldBuilder.getZone(hub, "Leaderboard")
	if boardZone then
		local gui = boardZone:FindFirstChild("Label", true)
		local label = gui and gui:FindFirstChild("LeaderboardLabel")
		if label and payload.leaderboard then
			local lines = { "Top Spieler" }
			for _, entry in payload.leaderboard do
				table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
			end
			if #payload.leaderboard == 0 then
				table.insert(lines, "Noch keine Einträge")
			end
			label.Text = table.concat(lines, "\n")
		end
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local rank = 0
	local ok, pages = pcall(function()
		return game:GetService("DataStoreService")
			:GetOrderedDataStore("NovaBladers_GlobalRank_v1")
			:GetSortedAsync(false, 100)
	end)
	if ok and pages then
		for i, item in pages:GetCurrentPage() do
			if tonumber(item.key) == player.UserId then
				rank = i
				break
			end
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function sendToHub(player)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(hub.HubSpawn.Position + Vector3.new(0, 3, 0))
		end
	end
	player:SetAttribute("InHub", true)
	playersInHub[player] = true
end

local function enterArena(player)
	if not playersInHub[player] then
		return
	end
	playersInHub[player] = nil
	player:SetAttribute("InHub", false)
	EnterArena:FireClient(player)
end

local function onPlayerReady(player)
	local payload = buildLobbyPayload(player)
	updateWorldBoards(payload)
	LobbyReady:FireClient(player, payload)
	HubState:FireClient(player, { state = "hub", modeLabel = payload.modeLabel })
	sendToHub(player)
end

local function hookPortalPrompt()
	local portal = HubWorldBuilder.getZone(hub, "ArenaPortal")
	if not portal then return end
	local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(player)
		enterArena(player)
	end)
end

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		if playersInHub[player] ~= false and player:GetAttribute("InHub") ~= false then
			task.defer(function()
				onPlayerReady(player)
			end)
		end
	end)
	if player.Character then
		onPlayerReady(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end)

EnterArena.OnServerEvent:Connect(function(player)
	enterArena(player)
end)

hookPortalPrompt()

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
	onPlayerReady(player)
end
