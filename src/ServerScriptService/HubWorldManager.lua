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
local hubModel
local playerZones = {}
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function teleportCharacter(player, position, lookAt)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	hrp.CFrame = CFrame.new(position, lookAt or (position + Vector3.new(0, 0, -1)))
end

local function refreshLeaderboardBoard()
	if not hubModel then return end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end
	local board = zones:FindFirstChild("LeaderboardBoard")
	if not board then return end
	HubWorldBuilder.updateLeaderboardBoard(board, LeaderboardManager.getTop(5))
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local arenaPlayers = 0
	for _, p in Players:GetPlayers() do
		if inArena[p] then
			arenaPlayers += 1
		end
	end

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(math.max(arenaPlayers, 1)),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	})
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	teleportCharacter(player, HubConfig.SPAWN)
	sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function enterArena(player)
	inArena[player] = true
	local spawnPart = HubWorldBuilder.findArenaSpawn()
	local target = spawnPart and (spawnPart.Position + Vector3.new(0, 4, 0)) or (HubConfig.HUB_ORIGIN + Vector3.new(0, 4, -80))
	teleportCharacter(player, target)
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enterArena" then
		enterArena(player)
	elseif zone.action == "openBeySelect" then
		openBeySelect(player)
	elseif zone.action == "viewLeaderboard" then
		sendLobbyReady(player)
	end
end

local function bindZonePrompts()
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				local zoneId = prompt:GetAttribute("ZoneId")
				if zoneId then
					handleZoneAction(player, zoneId)
				end
			end)
		end
	end
end

local function updateZoneHints()
	for _, player in Players:GetPlayers() do
		if inArena[player] then
			playerZones[player] = nil
			continue
		end

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local nearestZone
		local nearestDist = math.huge

		for zoneId, zone in HubConfig.ZONES do
			local dist = (hrp.Position - zone.position).Magnitude
			local radius = math.max(zone.size.X, zone.size.Z) / 2 + 4
			if dist <= radius and dist < nearestDist then
				nearestDist = dist
				nearestZone = zoneId
			end
		end

		if playerZones[player] ~= nearestZone then
			playerZones[player] = nearestZone
			if nearestZone then
				local zone = HubConfig.ZONES[nearestZone]
				remotes.HubZoneHint:FireClient(player, {
					zoneId = nearestZone,
					label = zone.label,
					hint = zone.hint,
				})
			else
				remotes.HubZoneHint:FireClient(player, nil)
			end
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	hubModel = HubWorldBuilder.build()
	bindZonePrompts()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if inArena[player] then
					local spawnPart = HubWorldBuilder.findArenaSpawn()
					if spawnPart then
						teleportCharacter(player, spawnPart.Position + Vector3.new(0, 4, 0))
					end
				else
					HubWorldManager.spawnInHub(player)
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.spawnInHub(player)
	end

	RunService.Heartbeat:Connect(function()
		updateZoneHints()
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
