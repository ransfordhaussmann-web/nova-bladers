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
local hubModel
local inHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function getZoneById(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

function HubWorldManager.buildLobbyPayload(player)
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

function HubWorldManager.setHubState(player, isInHub)
	inHub[player] = isInHub
	remotes.HubStateChanged:FireClient(player, { inHub = isInHub })
end

function HubWorldManager.isInHub(player)
	return inHub[player] ~= false
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	root.CFrame = HubConfig.SPAWN + CFrame.new(HubConfig.ORIGIN)
	HubWorldManager.setHubState(player, true)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.enterArena(player)
	if not HubWorldManager.isInHub(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	root.CFrame = HubConfig.ARENA_ENTRY
	HubWorldManager.setHubState(player, false)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

local function onZoneTriggered(player, zoneId)
	if not HubWorldManager.isInHub(player) then
		return
	end

	local zone = getZoneById(zoneId)
	if not zone then
		return
	end

	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showStats" then
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end
end

local function wireZonePrompts()
	if not hubModel then
		return
	end

	for _, descendant in hubModel:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Parent then
			local zoneId = descendant.Parent:GetAttribute("ZoneId")
			if zoneId then
				descendant.Triggered:Connect(function(player)
					onZoneTriggered(player, zoneId)
				end)
			end
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	inHub[player] = true

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInHub(player) then
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onPlayerRemoving(player)
	inHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	hubModel = HubWorldBuilder.build()
	wireZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
