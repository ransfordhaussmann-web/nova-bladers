local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local playerZones = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			for _, name in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = bowl:FindFirstChild(name)
				if spawn and spawn:IsA("BasePart") then
					return spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
		end
	end
	return CFrame.new(HubConfig.ARENA_FALLBACK)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = cframe
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateHallBoard(entries)
	local board = HubWorldBuilder.getLeaderboardBoard()
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if list then
		list.Text = formatLeaderboard(entries)
	end
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

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	return {
		inHub = inHub,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	}
end

local function sendToHub(player)
	teleportPlayer(player, CFrame.new(HubConfig.SPAWN))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

function HubWorldManager.returnToHub(player)
	sendToHub(player)
end

local function sendToArena(player)
	teleportPlayer(player, getArenaSpawnCFrame())
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, false))
end

local function zoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local min = zone.position - half
		local max = zone.position + half
		if position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y + 4
			and position.Z >= min.Z and position.Z <= max.Z then
			return zone
		end
	end
	return nil
end

local function handleZoneAction(player, zoneId)
	if zoneId == "arena" then
		sendToArena(player)
	elseif zoneId == "beylab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "halloffame" then
		local entries = LeaderboardManager.getTop(5)
		remotes.HubZoneHint:FireClient(player, {
			zoneId = "halloffame",
			name = "Ruhmeshalle",
			hint = formatLeaderboard(entries),
			persistent = true,
		})
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		sendToHub(player)
	end)

	if player.Character then
		sendToHub(player)
	end
end

local function onPlayerRemoving(player)
	playerZones[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		sendToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			local entries = LeaderboardManager.getTop(5)
			updateHallBoard(entries)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local zone = zoneAtPosition(root.Position)
					local prev = playerZones[player]
					local zoneId = zone and zone.id or nil
					if zoneId ~= prev then
						playerZones[player] = zoneId
						if zone then
							remotes.HubZoneHint:FireClient(player, {
								zoneId = zone.id,
								name = zone.name,
								hint = zone.hint,
								persistent = false,
							})
						else
							remotes.HubZoneHint:FireClient(player, nil)
						end
					end
				end
			end
			task.wait(0.35)
		end
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
