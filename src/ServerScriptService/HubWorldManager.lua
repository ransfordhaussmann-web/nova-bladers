local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local Remotes = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local inArena = {}
local hubModel

local function getArenaSpawnCFrame()
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = Workspace:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	return CFrame.new(0, 10, -120)
end

local function getPlayerCount()
	return #Players:GetPlayers()
end

local function getModeLabel()
	local count = getPlayerCount()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function refreshLeaderboardBoard()
	if not hubModel then
		return
	end
	HubWorldBuilder.buildLeaderboardBoard(hubModel, LeaderboardManager.getTop(5))
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.sendLobbyState(player)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	teleportCharacter(player, HubConfig.SPAWN)
	HubWorldManager.sendLobbyState(player)
end

local function enterArena(player)
	if inArena[player] then
		return
	end
	inArena[player] = true
	teleportCharacter(player, getArenaSpawnCFrame())
	Remotes.LobbyReady:FireClient(player, {
		inHub = false,
		modeLabel = getModeLabel(),
	})
end

local function openBeySelect(player)
	Remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, action)
	if action == "enterArena" then
		enterArena(player)
	elseif action == "openBeySelect" then
		openBeySelect(player)
	elseif action == "showLeaderboard" then
		refreshLeaderboardBoard()
		Remotes.HubZoneHint:FireClient(player, {
			zoneId = "FameHall",
			text = "Leaderboard in der Ruhmeshalle aktualisiert!",
		})
	end
end

local function wireZonePrompts()
	if not hubModel then
		return
	end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		if not zonePart:IsA("BasePart") then
			continue
		end
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if not prompt then
			continue
		end
		local action = zonePart:GetAttribute("ZoneAction")
		prompt.Triggered:Connect(function(player)
			handleZoneAction(player, action)
		end)
	end
end

function HubWorldManager.init()
	hubModel = HubWorldBuilder.build(LeaderboardManager.getTop(5))
	wireZonePrompts()

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				teleportCharacter(player, HubConfig.SPAWN)
				HubWorldManager.sendLobbyState(player)
			end
		end)

		if player.Character then
			task.defer(function()
				teleportCharacter(player, HubConfig.SPAWN)
				HubWorldManager.sendLobbyState(player)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
		HubWorldManager.sendLobbyState(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
