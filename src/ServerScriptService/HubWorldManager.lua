local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")

local HubWorldManager = {}
local hubFolder = nil
local playerModes = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function formatLeaderboardText(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

local function formatStatsText(wins, losses, rank)
	return string.format("Wins: %d\nLosses: %d\nRank: %d", wins, losses, rank)
end

function HubWorldManager.updateBoards(wins, losses, rank, leaderboard)
	if not hubFolder then
		return
	end

	local statsBody = HubWorldBuilder.findBoardBody(hubFolder, "StatsKiosk")
	if statsBody then
		statsBody.Text = formatStatsText(wins, losses, rank)
	end

	local lbBody = HubWorldBuilder.findBoardBody(hubFolder, "Leaderboard")
	if lbBody then
		lbBody.Text = formatLeaderboardText(leaderboard)
	end
end

function HubWorldManager.buildHub()
	hubFolder = HubWorldBuilder.build(Workspace)
	return hubFolder
end

function HubWorldManager.isInHub(player)
	return playerModes[player] == "hub"
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
	playerModes[player] = "hub"
end

function HubWorldManager.sendToArena(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local arenaFolder = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	local target = HubWorldBuilder.getArenaTeleportCFrame()
	if arenaFolder then
		local spawn = arenaFolder:FindFirstChild("ArenaSpawn", true)
		if spawn and spawn:IsA("BasePart") then
			target = spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	root.CFrame = target
	playerModes[player] = "arena"
end

function HubWorldManager.enterArena(player)
	HubWorldManager.sendToArena(player)
	-- GameManager in Studio sollte EnterArena ebenfalls hören und Match starten.
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.refreshLobby(player)
end

function HubWorldManager.refreshLobby(player)
	local data = PlayerDataManager.get(player)
	local rank = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_COUNT)
	local playerCount = #Players:GetPlayers()

	LeaderboardManager.submit(player, rank)
	HubWorldManager.updateBoards(data.Wins, data.Losses, rank, leaderboard)

	Remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		hubMode = true,
	})
end

local function onCharacterAdded(player, character)
	task.defer(function()
		if playerModes[player] == "arena" then
			return
		end
		HubWorldManager.teleportToHub(player)
	end)
end

local function wirePrompts()
	if not hubFolder then
		return
	end

	local arenaPortal = hubFolder:FindFirstChild("ArenaPortal", true)
	if arenaPortal then
		local prompt = arenaPortal:FindFirstChild("ArenaPortalPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				HubWorldManager.enterArena(player)
			end)
		end
	end

	local beyStation = hubFolder:FindFirstChild("BeyStation", true)
	if beyStation then
		local prompt = beyStation:FindFirstChild("BeyStationPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				Remotes.OpenBeySelect:FireClient(player)
			end)
		end
	end
end

function HubWorldManager.init()
	HubWorldManager.buildHub()
	wirePrompts()

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		playerModes[player] = "hub"

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end

		task.defer(function()
			HubWorldManager.refreshLobby(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerModes[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		playerModes[player] = "hub"
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		task.defer(function()
			HubWorldManager.refreshLobby(player)
		end)
	end
end

return HubWorldManager
