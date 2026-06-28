local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubManager = {}

local playerZones = {}
local remotes

local function ensureRemotes()
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

	local function remote(name, className)
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = folder
		return inst
	end

	return {
		LobbyReady = remote("LobbyReady", "RemoteEvent"),
		EnterArena = remote("EnterArena", "RemoteEvent"),
		ReturnToHub = remote("ReturnToHub", "RemoteEvent"),
		HubZoneHighlight = remote("HubZoneHighlight", "RemoteEvent"),
	}
end

local function getCharacterPosition(player)
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position
end

local function detectZone(position)
	if not position then
		return nil
	end

	local hubOrigin = HubConfig.HUB_ORIGIN
	local localPos = position - hubOrigin
	local flat = Vector3.new(localPos.X, 0, localPos.Z)

	for zoneId, zone in HubConfig.ZONES do
		local offset = zone.position
		local delta = flat - Vector3.new(offset.X, 0, offset.Z)
		if delta.Magnitude <= zone.radius then
			return zoneId
		end
	end

	return nil
end

local function buildLobbyPayload(player, zoneId)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local zone = zoneId and HubConfig.ZONES[zoneId]

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = zone and zone.modeLabel or "Modus: Training (Zentrum)",
		zoneId = zoneId,
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	root.CFrame = CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

function HubManager.sendLobby(player, zoneId)
	zoneId = zoneId or playerZones[player]
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, zoneId))
end

function HubManager.getPlayerZone(player)
	return playerZones[player]
end

function HubManager.setPlayerZone(player, zoneId)
	playerZones[player] = zoneId
	remotes.HubZoneHighlight:FireClient(player, zoneId)
	HubManager.sendLobby(player, zoneId)
end

local function onEnterArena(player)
	local zoneId = playerZones[player] or "Training"
	local zone = HubConfig.ZONES[zoneId] or HubConfig.ZONES.Training

	local playerCount = #Players:GetPlayers()
	if playerCount < zone.minPlayers and zoneId ~= "Training" then
		local payload = buildLobbyPayload(player, zoneId)
		payload.modeLabel = string.format(
			"%s — braucht %d+ Spieler (%d online)",
			zone.modeLabel,
			zone.minPlayers,
			playerCount
		)
		remotes.LobbyReady:FireClient(player, payload)
		return
	end

	-- GameManager im Place übernimmt Teleport + Match-Start;
	-- ZoneId wird als Attribut gesetzt für die Arena-Logik.
	player:SetAttribute("SelectedMode", zoneId)

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(HubConfig.ARENA_ORIGIN + Vector3.new(0, 4, 0))
		end
	end
end

local function bindPrompts(hubFolder)
	local zonesFolder = hubFolder:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end

	for _, disc in zonesFolder:GetChildren() do
		local prompt = disc:FindFirstChild("EnterPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				local zoneId = prompt:GetAttribute("ZoneId") or disc:GetAttribute("ZoneId")
				if zoneId then
					HubManager.setPlayerZone(player, zoneId)
				end
				onEnterArena(player)
			end)
		end
	end
end

local function startZoneWatcher()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local zoneId = detectZone(getCharacterPosition(player))
				if playerZones[player] ~= zoneId then
					HubManager.setPlayerZone(player, zoneId)
				end
			end
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
		end
	end)
end

function HubManager.init()
	remotes = ensureRemotes()
	HubWorldBuilder.build()
	bindPrompts(HubWorldBuilder.getFolder())
	startZoneWatcher()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubManager.teleportToHub(player)
		HubManager.sendLobby(player, playerZones[player])
	end)

	Players.PlayerAdded:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.load(player)

		player.CharacterAdded:Connect(function()
			task.defer(function()
				HubManager.teleportToHub(player)
				HubManager.sendLobby(player, nil)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubManager.teleportToHub(player)
		HubManager.sendLobby(player, nil)
	end
end

return HubManager
