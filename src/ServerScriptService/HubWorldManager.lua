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
local hubFolder
local playersInHub = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current.CFrame + Vector3.new(0, 3, 0)
		end
		if current and current:IsA("Model") then
			local part = current.PrimaryPart or current:FindFirstChildWhichIsA("BasePart")
			if part then
				return part.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(HubConfig.ARENA_FALLBACK)
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = "Modus: Training",
		leaderboard = leaderboard,
		inHub = inHub,
		inArena = not inHub,
	}
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

local function enterArena(player)
	if not playersInHub[player] then return end
	playersInHub[player] = nil
	teleportCharacter(player, resolveArenaSpawn())
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, false))
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(hubFolder, entries)
end

local function handleZoneAction(player, action)
	if action == "enterArena" then
		enterArena(player)
	elseif action == "openBeySelect" then
		openBeySelect(player)
	elseif action == "showLeaderboard" then
		refreshLeaderboardBoard()
		local entries = LeaderboardManager.getTop(5)
		remotes.HubZoneHint:FireClient(player, {
			zoneId = "HallOfFame",
			hint = "Top 5 Spieler — siehe Tafel",
			leaderboard = entries,
		})
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		handleZoneAction(player, action)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

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
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end

	task.spawn(function()
		while true do
			task.wait(60)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
