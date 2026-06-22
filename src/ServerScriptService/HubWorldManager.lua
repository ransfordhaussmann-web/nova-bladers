local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playersInHub = {}
local playerZones = {}

local function getArenaSpawnCFrame()
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
	return CFrame.new(0, 5, 0)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size * 0.5
		local delta = position - zone.center
		if math.abs(delta.X) <= half.X
			and math.abs(delta.Y) <= half.Y + 4
			and math.abs(delta.Z) <= half.Z then
			return zone
		end
	end
	return nil
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()
	local modeLabel
	if playerCount <= 1 then
		modeLabel = "Modus: Training"
	elseif playerCount == 2 then
		modeLabel = "Modus: 1v1 PvP"
	else
		modeLabel = string.format("Modus: FFA (%d Spieler)", playerCount)
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	playersInHub[player] = true
	playerZones[player] = nil
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	playerZones[player] = nil
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.teleportToArena(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
	teleportCharacter(player, getArenaSpawnCFrame())
end

local function handleZoneAction(player, action)
	if not playersInHub[player] then return end

	if action == "enterArena" then
		HubWorldManager.teleportToArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "viewLeaderboard" then
		-- 3D board is already visible; refresh client hint
		remotes.HubZoneHint:FireClient(player, {
			zoneId = "HallOfFame",
			label = HubConfig.ZONES.HallOfFame.label,
			hint = "Schau zum Leaderboard-Board",
		})
	end
end

local function updatePlayerZone(player)
	if not playersInHub[player] then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zone = getZoneAtPosition(root.Position)
	local previous = playerZones[player]

	if zone then
		if not previous or previous.id ~= zone.id then
			playerZones[player] = zone
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zone.id,
				label = zone.label,
				hint = zone.hint,
				action = zone.action,
			})
		end
	else
		if previous then
			playerZones[player] = nil
			remotes.HubZoneHint:FireClient(player, nil)
		end
	end
end

function HubWorldManager.init(remotesFolder, builtHub)
	remotes = remotesFolder
	hubFolder = builtHub

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			HubWorldManager.teleportToArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			handleZoneAction(player, action)
		end
	end)

	local lastCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastCheck < HubConfig.ZONE_CHECK_INTERVAL then return end
		lastCheck = now

		for _, player in Players:GetPlayers() do
			updatePlayerZone(player)
		end
	end)
end

function HubWorldManager.onPlayerReady(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	playersInHub[player] = true
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubFolder then return end
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
end

return HubWorldManager
