local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playerInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = options.inHub ~= false,
		showPanel = options.showPanel == true,
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubConfig.SPAWN_CFRAME
end

local function setHubState(player, inHub)
	playerInHub[player] = inHub
	if remotes and remotes.HubStateChanged then
		remotes.HubStateChanged:FireClient(player, { inHub = inHub })
	end
end

function HubWorldManager.isInHub(player)
	return playerInHub[player] ~= false
end

function HubWorldManager.sendLobbyReady(player, options)
	if not remotes then
		return
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, options))
end

function HubWorldManager.enterArena(player)
	if not playerInHub[player] then
		return
	end
	setHubState(player, false)
end

function HubWorldManager.returnToHub(player)
	setHubState(player, true)
	teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	setHubState(player, true)

	player.CharacterAdded:Connect(function()
		if playerInHub[player] then
			task.defer(teleportToHub, player)
		end
	end)

	task.defer(function()
		HubWorldManager.sendLobbyReady(player)
	end)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerInHub[player] = nil
end

local function onEnterArena(player)
	HubWorldManager.enterArena(player)
end

local function onReturnToHub(player)
	HubWorldManager.returnToHub(player)
end

local function onOpenBeySelect(player)
	if not remotes then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end

local function wireZonePrompts()
	if not hubModel then
		return
	end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, pad in zones:GetChildren() do
		local prompt = pad:FindFirstChild("ZonePrompt")
		if not prompt then
			continue
		end
		prompt.Triggered:Connect(function(player)
			local action = prompt:GetAttribute("HubAction")
			if action == "EnterArena" then
				onEnterArena(player)
			elseif action == "OpenBeySelect" then
				onOpenBeySelect(player)
			elseif action == "ShowLeaderboard" then
				HubWorldManager.sendLobbyReady(player, { inHub = true, showPanel = true })
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	wireZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.ReturnToHub.OnServerEvent:Connect(onReturnToHub)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
