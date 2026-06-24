local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hub
local remotes
local playerZone = {}

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = folder:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		inHub = true,
	}
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	playerZone[player] = nil
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 10, 0)
		warn("[HubWorldManager] Kein Arena-Spawn gefunden — Fallback-Position genutzt.")
	end
	playerZone[player] = nil
end

local function getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local center = zone.position + Vector3.new(0, zone.size.Y / 2, 0)
		local half = zone.size / 2
		local offset = position - center
		if math.abs(offset.X) <= half.X
			and math.abs(offset.Y) <= half.Y + 4
			and math.abs(offset.Z) <= half.Z
		then
			return zone
		end
	end
	return nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local leaderboard = LeaderboardManager.getTop(5)
	hub = HubWorldBuilder.build(leaderboard)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		sendLobbyReady(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		sendLobbyReady(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local zone = getZoneAtPosition(root.Position)
					local prev = playerZone[player]
					local zoneId = zone and zone.id or nil
					if zoneId ~= prev then
						playerZone[player] = zoneId
						if zone then
							remotes.HubZoneHint:FireClient(player, {
								zoneId = zone.id,
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
		end
	end)
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player)
end

function HubWorldManager.refreshLeaderboard()
	if not hub then return end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboard(hub, entries)
end

function HubWorldManager.getHub()
	return hub
end

return HubWorldManager
