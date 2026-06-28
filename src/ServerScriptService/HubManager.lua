local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubManager = {}

local remotes = nil
local zones = nil
local playersInArena = {}

local function ensureRemotes()
	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = ReplicatedStorage
	end

	local folder = root:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root
	end

	local function ensureRemote(name, className)
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	end

	return {
		LobbyReady = ensureRemote("LobbyReady", "RemoteEvent"),
		EnterArena = ensureRemote("EnterArena", "RemoteEvent"),
		ReturnToHub = ensureRemote("ReturnToHub", "RemoteEvent"),
		HubZoneHighlight = ensureRemote("HubZoneHighlight", "RemoteEvent"),
	}
end

local function zoneForMode(mode: string)
	for _, zone in HubConfig.ZONES do
		if zone.mode == mode then
			return zone
		end
	end
	return HubConfig.ZONES.Training
end

local function getModeLabel(playerCount: number): string
	if playerCount >= 3 then
		return HubConfig.ZONES.FFA.modeLabel
	elseif playerCount == 2 then
		return HubConfig.ZONES.Duel.modeLabel
	end
	return HubConfig.ZONES.Training.modeLabel
end

local function teleportToHub(player: Player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
	playersInArena[player] = nil
end

local function teleportToArena(player: Player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.ARENA_ORIGIN)
	playersInArena[player] = true
end

local function sendLobbyReady(player: Player, preferredModeLabel: string?)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = preferredModeLabel or getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not playersInArena[player],
	})
end

local function enterArena(player: Player, mode: string?)
	if playersInArena[player] then return end

	local resolvedMode = mode
	if not resolvedMode then
		local count = #Players:GetPlayers()
		if count >= 3 then
			resolvedMode = HubConfig.ZONES.FFA.mode
		elseif count == 2 then
			resolvedMode = HubConfig.ZONES.Duel.mode
		else
			resolvedMode = HubConfig.ZONES.Training.mode
		end
	end

	teleportToArena(player)
	local zone = zoneForMode(resolvedMode)
	remotes.LobbyReady:FireClient(player, {
		wins = PlayerDataManager.get(player).Wins,
		losses = PlayerDataManager.get(player).Losses,
		rank = PlayerDataManager.getRankPoints(PlayerDataManager.get(player)),
		modeLabel = zone.modeLabel,
		leaderboard = LeaderboardManager.getTop(5),
		inHub = false,
		arenaMode = resolvedMode,
	})
end

local function connectZonePrompts()
	for zoneId, zone in zones do
		zone.prompt.Triggered:Connect(function(player)
			enterArena(player, zone.config.mode)
		end)

		zone.pad.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player or playersInArena[player] then return end
			remotes.HubZoneHighlight:FireClient(player, {
				zoneId = zoneId,
				modeLabel = zone.config.modeLabel,
			})
		end)
	end
end

local function onPlayerAdded(player: Player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playersInArena[player] then
				teleportToArena(player)
			else
				teleportToHub(player)
				sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		teleportToHub(player)
		sendLobbyReady(player)
	end
end

local function onPlayerRemoving(player: Player)
	PlayerDataManager.save(player)
	playersInArena[player] = nil
end

function HubManager.init()
	remotes = ensureRemotes()
	_, zones = HubWorldBuilder.build()
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player, mode)
		enterArena(player, mode)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		teleportToHub(player)
		sendLobbyReady(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubManager
