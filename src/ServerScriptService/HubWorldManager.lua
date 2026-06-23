local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local leaderboardBoard
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

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local arena = workspace:FindFirstChild(folderName)
		if arena then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = arena:FindFirstChild(spawnName)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
			if arena:IsA("BasePart") then
				return arena
			end
			local fallback = arena:FindFirstChildWhichIsA("BasePart", true)
			if fallback then
				return fallback
			end
		end
	end
	return nil
end

local function teleportCharacter(player, position, lookAt)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local cf = CFrame.new(position)
	if lookAt then
		cf = CFrame.lookAt(position, lookAt)
	end
	root.CFrame = cf
end

local function getZoneFromPart(part)
	while part and part ~= workspace do
		local zoneId = part:GetAttribute("ZoneId")
		if zoneId then
			return zoneId
		end
		part = part.Parent
	end
	return nil
end

local function detectZone(player)
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local hits = workspace:GetPartBoundsInBox(
		root.CFrame,
		Vector3.new(4, 6, 4),
		params
	)

	for _, hit in hits do
		local zoneId = getZoneFromPart(hit)
		if zoneId and HubConfig.ZONES[zoneId] then
			return zoneId
		end
	end
	return nil
end

function HubWorldManager.sendLobbyPayload(player, inHub)
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

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, entries)
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local character = player.Character
	if character then
		teleportCharacter(player, HubConfig.SPAWN_POSITION, HubConfig.ZONES.ArenaGate.position)
	end
	HubWorldManager.sendLobbyPayload(player, true)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	HubWorldManager.spawnInHub(player)
	HubWorldManager.refreshLeaderboard()
end

function HubWorldManager.enterArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden — Arena/Bowl mit Spawn-Part anlegen.")
		return
	end

	inArena[player] = true
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)

	local targetPos = spawn.Position + Vector3.new(0, 3, 0)
	teleportCharacter(player, targetPos, targetPos + Vector3.new(0, 0, -5))

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if inArena[player] then return end
	if zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.refreshLeaderboard()
	end
end

local function onCharacterAdded(player, character)
	task.wait(0.1)
	if inArena[player] then return end
	teleportCharacter(player, HubConfig.SPAWN_POSITION, HubConfig.ZONES.ArenaGate.position)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	HubWorldManager.sendLobbyPayload(player, true)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	playerZones[player] = nil
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder, leaderboardBoard = HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		HubWorldManager.handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in Players:GetPlayers() do
				if inArena[player] then continue end
				local zoneId = detectZone(player)
				if playerZones[player] ~= zoneId then
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
		end
	end)
end

return HubWorldManager
