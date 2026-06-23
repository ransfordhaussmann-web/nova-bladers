local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local leaderboardBoard
local playerZones = {}
local zoneById = {}

for _, zone in HubConfig.ZONES do
	zoneById[zone.id] = zone
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Training"
	elseif playerCount == 2 then
		return "1v1 PvP"
	end
	return "FFA"
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn") or bowl:FindFirstChild("SpawnLocation")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
		local fallback = arena:FindFirstChild("Spawn", true)
		if fallback and fallback:IsA("BasePart") then
			return fallback.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 10, 0)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = cframe
	end
end

local function getPlayerPosition(player)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position
	end
	return nil
end

local function isInsideZone(position, zone)
	local half = zone.size * 0.5
	local offset = position - zone.position
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y - zone.size.Y * 0.5) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

local function detectZone(position)
	for _, zone in HubConfig.ZONES do
		if isInsideZone(position, zone) then
			return zone.id
		end
	end
	return nil
end

function HubWorldManager.updateLeaderboardBoard(entries)
	if not leaderboardBoard then return end
	local gui = leaderboardBoard:FindFirstChild("BoardGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

function HubWorldManager.sendLobbyReady(player)
	local deps = HubWorldManager._deps
	if not deps then return end

	local data = deps.PlayerDataManager.get(player)
	local rankPoints = deps.PlayerDataManager.getRankPoints(data)
	local leaderboard = deps.LeaderboardManager.getTop(5)

	HubWorldManager.updateLeaderboardBoard(leaderboard)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = "Modus: " .. getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	})
end

function HubWorldManager.spawnInHub(player)
	teleportPlayer(player, CFrame.new(HubConfig.SPAWN))
	playerZones[player] = nil
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function handleEnterArena(player)
	teleportPlayer(player, findArenaSpawnCFrame())
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function handleOpenBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, zoneId)
	local zone = zoneById[zoneId]
	if not zone or playerZones[player] ~= zoneId then return end

	if zone.action == "enterArena" then
		handleEnterArena(player)
	elseif zone.action == "openBeySelect" then
		handleOpenBeySelect(player)
	end
end

function HubWorldManager.init(deps)
	HubWorldManager._deps = deps
	remotes = RemotesSetup.ensure()
	local _, board = HubWorldBuilder.build()
	leaderboardBoard = board

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		handleEnterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		handleZoneAction(player, zoneId)
	end)

	local lastCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastCheck < HubConfig.ZONE_CHECK_INTERVAL then return end
		lastCheck = now

		for _, player in Players:GetPlayers() do
			local pos = getPlayerPosition(player)
			if pos then
				local zoneId = detectZone(pos)
				if playerZones[player] ~= zoneId then
					playerZones[player] = zoneId
					local zone = zoneId and zoneById[zoneId]
					remotes.HubZoneHint:FireClient(player, zone and {
						id = zone.id,
						name = zone.name,
						hint = zone.hint,
						action = zone.action,
					} or nil)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			local entries = deps.LeaderboardManager.getTop(5)
			HubWorldManager.updateLeaderboardBoard(entries)
			task.wait(HubConfig.LEADERBOARD_REFRESH)
		end
	end)
end

function HubWorldManager.onPlayerAdded(player)
	local deps = HubWorldManager._deps
	if not deps then return end

	deps.PlayerDataManager.load(player)
	local data = deps.PlayerDataManager.get(player)
	local rankPoints = deps.PlayerDataManager.getRankPoints(data)
	deps.LeaderboardManager.submit(player, rankPoints)

	local function onCharacter()
		task.defer(function()
			HubWorldManager.spawnInHub(player)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playerZones[player] = nil
	local deps = HubWorldManager._deps
	if deps then
		deps.PlayerDataManager.save(player)
	end
end

return HubWorldManager
