local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
local playersInArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
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

local function updateLeaderboardBoard()
	local label = HubWorldBuilder.getLeaderboardLabel()
	if not label then return end
	label.Text = formatLeaderboard(LeaderboardManager.getTop(5))
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn") or bowl:FindFirstChildWhichIsA("SpawnLocation")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(0, 6, 0)
end

local function buildLobbyPayload(player, flags)
	flags = flags or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	local rank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = flags.inHub == true,
		inArena = flags.inArena == true,
	}
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.sendLobbyState(player, flags)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, flags))
end

function HubWorldManager.spawnInHub(player)
	playersInArena[player] = nil
	local spawn = hub:FindFirstChild("HubSpawn")
	local cframe = spawn and spawn.CFrame or CFrame.new(HubConfig.SPAWN_POSITION)
	teleportCharacter(player, cframe)
	HubWorldManager.sendLobbyState(player, { inHub = true })
end

function HubWorldManager.enterArena(player)
	playersInArena[player] = true
	teleportCharacter(player, findArenaSpawn())
	HubWorldManager.sendLobbyState(player, { inArena = true })
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playersInArena[player] then
			HubWorldManager.enterArena(player)
		else
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		task.defer(function()
			HubWorldManager.spawnInHub(player)
		end)
	end

	updateLeaderboardBoard()
end

local function onPlayerRemoving(player)
	playersInArena[player] = nil
	PlayerDataManager.save(player)
end

local function onZoneAction(player, zoneId)
	if typeof(zoneId) ~= "string" then return end
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showLeaderboard" then
		updateLeaderboardBoard()
		remotes.HubZoneHint:FireClient(player, {
			zoneId = zoneId,
			name = zone.name,
			hint = formatLeaderboard(LeaderboardManager.getTop(5)),
		})
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()
	updateLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		onZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(30)
			updateLeaderboardBoard()
		end
	end)
end

return HubWorldManager
