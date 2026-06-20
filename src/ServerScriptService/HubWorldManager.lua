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
local inMatch = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
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
	}
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local current = Workspace
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function teleportCharacter(character, position)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

function HubWorldManager.spawnInHub(player)
	inMatch[player] = nil
	local character = player.Character
	if not character then
		return
	end
	teleportCharacter(character, HubConfig.SPAWN_POSITION)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	remotes.ReturnToHub:FireClient(player)
end

local function handleEnterArena(player)
	inMatch[player] = true
	local spawn = findArenaSpawn()
	if spawn and player.Character then
		teleportCharacter(player.Character, spawn.Position + Vector3.new(0, 3, 0))
	end
end

local function handleZoneAction(player, action)
	if action == "EnterArena" then
		handleEnterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowHallPanel" then
		remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
	end
end

local function wireZonePrompts(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return
	end
	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChildOfClass("ProximityPrompt")
		local action = zonePart:GetAttribute("ZoneAction")
		if prompt and action then
			prompt.Triggered:Connect(function(player)
				handleZoneAction(player, action)
			end)
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build(Workspace)
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		wireZonePrompts(hub)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		handleEnterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			if not inMatch[player] then
				task.defer(function()
					HubWorldManager.spawnInHub(player)
				end)
			end
		end)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character and not inMatch[player] then
			HubWorldManager.spawnInHub(player)
		end
	end
end

return HubWorldManager
