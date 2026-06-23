local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}
local remotes
local playersInHub = {}
local hubBuilt = false

local function resolveArenaSpawn()
	local current = Workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		current = current:FindFirstChild(name)
		if not current then
			return HubConfig.ARENA_FALLBACK
		end
	end
	if current:IsA("BasePart") then
		return current.Position + Vector3.new(0, 3, 0)
	end
	if current:IsA("Model") then
		local primary = current.PrimaryPart or current:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary.Position + Vector3.new(0, 3, 0)
		end
	end
	return HubConfig.ARENA_FALLBACK
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
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

local function getPlayerRank(player, data)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 1
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherData = PlayerDataManager.get(other)
			if PlayerDataManager.getRankPoints(otherData) > points then
				rank += 1
			end
		end
	end
	return rank
end

function HubWorldManager.sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local leaderboard = LeaderboardManager.getTop(5)
	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player, data),
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub ~= false,
	})
end

function HubWorldManager.refreshLeaderboardBoard()
	local hubFolder = Workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if not hubFolder then return end
	local board = hubFolder:FindFirstChild("LeaderboardBoard")
	if not board then return end
	HubWorldBuilder.updateLeaderboardBoard(board, LeaderboardManager.getTop(5))
end

function HubWorldManager.ensureHubBuilt()
	if hubBuilt then return end
	local folder = HubWorldBuilder.getOrCreateFolder()
	HubWorldBuilder.build(folder, LeaderboardManager.getTop(5))
	hubBuilt = true
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportPlayer(player, HubConfig.SPAWN)
	HubWorldManager.sendLobbyReady(player, true)
end

local function enterArena(player)
	playersInHub[player] = nil
	teleportPlayer(player, resolveArenaSpawn())
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function handleZoneAction(player, zoneId)
	if not playersInHub[player] then return end

	local zoneConfig
	for _, config in pairs(HubConfig.ZONES) do
		if config.id == zoneId then
			zoneConfig = config
			break
		end
	end
	if not zoneConfig then return end

	if zoneConfig.action == "enterArena" then
		enterArena(player)
	elseif zoneConfig.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneConfig.action == "viewLeaderboard" then
		HubWorldManager.refreshLeaderboardBoard()
		HubWorldManager.sendLobbyReady(player, true)
	end
end

function HubWorldManager.onPlayerAdded(player)
	HubWorldManager.ensureHubBuilt()

	local data = PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		if playersInHub[player] ~= false then
			task.defer(function()
				teleportPlayer(player, HubConfig.SPAWN)
			end)
		end
	end)

	playersInHub[player] = true
	task.defer(function()
		if player.Parent then
			teleportPlayer(player, HubConfig.SPAWN)
			HubWorldManager.sendLobbyReady(player, true)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			enterArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)
end

return HubWorldManager
