local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = game
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current
		end
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

local function buildLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = options.inHub ~= false,
		showPanel = options.showPanel == true,
	}
end

function HubWorldManager.sendLobbyReady(player, options)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, options))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	inArena[player] = nil
	HubWorldManager.sendLobbyReady(player, { inHub = true, showPanel = false })
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.teleportToArena(player)
	local spawn = resolveArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Arena.ArenaSpawn in Studio anlegen.")
		return false
	end

	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	inArena[player] = true
	remotes.LobbyReady:FireClient(player, { inHub = true, showPanel = false, hideAll = true })
	return true
end

local function onZoneTriggered(player, zoneId)
	if inArena[player] then
		return
	end

	if zoneId == "ArenaGate" then
		HubWorldManager.teleportToArena(player)
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyReady(player, { inHub = false, showPanel = true })
	end
end

local function connectZonePrompts(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zoneFolder in zones:GetChildren() do
		local platform = zoneFolder:FindFirstChild("Platform")
		local prompt = platform and platform:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, zoneFolder.Name)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				return
			end
			HubWorldManager.teleportToHub(player)
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	else
		HubWorldManager.sendLobbyReady(player, { inHub = true, showPanel = false })
	end
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	inArena[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local hub = HubWorldBuilder.build()
	connectZonePrompts(hub)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
