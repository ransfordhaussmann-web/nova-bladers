local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playerStates = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn")
			or arena:FindFirstChild("ArenaSpawn")
			or arena:FindFirstChildWhichIsA("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl then
		local center = bowl:IsA("Model") and bowl:GetPivot() or bowl.CFrame
		return center + Vector3.new(0, 5, 0)
	end

	return CFrame.new(0, 5, 0)
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

function HubWorldManager.sendLobbyReady(player, inHub)
	inHub = inHub ~= false
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPart = hubModel and hubModel:FindFirstChild("HubSpawn")
	local target = spawnPart and spawnPart.CFrame or CFrame.new(HubConfig.SPAWN_POSITION)
	root.CFrame = target + Vector3.new(0, 3, 0)

	playerStates[player] = "hub"
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	playerStates[player] = "arena"
	root.CFrame = getArenaSpawnCFrame()

	local hud = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = true end
end

function HubWorldManager.openBeySelect(player)
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BeySelect")
	if gui then
		gui.Enabled = true
	end
end

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(entries)
	for player, state in playerStates do
		if state == "hub" and player.Parent then
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
		end
	end
end

function HubWorldManager.onPlayerReady(player)
	if playerStates[player] then return end
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.teleportToHub(player)
	HubWorldManager.refreshLeaderboard()
end

function HubWorldManager.onPlayerLeaving(player)
	playerStates[player] = nil
	PlayerDataManager.save(player)
end

local function bindZonePrompts()
	local zones = hubModel and hubModel:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("HubPrompt")
		if not prompt then continue end

		local action = zonePart:GetAttribute("ZoneAction")
		prompt.Triggered:Connect(function(player)
			if action == "EnterArena" then
				HubWorldManager.teleportToArena(player)
			elseif action == "OpenBeySelect" then
				HubWorldManager.openBeySelect(player)
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	bindZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playerStates[player] == "hub" then
			HubWorldManager.teleportToArena(player)
		end
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if playerStates[player] == "hub" then
			HubWorldManager.openBeySelect(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not player.Parent then return end
				local state = playerStates[player]
				if state == "hub" then
					HubWorldManager.teleportToHub(player)
				elseif not state then
					HubWorldManager.onPlayerReady(player)
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		HubWorldManager.onPlayerLeaving(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerReady(player)
	end

	task.spawn(function()
		while true do
			task.wait(60)
			HubWorldManager.refreshLeaderboard()
		end
	end)
end

return HubWorldManager
