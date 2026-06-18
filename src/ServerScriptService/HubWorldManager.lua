local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inHub = {}
local zoneDebounce = {}

local function getRemotes()
	if remotes then return remotes end
	remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
	return remotes
end

local function getHubSpawnCFrame()
	local hub = workspace:FindFirstChild("NovaHub")
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 5, 0)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function modeLabelForPlayerCount(count)
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelForPlayerCount(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = HubWorldManager.isInHub(player),
	}
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.sendLobbyReady(player)
	getRemotes().LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.placeInHub(player)
	inHub[player] = true
	player:SetAttribute("inHub", true)
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	player:SetAttribute("inHub", true)
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	inHub[player] = false
	player:SetAttribute("inHub", false)
	teleportCharacter(player, getArenaSpawnCFrame())
end

function HubWorldManager.onZoneTriggered(player, remoteName)
	if zoneDebounce[player] and os.clock() - zoneDebounce[player] < HubConfig.ZONE_TOUCH_DEBOUNCE then
		return
	end
	zoneDebounce[player] = os.clock()

	if remoteName == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif remoteName == "OpenBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif remoteName == "ShowHallOfFame" then
		getRemotes().ShowHallOfFame:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end
end

function HubWorldManager.init()
	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	getRemotes().ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	getRemotes().OpenBeySelect.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInHub(player) then
			getRemotes().OpenBeySelect:FireClient(player)
		end
	end)

	getRemotes().ShowHallOfFame.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInHub(player) then
			getRemotes().ShowHallOfFame:FireClient(player, HubWorldManager.buildLobbyPayload(player))
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		inHub[player] = true
		player:SetAttribute("inHub", true)

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if HubWorldManager.isInHub(player) then
					teleportCharacter(player, getHubSpawnCFrame())
				end
			end)
		end)

		local data = PlayerDataManager.load(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)
		HubWorldManager.sendLobbyReady(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inHub[player] = nil
		zoneDebounce[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		inHub[player] = player:GetAttribute("inHub") ~= false
		HubWorldManager.sendLobbyReady(player)
	end
end

return HubWorldManager
