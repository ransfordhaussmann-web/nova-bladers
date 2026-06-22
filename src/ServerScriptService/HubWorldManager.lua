local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local hubModel
local hubOrigin = Vector3.new(0, 0, 200)
local leaderboardRefreshScheduled = false

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function resolveArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local arenaSpawn = workspace:FindFirstChild("ArenaSpawn")
	if arenaSpawn and arenaSpawn:IsA("BasePart") then
		return arenaSpawn.CFrame + Vector3.new(0, 3, 0)
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl then
		local center = bowl:IsA("Model") and bowl:GetPivot().Position or bowl.Position
		return CFrame.new(center + Vector3.new(0, 3, 0))
	end

	return CFrame.new(0, 5, 0)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = cframe
	end
end

local function getHubSpawnCFrame()
	if hubModel then
		local spawn = hubModel:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(hubOrigin + HubConfig.SPAWN_OFFSET)
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubModel then return end
	local LeaderboardManager = require(script.Parent.LeaderboardManager)
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.buildLeaderboardBoard(hubModel, hubOrigin, entries)
end

function HubWorldManager.sendLobbyReady(player, inHub)
	local PlayerDataManager = require(script.Parent.PlayerDataManager)
	local LeaderboardManager = require(script.Parent.LeaderboardManager)

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
	})
end

function HubWorldManager.returnToHub(player)
	player:SetAttribute("InArena", false)
	teleportPlayer(player, getHubSpawnCFrame())
	remotes.ReturnToHub:FireClient(player)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.spawnInHub(player)
	if player:GetAttribute("InArena") then return end
	teleportPlayer(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player, true)
end

local function onEnterArena(player)
	player:SetAttribute("InArena", true)
	teleportPlayer(player, resolveArenaSpawn())
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function onZoneAction(player, action)
	if action == "enter_arena" then
		onEnterArena(player)
	elseif action == "bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "leaderboard" then
		HubWorldManager.sendLobbyReady(player, true)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build(hubOrigin)
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.HubZoneAction.OnServerEvent:Connect(onZoneAction)
	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				HubWorldManager.spawnInHub(player)
			end)
		end)
	end)

	for _, player in Players:GetPlayers() do
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end

	if not leaderboardRefreshScheduled then
		leaderboardRefreshScheduled = true
		task.spawn(function()
			while true do
				task.wait(60)
				HubWorldManager.refreshLeaderboardBoard()
			end
		end)
	end
end

return HubWorldManager
