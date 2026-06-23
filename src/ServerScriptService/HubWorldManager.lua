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

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return nil
	end

	local bowl = arena:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn")
			or bowl:FindFirstChildWhichIsA("SpawnLocation")
		if spawn then
			return spawn
		end
	end

	return arena:FindFirstChild("Spawn")
		or arena:FindFirstChildWhichIsA("SpawnLocation")
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

function HubWorldManager.sendLobbyReady(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		leaderboard = leaderboard,
		modeLabel = getModeLabel(),
		inHub = options.inHub ~= false,
	})
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local character = player.Character
	if not character then
		return
	end
	teleportCharacter(player, HubConfig.SPAWN_POSITION)
	HubWorldManager.sendLobbyReady(player, { inHub = true })
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	if inArena[player] then
		return
	end

	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Bowl/Spawn in Workspace.Arena anlegen")
		return
	end

	inArena[player] = true
	local target = spawn:IsA("BasePart") and spawn.Position or HubConfig.SPAWN_POSITION
	teleportCharacter(player, target + Vector3.new(0, 3, 0))

	remotes.LobbyReady:FireClient(player, {
		wins = PlayerDataManager.get(player).Wins,
		losses = PlayerDataManager.get(player).Losses,
		rank = PlayerDataManager.getRankPoints(PlayerDataManager.get(player)),
		leaderboard = LeaderboardManager.getTop(5),
		modeLabel = getModeLabel(),
		inHub = false,
	})
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.refreshLeaderboardBoard()
	local hub = workspace:FindFirstChild("NovaHub")
	if hub then
		HubWorldBuilder.buildLeaderboardBoard(hub, LeaderboardManager.getTop(5))
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not inArena[player] then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "enterArena" then
			HubWorldManager.enterArena(player)
		elseif action == "openBeySelect" then
			HubWorldManager.openBeySelect(player)
		end
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(60)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
