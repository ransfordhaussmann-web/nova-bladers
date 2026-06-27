local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local HubWorldManager = {}

local playerZones = {}
local playerInArena = {}

local function getCharacterRoot(player)
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function buildLobbyPayload(player, modeLabel, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not showPanel,
	}
end

local function sendLobbyReady(player, modeLabel, showPanel)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, modeLabel, showPanel))
end

local function getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size * 0.5
		local delta = position - zone.position
		if math.abs(delta.X) <= half.X + 2 and math.abs(delta.Z) <= half.Z + 2 then
			return zone
		end
	end
	return nil
end

local function handleZoneAction(player, zone)
	if zone.action == "enterArena" then
		sendLobbyReady(player, "Modus: Arena bereit", true)
	elseif zone.action == "openBeySelect" then
		Remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showStats" then
		sendLobbyReady(player, "Modus: Ruhmeshalle", true)
	end
end

function HubWorldManager.teleportToHub(player)
	playerInArena[player] = false
	local root = getCharacterRoot(player)
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
	playerZones[player] = nil
	Remotes.HubZoneChanged:FireClient(player, { zoneId = nil })
end

function HubWorldManager.enterArena(player)
	playerInArena[player] = true
	local root = getCharacterRoot(player)
	if root then
		root.CFrame = CFrame.new(HubConfig.ARENA_SPAWN)
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	sendLobbyReady(player, "Modus: Zurück im Hub", false)
end

function HubWorldManager.init(hubModel)
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not playerInArena[player] then
					HubWorldManager.teleportToHub(player)
					sendLobbyReady(player, "Modus: Hub", false)
				end
			end)
		end)

		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
		playerInArena[player] = nil
	end)

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	local pollAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		pollAccumulator += dt
		if pollAccumulator < 0.25 then return end
		pollAccumulator = 0

		for _, player in Players:GetPlayers() do
			if playerInArena[player] then continue end
			local root = getCharacterRoot(player)
			if not root then continue end

			local zone = getZoneAtPosition(root.Position)
			local previous = playerZones[player]
			local zoneId = zone and zone.id or nil

			if zoneId ~= previous then
				playerZones[player] = zoneId
				Remotes.HubZoneChanged:FireClient(player, {
					zoneId = zoneId,
					label = zone and zone.label or nil,
				})
				if zone then
					handleZoneAction(player, zone)
				end
			end
		end
	end)

	return hubModel
end

return HubWorldManager
