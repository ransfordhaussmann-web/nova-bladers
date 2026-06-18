local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local hubFolder
local playerDataManager
local leaderboardManager
local inHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboardManager.getTop(5),
		inHub = inHub[player] == true,
	}
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function getHubSpawnCFrame()
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.spawnInHub(player)
	inHub[player] = true
	player:SetAttribute("InHub", true)
	teleportCharacter(player, getHubSpawnCFrame())
	sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	player:SetAttribute("InHub", true)
	teleportCharacter(player, getHubSpawnCFrame())
	sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = HubWorldBuilder.findArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] ArenaSpawn nicht gefunden — Arena-Tor deaktiviert.")
		return false
	end

	inHub[player] = false
	player:SetAttribute("InHub", false)
	teleportCharacter(player, arenaSpawn.CFrame + Vector3.new(0, 3, 0))
	sendLobbyReady(player)
	return true
end

local function handleZoneAction(player, action)
	if action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowHallOfFame" then
		remotes.HallOfFameData:FireClient(player, buildLobbyPayload(player))
	end
end

local function wireZonePrompt(prompt)
	if prompt:GetAttribute("HubWired") then return end
	prompt:SetAttribute("HubWired", true)

	prompt.Triggered:Connect(function(player)
		if not inHub[player] then return end
		local action = prompt:GetAttribute("PromptAction")
		if action then
			handleZoneAction(player, action)
		end
	end)
end

local function wireHubZones()
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end
	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			wireZonePrompt(prompt)
		end
	end
	zones.ChildAdded:Connect(function(child)
		local prompt = child:FindFirstChild("ZonePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			wireZonePrompt(prompt)
		end
	end)
end

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager

	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	wireHubZones()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		handleZoneAction(player, action)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inHub[player] = nil
	end)
end

function HubWorldManager.onPlayerReady(player)
	HubWorldManager.spawnInHub(player)
end

return HubWorldManager
