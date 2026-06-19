local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inHub = {}

local function getRemotes()
	if remotes then return remotes end
	remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	return remotes
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getHubSpawn()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then return HubConfig.SPAWN_OFFSET end
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return HubConfig.SPAWN_OFFSET
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function buildLobbyPayload(player, inHubFlag)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	local modeLabel = "Modus: Training"
	if playerCount >= 3 then
		modeLabel = "Modus: FFA"
	elseif playerCount == 2 then
		modeLabel = "Modus: 1v1 PvP"
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHubFlag,
	}
end

function HubWorldManager.sendLobbyReady(player, inHubFlag)
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player, inHubFlag))
end

function HubWorldManager.spawnInHub(player)
	inHub[player] = true
	teleportPlayer(player, getHubSpawn())
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	teleportPlayer(player, getHubSpawn())
	HubWorldManager.sendLobbyReady(player, true)
	getRemotes().ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	inHub[player] = false
	local arenaSpawn = findArenaSpawn()
	if arenaSpawn then
		teleportPlayer(player, arenaSpawn.Position + Vector3.new(0, 3, 0))
	end
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.onPlayerRemoving(player)
	inHub[player] = nil
end

local function bindZonePrompts()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then return end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then continue end
		local action = prompt:GetAttribute("HubAction")
		if not action then continue end

		prompt.Triggered:Connect(function(player)
			if not HubWorldManager.isInHub(player) then return end
			local r = getRemotes()
			if action == "EnterArena" then
				HubWorldManager.enterArena(player)
				r.EnterArena:FireClient(player)
			elseif action == "OpenBeySelect" then
				r.OpenBeySelect:FireClient(player)
			elseif action == "ShowHallOfFame" then
				HubWorldManager.sendLobbyReady(player, false)
			end
		end)
	end
end

function HubWorldManager.bindRemotes()
	local r = getRemotes()
	bindZonePrompts()

	r.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	r.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	r.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not HubWorldManager.isInHub(player) then return end
		r.OpenBeySelect:FireClient(player)
	end)

	r.ShowHallOfFame.OnServerEvent:Connect(function(player)
		if not HubWorldManager.isInHub(player) then return end
		HubWorldManager.sendLobbyReady(player, false)
	end)
end

function HubWorldManager.onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if inHub[player] == true then
			HubWorldManager.spawnInHub(player)
		elseif inHub[player] == nil then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

return HubWorldManager
