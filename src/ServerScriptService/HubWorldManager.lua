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
local playerZones = {}
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

function HubWorldManager.sendLobbyPanel(player, show)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player), show)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubConfig.SPAWN_CFRAME + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	end
	inArena[player] = nil
	HubWorldManager.sendLobbyPanel(player, HubConfig.SHOW_LOBBY_PANEL_ZONES.Spawn)
	remotes.HubZoneChanged:FireClient(player, "Spawn")
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubConfig.ARENA_ENTRY_CFRAME
	end
	inArena[player] = true
	remotes.HubZoneChanged:FireClient(player, "Arena")
end

local function zoneFromPosition(position)
	local bestId
	local bestDist = math.huge
	for _, zone in HubConfig.ZONES do
		local center = HubConfig.ORIGIN + zone.center
		local half = zone.size / 2
		local inside = math.abs(position.X - center.X) <= half.X
			and math.abs(position.Z - center.Z) <= half.Z
		if inside then
			local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestId = zone.id
			end
		end
	end
	return bestId
end

local function onZoneChanged(player, zoneId)
	if inArena[player] then
		return
	end
	local previous = playerZones[player]
	if previous == zoneId then
		return
	end
	playerZones[player] = zoneId
	remotes.HubZoneChanged:FireClient(player, zoneId)

	local showPanel = zoneId and HubConfig.SHOW_LOBBY_PANEL_ZONES[zoneId]
	if showPanel then
		HubWorldManager.sendLobbyPanel(player, true)
	else
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player), false)
	end
end

local function trackPlayerZone(player)
	task.spawn(function()
		while player.Parent do
			if not inArena[player] then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					onZoneChanged(player, zoneFromPosition(root.Position))
				end
			end
			task.wait(0.35)
		end
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if inArena[player] then
			HubWorldManager.teleportToArena(player)
		else
			HubWorldManager.teleportToHub(player)
		end
	end)

	trackPlayerZone(player)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

function HubWorldManager.init(prompts)
	remotes = RemotesSetup.ensure()
	if prompts then
		HubWorldManager.bindPrompts(prompts)
	else
		local _, builtPrompts = HubWorldBuilder.build()
		HubWorldManager.bindPrompts(builtPrompts)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function HubWorldManager.bindPrompts(prompts)
	if prompts.ArenaGate then
		prompts.ArenaGate.Triggered:Connect(function(player)
			HubWorldManager.teleportToArena(player)
		end)
	end
	if prompts.BeyLab then
		prompts.BeyLab.Triggered:Connect(function(player)
			remotes.OpenBeySelect:FireClient(player)
		end)
	end
	if prompts.HallOfFame then
		prompts.HallOfFame.Triggered:Connect(function(player)
			HubWorldManager.sendLobbyPanel(player, true)
		end)
	end
end

return HubWorldManager
