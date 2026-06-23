local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local zoneParts
local leaderboardBoard
local playersInHub = {}
local playerZones = {}
local zoneCheckAccumulator = 0

local function getArenaSpawnCFrame()
	local current = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		current = current and current:FindFirstChild(name)
	end
	if current and current:IsA("BasePart") then
		return current.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 10, 0)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function updateLeaderboardBoard()
	if not leaderboardBoard then
		return
	end
	local gui = leaderboardBoard:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("List")
	if not list then
		return
	end

	local entries = LeaderboardManager.getTop(5)
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

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function isInsideZone(position, zonePart, zoneConfig)
	local offset = position - zonePart.Position
	local half = zoneConfig.size * 0.5
	return math.abs(offset.X) <= half.X + 2
		and math.abs(offset.Y) <= 8
		and math.abs(offset.Z) <= half.Z + 2
end

local function detectZone(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	for zoneId, zoneConfig in HubConfig.ZONES do
		local zonePart = zoneParts[zoneId]
		if zonePart and isInsideZone(root.Position, zonePart, zoneConfig) then
			return zoneId, zoneConfig
		end
	end
	return nil
end

local function sendZoneHint(player, zoneId, zoneConfig)
	if zoneId then
		remotes.HubZoneHint:FireClient(player, {
			zoneId = zoneId,
			name = zoneConfig.name,
			hint = zoneConfig.hint,
			action = zoneConfig.action,
		})
	else
		remotes.HubZoneHint:FireClient(player, { zoneId = nil })
	end
end

local function refreshPlayerZone(player)
	if not playersInHub[player] then
		return
	end

	local zoneId, zoneConfig = detectZone(player)
	if playerZones[player] ~= zoneId then
		playerZones[player] = zoneId
		sendZoneHint(player, zoneId, zoneConfig)
	end
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	playerZones[player] = nil
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	task.defer(refreshPlayerZone, player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	playerZones[player] = nil
	updateLeaderboardBoard()
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	task.defer(refreshPlayerZone, player)
end

function HubWorldManager.leaveHub(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, { zoneId = nil })
end

local function handleEnterArena(player)
	if not playersInHub[player] then
		return
	end
	HubWorldManager.leaveHub(player)
	teleportCharacter(player, getArenaSpawnCFrame())
end

local function handleZoneAction(player, zoneId)
	if not playersInHub[player] then
		return
	end

	local zoneConfig = HubConfig.ZONES[zoneId]
	if not zoneConfig then
		return
	end

	if zoneConfig.action == "enterArena" then
		handleEnterArena(player)
	elseif zoneConfig.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneConfig.action == "viewLeaderboard" then
		updateLeaderboardBoard()
	end
end

local function onCharacterAdded(player, character)
	if not playersInHub[player] then
		return
	end
	task.wait(0.1)
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	task.defer(refreshPlayerZone, player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	hubFolder, zoneParts, leaderboardBoard = HubWorldBuilder.build()
	updateLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(handleEnterArena)
	remotes.HubZoneAction.OnServerEvent:Connect(handleZoneAction)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
		HubWorldManager.spawnInHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		HubWorldManager.spawnInHub(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		zoneCheckAccumulator += dt
		if zoneCheckAccumulator < HubConfig.ZONE_CHECK_INTERVAL then
			return
		end
		zoneCheckAccumulator = 0
		for player in playersInHub do
			refreshPlayerZone(player)
		end
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
