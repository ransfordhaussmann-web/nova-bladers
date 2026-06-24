local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local hubFolder
local playersInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function findArenaSpawn()
	local arena = Workspace:FindFirstChild("Arena")
	if not arena then return nil end
	local bowl = arena:FindFirstChild("Bowl")
	if not bowl then return nil end
	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = bowl:FindFirstChild(name)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return bowl:FindFirstChildWhichIsA("BasePart")
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(HubConfig.SPAWN)
	playersInHub[player] = true
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

local function enterArena(player)
	playersInHub[player] = nil
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena spawn not found — place Workspace.Arena.Bowl.Spawn")
		return
	end
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
end

local function onZoneAction(player, action)
	if action == "enterArena" then
		enterArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showLeaderboard" then
		HubWorldManager.sendLobbyReady(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local leaderboard = LeaderboardManager.getTop(5)
	hubFolder = HubWorldBuilder.build(leaderboard)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if playersInHub[player] ~= false then
				teleportToHub(player)
				HubWorldManager.sendLobbyReady(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.persist(player)
		playersInHub[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		playersInHub[player] = true
		if player.Character then
			teleportToHub(player)
		end
		HubWorldManager.sendLobbyReady(player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			onZoneAction(player, action)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

function HubWorldManager.refreshLeaderboard()
	if not hubFolder then return end
	HubWorldBuilder.updateLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
end

return HubWorldManager
