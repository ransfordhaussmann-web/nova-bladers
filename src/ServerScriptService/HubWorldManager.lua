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
local zoneCooldown = {}

local ZONE_CHECK_INTERVAL = 0.35
local ZONE_HINT_COOLDOWN = 2.5

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if not arena then
		return nil
	end
	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChildWhichIsA("BasePart")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, 5, 0)
	end
	return nil
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

function HubWorldManager.buildWorld()
	local leaderboard = LeaderboardManager.getTop(5)
	hubFolder, _ = HubWorldBuilder.build(leaderboard)
end

function HubWorldManager.refreshHallBoard()
	if not hubFolder then
		return
	end
	HubWorldBuilder.buildHallBoard(hubFolder, LeaderboardManager.getTop(5))
end

function HubWorldManager.sendLobbyState(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	})
end

function HubWorldManager.spawnInHub(player)
	local root = getCharacterRoot(player)
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	playersInHub[player] = true
	HubWorldManager.sendLobbyState(player, true)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
	HubWorldManager.refreshHallBoard()
end

function HubWorldManager.teleportToArena(player)
	local root = getCharacterRoot(player)
	if not root then
		return false
	end
	local arenaCFrame = findArenaSpawn()
	if not arenaCFrame then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Workspace.Arena.Spawn anlegen")
		return false
	end
	playersInHub[player] = nil
	root.CFrame = arenaCFrame
	HubWorldManager.sendLobbyState(player, false)
	return true
end

local function getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local offset = position - zone.position
		if math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z then
			return zone
		end
	end
	return nil
end

local function canHint(player)
	local now = os.clock()
	local last = zoneCooldown[player]
	if last and now - last < ZONE_HINT_COOLDOWN then
		return false
	end
	zoneCooldown[player] = now
	return true
end

local function checkZones()
	for player, inHub in playersInHub do
		if not inHub or not player.Parent then
			continue
		end
		local root = getCharacterRoot(player)
		if not root then
			continue
		end
		local zone = getZoneAtPosition(root.Position)
		if zone and canHint(player) then
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zone.id,
				name = zone.name,
				hint = zone.hint,
				action = zone.action,
			})
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playersInHub[player] ~= false then
			HubWorldManager.spawnInHub(player)
		end
	end)
	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then
			return
		end
		remotes.OpenBeySelect:FireClient(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		zoneCooldown[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			checkZones()
			task.wait(ZONE_CHECK_INTERVAL)
		end
	end)
end

return HubWorldManager
