local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubManager = {}

local hubRoot
local statsLabel
local leaderboardLabel
local remotes
local playersInHub = {}

local function getRemotes()
	local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not nova then
		nova = Instance.new("Folder")
		nova.Name = "NovaBladers"
		nova.Parent = ReplicatedStorage
	end
	local folder = nova:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = nova
	end

	local function ensureRemote(name, className)
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	end

	return {
		LobbyReady = ensureRemote("LobbyReady", "RemoteEvent"),
		EnterArena = ensureRemote("EnterArena", "RemoteEvent"),
		HubZoneUpdate = ensureRemote("HubZoneUpdate", "RemoteEvent"),
		HubInteract = ensureRemote("HubInteract", "RemoteEvent"),
	}
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

local function formatLeaderboard(entries)
	local lines = {"Top Spieler:"}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Eintraege")
	end
	return table.concat(lines, "\n")
end

local function updateWorldBoard(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local rank = 0
	for i, p in Players:GetPlayers() do
		if p == player then
			rank = i
			break
		end
	end

	local statsText = string.format(
		"%s\nWins: %d\nLosses: %d\nRank-Punkte: %d",
		player.DisplayName,
		data.Wins,
		data.Losses,
		rankPoints
	)

	if statsLabel then
		statsLabel.Text = statsText
	end

	local top = LeaderboardManager.getTop(5)
	if leaderboardLabel then
		leaderboardLabel.Text = formatLeaderboard(top)
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	hrp.CFrame = CFrame.new(HubConfig.SPAWN + Vector3.new(0, 2, 0))
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
	playersInHub[player] = true
end

function HubManager.sendLobbyReady(player)
	local payload = buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	updateWorldBoard(player)
end

function HubManager.isInHub(player)
	return playersInHub[player] == true
end

function HubManager.leaveHub(player)
	playersInHub[player] = nil
end

function HubManager.getPlayerZone(player)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local pos = hrp.Position
	for _, zone in HubConfig.ZONES do
		local flat = Vector3.new(pos.X, zone.position.Y, pos.Z)
		local zoneFlat = Vector3.new(zone.position.X, zone.position.Y, zone.position.Z)
		if (flat - zoneFlat).Magnitude <= zone.radius then
			return zone
		end
	end
	return nil
end

function HubManager.setupPlayer(player)
	PlayerDataManager.load(player)

	local function onCharacterAdded(character)
		task.wait(0.1)
		HubManager.teleportToHub(player)
		HubManager.sendLobbyReady(player)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

function HubManager.setup()
	remotes = getRemotes()
	local refs
	hubRoot, refs = HubWorldBuilder.build()
	statsLabel = refs.statsLabel
	leaderboardLabel = refs.leaderboardLabel

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not HubManager.isInHub(player) then return end
		HubManager.leaveHub(player)
		-- GameManager handles arena transition when present in Studio
		player:SetAttribute("NovaBladers_EnterArena", true)
	end)

	remotes.HubInteract.OnServerEvent:Connect(function(player, zoneId)
		if not HubManager.isInHub(player) then return end
		local zone = HubConfig.ZONES[zoneId]
		if not zone then return end
		local current = HubManager.getPlayerZone(player)
		if not current or current.id ~= zone.id then return end

		if zoneId == "ArenaGate" then
			HubManager.leaveHub(player)
			player:SetAttribute("NovaBladers_EnterArena", true)
			remotes.EnterArena:FireClient(player)
		elseif zoneId == "StatsBoard" then
			player:SetAttribute("NovaBladers_ShowStatsPanel", true)
			HubManager.sendLobbyReady(player)
		elseif zoneId == "BeyTerminal" then
			player:SetAttribute("NovaBladers_OpenBeySelect", true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)
end

function HubManager.getHubRoot()
	return hubRoot
end

function HubManager.getRemotes()
	return remotes
end

return HubManager
