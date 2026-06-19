local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
local inHub = {}
local inArena = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getHubSpawn()
	if not hub then return nil end
	return hub:FindFirstChild(HubConfig.SPAWN_NAME)
end

local function buildLobbyPayload(player, options)
	options = options or {}
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
		inHub = options.inHub ~= false,
		showStats = options.showStats == true,
	}
end

local function teleportCharacter(character, targetCFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character
	if not character then return end
	local spawnPart = getHubSpawn()
	if not spawnPart then return end
	teleportCharacter(character, spawnPart.CFrame)
	inHub[player] = true
	inArena[player] = nil
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, { inHub = true, showStats = false }))
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	inHub[player] = true
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	local arenaSpawn = resolveArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — HubWorldManager.teleportToArena")
		return false
	end
	local character = player.Character
	if not character then return false end
	teleportCharacter(character, arenaSpawn.CFrame)
	inHub[player] = nil
	inArena[player] = true
	return true
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.handleZoneAction(player, action)
	if action == "enterArena" then
		HubWorldManager.teleportToArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, { inHub = true, showStats = true }))
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				HubWorldManager.teleportToArena(player)
			else
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	inHub[player] = nil
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		HubWorldManager.handleZoneAction(player, action)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
