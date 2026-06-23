local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hub
local zoneParts
local playerZones = {}
local leaderboardBoard

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end
	local bowl = arena:FindFirstChild("Bowl")
	if not bowl then return nil end
	return bowl:FindFirstChild("Spawn")
end

local function getPlayerRank(player)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherPoints = PlayerDataManager.getRankPoints(PlayerDataManager.get(other))
			if otherPoints > points then
				rank += 1
			end
		end
	end
	return rank + 1
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local playerCount = #Players:GetPlayers()
	local modeLabel = "Modus: Training"
	if playerCount >= 3 then
		modeLabel = "Modus: FFA"
	elseif playerCount == 2 then
		modeLabel = "Modus: 1v1 PvP"
	end

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player),
		modeLabel = modeLabel,
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function formatLeaderboardText(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateLeaderboardBoard()
	if not leaderboardBoard then return end
	local gui = leaderboardBoard:FindFirstChild("LeaderboardGui")
	if not gui then return end
	local body = gui:FindFirstChild("Body")
	if not body then return end
	body.Text = formatLeaderboardText(LeaderboardManager.getTop(5))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN) + Vector3.new(0, 3, 0)
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if spawn and spawn:IsA("BasePart") then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 5, 0)
	end
end

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function playerInZone(player, zoneId)
	local entry = zoneParts[zoneId]
	if not entry then return false end
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local trigger = entry.trigger
	local rel = trigger.CFrame:PointToObjectSpace(root.Position)
	local half = trigger.Size / 2
	return math.abs(rel.X) <= half.X
		and math.abs(rel.Y) <= half.Y
		and math.abs(rel.Z) <= half.Z
end

local function sendZoneHint(player, zoneId)
	local zone = getZoneConfig(zoneId)
	if not zone then return end
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zone.id,
		name = zone.name,
		hint = zone.hint,
		action = zone.action,
	})
end

local function clearZoneHint(player)
	remotes.HubZoneHint:FireClient(player, nil)
end

local function handleZoneAction(player, zoneId)
	local zone = getZoneConfig(zoneId)
	if not zone or not zone.action then return end

	if zone.action == "EnterArena" then
		teleportToArena(player)
		remotes.HubZoneAction:FireClient(player, { action = "LeftHub" })
	elseif zone.action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub, zoneParts = HubWorldBuilder.build()

	local fameZone = hub:FindFirstChild("LeaderboardBoard", true)
	if fameZone then
		leaderboardBoard = fameZone
	end
	updateLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
		remotes.HubZoneAction:FireClient(player, { action = "LeftHub" })
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			teleportToHub(player)
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
		end)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character then
			teleportToHub(player)
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local currentZone = nil
				for zoneId, _ in zoneParts do
					if playerInZone(player, zoneId) then
						currentZone = zoneId
						break
					end
				end

				if currentZone ~= playerZones[player] then
					playerZones[player] = currentZone
					if currentZone then
						sendZoneHint(player, currentZone)
					else
						clearZoneHint(player)
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.LEADERBOARD_REFRESH)
			updateLeaderboardBoard()
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then return end
		if payload.action == "ActivateZone" and typeof(payload.zoneId) == "string" then
			if playerZones[player] == payload.zoneId then
				handleZoneAction(player, payload.zoneId)
			end
		end
	end)
end

return HubWorldManager
