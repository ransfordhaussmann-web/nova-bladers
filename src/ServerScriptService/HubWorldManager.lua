local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playersInHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn") or bowl:FindFirstChild("SpawnLocation")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return HubConfig.ARENA_FALLBACK
end

local function refreshLeaderboardBoard()
	if not hubModel then return end
	local hall = hubModel.Zones:FindFirstChild("HallOfFame")
	if not hall then return end
	HubWorldBuilder.buildLeaderboardBoard(hall, LeaderboardManager.getTop(5))
end

local function sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

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
	playersInHub[player] = true
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN)
	end
	sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = false
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = findArenaSpawnCFrame()
	end
	sendLobbyReady(player, false)
end

local function wireZonePrompts()
	if not hubModel then return end
	for _, zonePart in hubModel.Zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if not prompt then continue end
		local action = prompt:GetAttribute("ZoneAction")
		prompt.Triggered:Connect(function(player)
			if action == "enterArena" then
				HubWorldManager.enterArena(player)
			elseif action == "openBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif action == "showLeaderboard" then
				refreshLeaderboardBoard()
				local zone = HubConfig.ZONES[zonePart.Name]
				if zone then
					remotes.HubZoneHint:FireClient(player, zone.name, zone.hint)
				end
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	wireZonePrompts()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if playersInHub[player] ~= false then
					HubWorldManager.spawnInHub(player)
				end
			end)
		end)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
