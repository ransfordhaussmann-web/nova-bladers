local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
local playerZones = {}
local inArena = {}

local ZONE_LOOKUP = {}
for _, zone in HubConfig.ZONES do
	ZONE_LOOKUP[zone.id] = zone
end

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
	return HubConfig.ARENA_SPAWN_FALLBACK
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

function HubWorldManager.updateLeaderboardBoard()
	if not hub then return end
	local label = HubWorldBuilder.getLeaderboardBoard(hub)
	if not label then return end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD.topCount)
	label.Text = formatLeaderboard(entries)
end

local function sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubConfig.SPAWN_CFRAME
	end
	inArena[player] = nil
	sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = getArenaSpawnCFrame()
	end
	inArena[player] = true
	sendLobbyReady(player, false)
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, zoneId)
	if inArena[player] then return end

	local zone = ZONE_LOOKUP[zoneId]
	if not zone or zone.action == "none" then return end

	if zone.action == "enterArena" then
		teleportToArena(player)
	elseif zone.action == "openBeySelect" then
		openBeySelect(player)
	end
end

local function setPlayerZone(player, zoneId)
	local previous = playerZones[player]
	if previous == zoneId then return end
	playerZones[player] = zoneId

	if inArena[player] then return end

	if zoneId then
		local zone = ZONE_LOOKUP[zoneId]
		if zone then
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zoneId,
				name = zone.name,
				hint = zone.hint,
				action = zone.action,
				active = true,
			})
		end
	elseif previous then
		remotes.HubZoneHint:FireClient(player, { active = false })
	end
end

local function bindZone(zonePart)
	local zoneId = zonePart:GetAttribute("ZoneId")
	if not zoneId then return end

	zonePart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			setPlayerZone(player, zoneId)
		end
	end)

	zonePart.TouchEnded:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player and playerZones[player] == zoneId then
			setPlayerZone(player, nil)
		end
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not inArena[player] then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onPlayerRemoving(player)
	playerZones[player] = nil
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init(remotesFolder, hubFolder)
	remotes = remotesFolder
	hub = hubFolder

	for _, zonePart in hub.Zones:GetChildren() do
		if zonePart:IsA("BasePart") and zonePart:GetAttribute("ZoneId") then
			bindZone(zonePart)
		end
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		if playerZones[player] ~= zoneId then return end
		handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	HubWorldManager.updateLeaderboardBoard()
	task.spawn(function()
		while true do
			task.wait(60)
			HubWorldManager.updateLeaderboardBoard()
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
