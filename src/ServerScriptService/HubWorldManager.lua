local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playersInHub = {}

local function getArenaSpawnCFrame()
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = Workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 3, 0)
	end

	return CFrame.new(0, 10, 80)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function getHubSpawnCFrame()
	if hubFolder then
		local spawn = hubFolder:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

local function refreshLeaderboardBoard()
	if not hubFolder then return end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	local hallZone = hubFolder:FindFirstChild("Zones")
	if not hallZone then return end
	local fame = hallZone:FindFirstChild("hall_of_fame")
	if not fame then return end
	local hall = fame:FindFirstChild("HallOfFame")
	if hall then
		HubWorldBuilder.buildLeaderboardBoard(hall, entries)
	end
end

function HubWorldManager.build()
	hubFolder = HubWorldBuilder.build(LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT))
	return hubFolder
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local payload = {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT),
	}
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.enterHub(player)
	playersInHub[player] = true
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
	refreshLeaderboardBoard()
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = nil
	teleportCharacter(player, getArenaSpawnCFrame())
end

function HubWorldManager.handleZoneAction(player, action)
	if not playersInHub[player] then return end

	if action == "enter_arena" then
		HubWorldManager.enterArena(player)
	elseif action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "show_leaderboard" then
		HubWorldManager.sendLobbyReady(player)
	end
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder
	HubWorldManager.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			HubWorldManager.enterArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			HubWorldManager.handleZoneAction(player, action)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if playersInHub[player] ~= false then
					HubWorldManager.enterHub(player)
				end
			end)
		end)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		task.defer(function()
			HubWorldManager.enterHub(player)
		end)
	end
end

return HubWorldManager
