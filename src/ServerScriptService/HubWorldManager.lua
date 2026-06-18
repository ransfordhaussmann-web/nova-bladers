local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local hubModel

local function getRemotes()
	if remotes then return remotes end
	remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	return remotes
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

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = player:GetAttribute("inHub") == true,
	}
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then return nil end
	return arena:FindFirstChild(HubConfig.ARENA_SPAWN_NAME, true)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
end

function HubWorldManager.setHubModel(model)
	hubModel = model
end

function HubWorldManager.spawnInHub(player)
	local spawn = hubModel and hubModel:FindFirstChild("HubSpawn")
	local target = spawn and spawn.CFrame or CFrame.new(HubConfig.SPAWN_POSITION)
	teleportCharacter(player, target)
end

function HubWorldManager.returnToHub(player)
	player:SetAttribute("inHub", true)
	HubWorldManager.spawnInHub(player)
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[HubWorldManager] ArenaSpawn nicht gefunden — Arena-Tor deaktiviert")
		return
	end

	player:SetAttribute("inHub", false)
	teleportCharacter(player, arenaSpawn.CFrame)
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.load(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	player:SetAttribute("inHub", true)
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.onPlayerAdded(player)
	player:SetAttribute("inHub", true)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player:GetAttribute("inHub") == true then
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.bindRemotes()
	local remoteFolder = getRemotes()

	remoteFolder.EnterArena.OnServerEvent:Connect(function(player)
		if player:GetAttribute("inHub") ~= true then return end
		HubWorldManager.enterArena(player)
	end)

	remoteFolder.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remoteFolder.OpenBeySelect.OnServerEvent:Connect(function(player)
		if player:GetAttribute("inHub") ~= true then return end
		-- BeySelect-GUI wird clientseitig geöffnet; Server validiert nur Hub-Status.
	end)
end

return HubWorldManager
