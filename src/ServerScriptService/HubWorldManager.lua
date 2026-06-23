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
local hub
local playerZones = {}
local inArena = {}

local function getArenaSpawn()
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
	return CFrame.new(0, 10, 0)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
	inArena[player] = nil
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = getArenaSpawn()
	inArena[player] = true
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function handleZoneAction(player, zoneId)
	if inArena[player] then return end

	if zoneId == "arena" then
		teleportToArena(player)
	elseif zoneId == "beyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "hallOfFame" then
		HubWorldManager.sendLobbyReady(player)
	end
end

local function onPlayerZoneChanged(player, zoneId)
	local previous = playerZones[player]
	if previous == zoneId then return end
	playerZones[player] = zoneId

	if inArena[player] then return end

	if zoneId then
		for _, zone in HubConfig.ZONES do
			if zone.id == zoneId then
				remotes.HubZoneHint:FireClient(player, {
					zoneId = zoneId,
					name = zone.name,
					hint = zone.hint,
					canAct = zone.action ~= "viewLeaderboard",
				})
				return
			end
		end
	else
		remotes.HubZoneHint:FireClient(player, { zoneId = nil })
	end
end

local function getPlayerZoneId(player)
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local pos = root.Position

	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2 + Vector3.new(1, 2, 1)
		local offset = pos - zone.position
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			return zone.id
		end
	end
	return nil
end

local function pollPlayerZones()
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			onPlayerZoneChanged(player, getPlayerZoneId(player))
		end
	end
end

local function refreshLeaderboardBoard()
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard", true)
	if board then
		HubWorldBuilder.updateLeaderboardBoard(board, LeaderboardManager.getTop(5))
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	local leaderboardBoard = HubWorldBuilder.createLeaderboardBoard(
		hub,
		LeaderboardManager.getTop(5)
	)
	leaderboardBoard.Name = "LeaderboardBoard"

	RunService.Heartbeat:Connect(pollPlayerZones)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inArena[player] then return end
		teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character and not inArena[player] then
			HubWorldManager.teleportToHub(player)
		end
	end

	task.spawn(function()
		while true do
			task.wait(60)
			refreshLeaderboardBoard()
		end
	end)
end

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player)
end

return HubWorldManager
