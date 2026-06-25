local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playersInArena = {}
local playersInHub = {}

local function getZoneById(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
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

local function buildLobbyPayload(player, opts)
	opts = opts or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = opts.inHub == true,
		inArena = opts.inArena == true,
	}
end

local function sendLobbyReady(player, opts)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, opts))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	playersInArena[player] = nil
	playersInHub[player] = true
	sendLobbyReady(player, { inHub = true })
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	local spawnPos = HubConfig.ARENA_SPAWN
	if arena then
		local arenaSpawn = arena:FindFirstChild("Spawn", true)
		if arenaSpawn and arenaSpawn:IsA("BasePart") then
			spawnPos = arenaSpawn.Position + Vector3.new(0, 3, 0)
		end
	end

	hrp.CFrame = CFrame.new(spawnPos)
	playersInHub[player] = nil
	playersInArena[player] = true
	sendLobbyReady(player, { inArena = true })
end

local function handleZoneAction(player, zoneId)
	local zone = getZoneById(zoneId)
	if not zone then return end

	if zone.action == "enterArena" then
		teleportToArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showLobby" then
		sendLobbyReady(player, { inHub = true, showPanel = true })
	end
end

local function getNearestZone(position)
	local nearest, nearestDist = nil, HubConfig.INTERACT_RANGE
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist < nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end
	return nearest
end

local function onCharacterAdded(player, character)
	task.wait(0.1)
	if playersInArena[player] then
		teleportToArena(player)
	else
		teleportToHub(player)
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build(workspace)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInArena[player] then return end
		teleportToArena(player)
	end)

	remotes.HubInteract.OnServerEvent:Connect(function(player, zoneId)
		if playersInArena[player] then return end
		if typeof(zoneId) ~= "string" then return end

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local zone = getZoneById(zoneId)
		if not zone then return end
		local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist > HubConfig.INTERACT_RANGE then return end

		handleZoneAction(player, zoneId)
	end)

	local function onPlayerAdded(player)
		playersInHub[player] = true
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		playersInArena[player] = nil
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			if playersInArena[player] then continue end
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end

			local zone = getNearestZone(hrp.Position)
			if zone then
				remotes.HubZoneHint:FireClient(player, {
					zoneId = zone.id,
					name = zone.name,
					hint = zone.hint,
					active = true,
				})
			else
				remotes.HubZoneHint:FireClient(player, { active = false })
			end
		end
	end)
end

return HubWorldManager
