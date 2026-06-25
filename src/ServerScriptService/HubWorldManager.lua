local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local remotes = RemotesSetup.ensure(NovaBladers)

local playerZones = {}
local playerInArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
		inArena = playerInArena[player] == true,
	}
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function getZoneAtPosition(position)
	local bestZone = nil
	local bestDist = HubConfig.INTERACT_RADIUS

	for _, zone in HubConfig.ZONES do
		local flat = Vector3.new(position.X, 0, position.Z)
		local zoneFlat = Vector3.new(zone.position.X, 0, zone.position.Z)
		local dist = (flat - zoneFlat).Magnitude
		if dist <= bestDist then
			bestDist = dist
			bestZone = zone
		end
	end

	return bestZone
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION + Vector3.new(0, 2, 0))
	playerInArena[player] = false
	sendLobbyReady(player, true)
end

local function enterArena(player)
	playerInArena[player] = true
	sendLobbyReady(player, false)
	local hook = _G.NovaBladersOnEnterArena
	if typeof(hook) == "function" then
		hook(player)
	end
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function showLeaderboard(player)
	local payload = buildLobbyPayload(player, true)
	local lines = {"🏆 Top Spieler:"}
	for _, entry in payload.leaderboard do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	remotes.HubZoneHint:FireClient(player, {
		zoneName = "Ruhmeshalle",
		hint = table.concat(lines, "\n"),
		persistent = true,
	})
end

local function handleZoneAction(player, zone)
	if not zone then return end
	if zone.action == "enter_arena" then
		enterArena(player)
	elseif zone.action == "open_bey_select" then
		openBeySelect(player)
	elseif zone.action == "show_leaderboard" then
		showLeaderboard(player)
	end
end

local function updatePlayerZone(player)
	if playerInArena[player] then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zone = getZoneAtPosition(root.Position)
	local prev = playerZones[player]

	if zone then
		if not prev or prev.id ~= zone.id then
			playerZones[player] = zone
			remotes.HubZoneHint:FireClient(player, {
				zoneName = zone.name,
				hint = zone.hint,
				persistent = false,
			})
		end
	else
		if prev then
			playerZones[player] = nil
			remotes.HubZoneHint:FireClient(player, {
				zoneName = nil,
				hint = nil,
				persistent = false,
			})
		end
	end
end

local HubWorldManager = {}

function HubWorldManager.init()
	HubWorldBuilder.build(workspace)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		playerInArena[player] = false
		playerZones[player] = nil

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not playerInArena[player] then
					teleportToHub(player)
				end
			end)
		end)

		task.defer(function()
			sendLobbyReady(player, true)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
		playerInArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		playerInArena[player] = false
		sendLobbyReady(player, true)
	end

	remotes.HubInteract.OnServerEvent:Connect(function(player)
		if playerInArena[player] then return end
		local zone = playerZones[player]
		if not zone then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				zone = getZoneAtPosition(root.Position)
			end
		end
		handleZoneAction(player, zone)
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			updatePlayerZone(player)
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		teleportToHub(player)
	end
	_G.NovaBladersEnterArena = enterArena
end

return HubWorldManager
