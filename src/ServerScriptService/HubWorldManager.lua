local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubFolder
local leaderboardBoard
local zoneStates = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
		local bowl = arena:FindFirstChild("Bowl")
		if bowl and bowl:IsA("BasePart") then
			return bowl
		end
	end
	return nil
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe + Vector3.new(0, 3, 0)
	end
end

function HubWorldManager.getRemotes()
	return remotes
end

function HubWorldManager.buildHub()
	hubFolder = HubWorldBuilder.build()
	leaderboardBoard = hubFolder:FindFirstChild("LeaderboardBoard")
	return hubFolder
end

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(5)
	if leaderboardBoard then
		HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, entries)
	end
	return entries
end

function HubWorldManager.sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = HubWorldManager.refreshLeaderboard()

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub == true,
	})
end

function HubWorldManager.spawnInHub(player)
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	local cframe = spawn and spawn.CFrame or CFrame.new(HubConfig.SPAWN)
	teleportCharacter(player, cframe)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	local spawn = findArenaSpawn()
	if spawn then
		teleportCharacter(player, spawn.CFrame)
	else
		warn("[NovaBladers] Kein Arena-Spawn gefunden — HubSpawn als Fallback.")
		HubWorldManager.spawnInHub(player)
		return
	end

	remotes.LobbyReady:FireClient(player, {
		wins = PlayerDataManager.get(player).Wins,
		losses = PlayerDataManager.get(player).Losses,
		rank = PlayerDataManager.getRankPoints(PlayerDataManager.get(player)),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = false,
	})
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function playerInZone(player, zonePart)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local localPos = zonePart.CFrame:PointToObjectSpace(root.Position)
	local half = zonePart.Size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y + 4
		and math.abs(localPos.Z) <= half.Z
end

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

function HubWorldManager.handleZoneAction(player, zoneId)
	local zone = getZoneConfig(zoneId)
	if not zone then return end

	if zone.action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "OpenBeySelect" then
		HubWorldManager.openBeySelect(player)
	elseif zone.action == "ShowLeaderboard" then
		HubWorldManager.refreshLeaderboard()
		HubWorldManager.sendLobbyReady(player, true)
	end
end

function HubWorldManager.pollZones()
	if not hubFolder then return end
	local zonesFolder = hubFolder:FindFirstChild("Zones")
	if not zonesFolder then return end

	for _, player in Players:GetPlayers() do
		local foundZone = nil
		for _, zonePart in zonesFolder:GetChildren() do
			if zonePart:IsA("BasePart") and playerInZone(player, zonePart) then
				foundZone = zonePart:GetAttribute("ZoneId")
				break
			end
		end

		local prev = zoneStates[player]
		if foundZone ~= prev then
			zoneStates[player] = foundZone
			if foundZone then
				local cfg = getZoneConfig(foundZone)
				if cfg then
					remotes.HubZoneHint:FireClient(player, {
						zoneId = foundZone,
						name = cfg.name,
						hint = cfg.hint,
						action = cfg.action,
					})
					HubWorldManager.handleZoneAction(player, foundZone)
				end
			else
				remotes.HubZoneHint:FireClient(player, nil)
			end
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildHub()

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			HubWorldManager.spawnInHub(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		zoneStates[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	task.spawn(function()
		while true do
			HubWorldManager.pollZones()
			task.wait(0.25)
		end
	end)
end

return HubWorldManager
