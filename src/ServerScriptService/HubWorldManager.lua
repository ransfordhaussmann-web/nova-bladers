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
local zoneById = {}
local playersInHub = {}
local playerZone = {}

for _, zone in HubConfig.ZONES do
	zoneById[zone.id] = zone
end

local function resolveArenaCFrame()
	local arena = Workspace:FindFirstChild("Arena")
	local bowl = arena and arena:FindFirstChild("Bowl")
	local spawn = bowl and bowl:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return HubConfig.ARENA_TELEPORT.fallback
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

local function buildHubPayload(player)
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

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildHubPayload(player))
end

function HubWorldManager.refreshLeaderboardBoard()
	HubWorldBuilder.buildLeaderboardBoard(
		Workspace:FindFirstChild("NovaHub"),
		LeaderboardManager.getTop(5)
	)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = CFrame.new(HubConfig.SPAWN)
	playersInHub[player] = true
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	playersInHub[player] = nil
	playerZone[player] = nil
	root.CFrame = resolveArenaCFrame()
end

local function onZoneEnter(player, zoneId)
	local zone = zoneById[zoneId]
	if not zone or not playersInHub[player] then return end

	playerZone[player] = zoneId
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zone.name,
		hint = zone.hint,
		action = zone.action,
	})
end

local function onZoneLeave(player, zoneId)
	if playerZone[player] == zoneId then
		playerZone[player] = nil
		remotes.HubZoneHint:FireClient(player, { clear = true })
	end
end

local function bindZoneTrigger(trigger)
	local zoneId = trigger:GetAttribute("ZoneId")
	if not zoneId then return end

	local inside = {}

	trigger.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or inside[player] then return end
		inside[player] = true
		onZoneEnter(player, zoneId)
	end)

	trigger.TouchEnded:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or not inside[player] then return end
		inside[player] = nil
		onZoneLeave(player, zoneId)
	end)
end

local function bindZoneTriggers(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end
	for _, zoneFolder in zones:GetChildren() do
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if trigger then
			bindZoneTrigger(trigger)
		end
	end
end

local function onEnterArena(player)
	if not playersInHub[player] then return end
	HubWorldManager.teleportToArena(player)
end

local function onZoneAction(player, action)
	if not playersInHub[player] then return end

	if action == "enter_arena" then
		HubWorldManager.teleportToArena(player)
	elseif action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "view_leaderboard" then
		HubWorldManager.refreshLeaderboardBoard()
		HubWorldManager.sendLobbyReady(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			HubWorldManager.teleportToHub(player)
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	playerZone[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build(LeaderboardManager.getTop(5))

	local hub = Workspace:FindFirstChild("NovaHub")
	if hub then
		bindZoneTriggers(hub)
	end

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.HubZoneAction.OnServerEvent:Connect(onZoneAction)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
