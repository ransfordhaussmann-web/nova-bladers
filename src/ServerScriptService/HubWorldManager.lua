local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
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

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
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

function HubWorldManager.sendLobbyReady(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	teleportCharacter(player, HubConfig.SPAWN_POSITION)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player)
	if remotes then
		remotes.ReturnToHub:FireClient(player)
	end
end

local function enterArena(player)
	local spawnPart = findArenaSpawn()
	local target = spawnPart and (spawnPart.Position + Vector3.new(0, 3, 0)) or (HubConfig.SPAWN_POSITION + Vector3.new(0, 0, -60))
	inArena[player] = true
	teleportCharacter(player, target)
	if remotes then
		remotes.EnterArena:FireClient(player)
	end
end

local function openBeySelect(player)
	if remotes then
		remotes.OpenBeySelect:FireClient(player)
	end
end

local function showHallPanel(player)
	if remotes then
		remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
	end
end

local function onZoneAction(player, zoneId)
	if inArena[player] then return end
	if zoneId == "ArenaGate" then
		enterArena(player)
	elseif zoneId == "BeyLab" then
		openBeySelect(player)
	elseif zoneId == "HallOfFame" then
		showHallPanel(player)
	end
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inArena[player] then return end
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		onZoneAction(player, zoneId)
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not inArena[player] then
					HubWorldManager.spawnInHub(player)
				end
			end)
		end)

		if player.Character and not inArena[player] then
			HubWorldManager.spawnInHub(player)
		end

		HubWorldManager.sendLobbyReady(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
