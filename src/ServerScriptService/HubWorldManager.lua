local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerZones = {}
local inArena = {}

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
	return CFrame.new(0, 5, 50)
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function isInsideZone(position, zone)
	local half = zone.size / 2
	local delta = position - zone.position
	return math.abs(delta.X) <= half.X
		and math.abs(delta.Y) <= half.Y + 4
		and math.abs(delta.Z) <= half.Z
end

local function findZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		if isInsideZone(position, zone) then
			return zone
		end
	end
	return nil
end

local function sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
	})
end

function HubWorldManager.refreshLeaderboardBoard()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then
		return
	end
	HubWorldBuilder.buildLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = HubConfig.SPAWN_CFRAME
	end
	sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	inArena[player] = true
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = getArenaSpawnCFrame()
	end
end

local function handleZoneAction(player, zoneId)
	if inArena[player] then
		return
	end

	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		return
	end

	if zone.action == "EnterArena" then
		HubWorldManager.teleportToArena(player)
	elseif zone.action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "ViewLeaderboard" then
		sendLobbyReady(player, true)
	end
end

local function updatePlayerZone(player)
	if inArena[player] then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local zone = findZoneAtPosition(hrp.Position)
	local previous = playerZones[player]

	if zone then
		if not previous or previous.id ~= zone.id then
			playerZones[player] = zone
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zone.id,
				name = zone.name,
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

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboardBoard()

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				HubWorldManager.spawnInHub(player)
			end
		end)

		if player.Character then
			task.defer(function()
				HubWorldManager.spawnInHub(player)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
		inArena[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				updatePlayerZone(player)
			end
			task.wait(0.25)
		end
	end)
end

return HubWorldManager
