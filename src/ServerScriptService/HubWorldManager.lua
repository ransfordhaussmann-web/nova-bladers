local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playersInHub = {}
local activeZone = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
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

function HubWorldManager.sendLobbyData(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	end
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	activeZone[player] = nil
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyData(player)
	remotes.LeaveHubPanel:FireClient(player)
	remotes.HubZonePrompt:FireClient(player, nil)
end

local function getNearestZone(position)
	local nearestZone
	local nearestDist = HubConfig.ZONE_PROMPT_DISTANCE

	for zoneId, zone in HubConfig.ZONES do
		local dist = (position - zone.position).Magnitude
		if dist <= nearestDist then
			nearestDist = dist
			nearestZone = zone
		end
	end

	return nearestZone
end

local function onZoneChanged(player, zone)
	local previous = activeZone[player]
	if previous == zone then return end
	activeZone[player] = zone

	if zone then
		remotes.HubZonePrompt:FireClient(player, {
			id = zone.id,
			name = zone.name,
			prompt = zone.prompt,
			action = zone.action,
		})
	else
		remotes.HubZonePrompt:FireClient(player, nil)
	end
end

local function trackZones()
	RunService.Heartbeat:Connect(function()
		for player, inHub in playersInHub do
			if inHub and player.Parent then
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					onZoneChanged(player, getNearestZone(hrp.Position))
				end
			end
		end
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	playersInHub[player] = true

	player.CharacterAdded:Connect(function()
		if playersInHub[player] then
			task.defer(function()
				HubWorldManager.teleportToHub(player)
				HubWorldManager.sendLobbyData(player)
			end)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
	HubWorldManager.sendLobbyData(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	activeZone[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.markLeftHub(player)
	playersInHub[player] = nil
	activeZone[player] = nil
	remotes.HubZonePrompt:FireClient(player, nil)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	trackZones()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.markLeftHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
