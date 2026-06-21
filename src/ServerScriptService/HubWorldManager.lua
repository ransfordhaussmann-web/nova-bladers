local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubFolder
local hubSpawn
local leaderboardBoard

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end
	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end
	return nil
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
	end
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, entries)
	return entries
end

local function sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = refreshLeaderboardBoard()

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	})
end

function HubWorldManager.teleportToHub(player)
	if not hubSpawn then return end
	teleportCharacter(player, hubSpawn.CFrame)
	sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden (Arena.Spawn / Bowl)")
		return
	end
	local cf = arenaSpawn:IsA("BasePart") and arenaSpawn.CFrame or CFrame.new(arenaSpawn.Position)
	teleportCharacter(player, cf)
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		HubWorldManager.teleportToHub(player)
	end)
	if player.Character then
		task.defer(function()
			HubWorldManager.teleportToHub(player)
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder, hubSpawn, leaderboardBoard = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(30)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
