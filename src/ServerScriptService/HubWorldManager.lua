local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubModel
local playersInHub = {}
local playerZone = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
		local fallback = arena:FindFirstChild("Spawn", true)
		if fallback and fallback:IsA("BasePart") then
			return fallback.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 10, 0)
end

local function updateLeaderboardBoard()
	if not hubModel then return end
	local board = hubModel:FindFirstChild("LeaderboardBoard", true)
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP),
		inHub = inHub,
	}
end

local function sendLobbyReady(player, inHub)
	playersInHub[player] = inHub or false
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
	playersInHub[player] = true
	playerZone[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
end

local function getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local delta = position - zone.center
		if math.abs(delta.X) <= half.X and math.abs(delta.Y) <= half.Y + 4 and math.abs(delta.Z) <= half.Z then
			return zone
		end
	end
	return nil
end

local function setPlayerZone(player, zone)
	local previous = playerZone[player]
	local zoneId = zone and zone.id or nil
	if previous == zoneId then return end
	playerZone[player] = zoneId

	if zone then
		remotes.HubZoneHint:FireClient(player, {
			zoneId = zone.id,
			name = zone.name,
			hint = zone.hint,
			action = zone.action,
		})
	else
		remotes.HubZoneHint:FireClient(player, nil)
	end
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build(LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP))
end

function HubWorldManager.onPlayerReady(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	teleportToHub(player)
	sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player, true)
	updateLeaderboardBoard()
end

function HubWorldManager.enterArena(player)
	if not playersInHub[player] then return end
	playersInHub[player] = false
	playerZone[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = findArenaSpawn()
		end
	end

	sendLobbyReady(player, false)
end

function HubWorldManager.openBeySelect(player)
	if not playersInHub[player] then return end
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if not playersInHub[player] then return end
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		HubWorldManager.openBeySelect(player)
	end
end

function HubWorldManager.tickZones()
	for _, player in Players:GetPlayers() do
		if not playersInHub[player] then continue end
		local character = player.Character
		if not character then continue end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		setPlayerZone(player, getZoneAtPosition(root.Position))
	end
end

function HubWorldManager.refreshLeaderboard()
	updateLeaderboardBoard()
end

return HubWorldManager
