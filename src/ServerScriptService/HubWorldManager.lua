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
local playersInHub = {}
local playerZones = {}

local function getModeLabel(playerCount: number): string
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawnCFrame(): CFrame?
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, 5, 0)
	end

	return nil
end

local function teleportCharacter(player: Player, targetCFrame: CFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame
end

local function buildLobbyPayload(player: Player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player: Player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	if hubFolder then
		HubWorldBuilder.createLeaderboardBoard(hubFolder, entries)
	end
end

function HubWorldManager.returnToHub(player: Player)
	playersInHub[player] = true
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

local function enterArena(player: Player)
	local arenaSpawn = findArenaSpawnCFrame()
	if not arenaSpawn then
		warn("[NovaBladers] Kein Arena-Spawn gefunden (Arena.Spawn / Bowl)")
		return
	end

	playersInHub[player] = false
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
	teleportCharacter(player, arenaSpawn)
end

local function handleZoneAction(player: Player, zoneId: string)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enter_arena" then
		enterArena(player)
	elseif zone.action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "view_leaderboard" then
		HubWorldManager.refreshLeaderboardBoard()
		HubWorldManager.sendLobbyReady(player)
	end
end

local function getNearestZone(position: Vector3)
	local nearestId = nil
	local nearestDist = HubConfig.PROXIMITY_RADIUS

	for zoneId, zone in HubConfig.ZONES do
		local dist = (position - zone.position).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestId = zoneId
		end
	end

	return nearestId
end

local function updatePlayerZone(player: Player)
	if not playersInHub[player] then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zoneId = getNearestZone(root.Position)
	local previous = playerZones[player]

	if zoneId ~= previous then
		playerZones[player] = zoneId
		if zoneId then
			local zone = HubConfig.ZONES[zoneId]
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zoneId,
				name = zone.name,
				hint = zone.hint,
				actionLabel = zone.actionLabel,
			})
		else
			remotes.HubZoneHint:FireClient(player, nil)
		end
	end
end

function HubWorldManager.onPlayerAdded(player: Player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	playersInHub[player] = true

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playersInHub[player] then
			teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
			HubWorldManager.sendLobbyReady(player)
		end
	end)

	if player.Character then
		teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
	end

	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onPlayerRemoving(player: Player)
	PlayerDataManager.save(player)
	playersInHub[player] = nil
	playerZones[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(enterArena)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		if playerZones[player] ~= zoneId then return end
		handleZoneAction(player, zoneId)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			updatePlayerZone(player)
		end
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
