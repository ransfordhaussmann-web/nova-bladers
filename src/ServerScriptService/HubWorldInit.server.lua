local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
end

local function ensureRemote(name, className)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local LobbyReady = ensureRemote("LobbyReady", "RemoteEvent")
local EnterArena = ensureRemote("EnterArena", "RemoteEvent")
local OpenBeySelect = ensureRemote("OpenBeySelect", "RemoteEvent")
local HubZoneTouched = ensureRemote("HubZoneTouched", "RemoteEvent")

local ZONE_COOLDOWN = 1.5
local zoneCooldowns = {}

local arenaEntrySignal = script.Parent:FindFirstChild("ArenaEntryRequested")
if not arenaEntrySignal then
	arenaEntrySignal = Instance.new("BindableEvent")
	arenaEntrySignal.Name = "ArenaEntryRequested"
	arenaEntrySignal.Parent = script.Parent
end

local function requestArenaEntry(player)
	HubWorldManager.sendToArena(player)
	arenaEntrySignal:Fire(player)
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	})
end

local function canUseZone(player, zoneKey)
	local key = player.UserId .. "_" .. zoneKey
	local now = os.clock()
	if zoneCooldowns[key] and now - zoneCooldowns[key] < ZONE_COOLDOWN then
		return false
	end
	zoneCooldowns[key] = now
	return true
end

local function onZoneTouch(zoneKey, hit)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or HubWorldManager.isInArena(player) then
		return
	end
	if not canUseZone(player, zoneKey) then
		return
	end

	if zoneKey == "Arena" then
		requestArenaEntry(player)
		HubZoneTouched:FireClient(player, "Arena")
	elseif zoneKey == "BeySelect" then
		OpenBeySelect:FireClient(player)
		HubZoneTouched:FireClient(player, "BeySelect")
	elseif zoneKey == "Leaderboard" then
		sendLobbyReady(player)
		HubZoneTouched:FireClient(player, "Leaderboard")
	end
end

local function connectZonePads()
	for zoneKey in HubWorldConfig.ZONES do
		local pad = HubWorldManager.getZonePart(zoneKey)
		if pad then
			pad.Touched:Connect(function(hit)
				onZoneTouch(zoneKey, hit)
			end)
		end
	end
end

HubWorldManager.build()
connectZonePads()

EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	requestArenaEntry(player)
end)

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not HubWorldManager.isInArena(player) then
				HubWorldManager.teleportToHub(player)
				sendLobbyReady(player)
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
	sendLobbyReady(player)
end
