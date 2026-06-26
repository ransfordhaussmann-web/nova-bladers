local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
end

local function ensureRemote(name)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local LobbyReady = ensureRemote("LobbyReady")
local EnterArena = ensureRemote("EnterArena")
local OpenBeySelect = ensureRemote("OpenBeySelect")

local HubWorldManager = {}
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount >= 3 then
		return "Modus: FFA"
	elseif playerCount >= 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function getHubPlayerCount()
	local count = 0
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			count += 1
		end
	end
	return count
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(getHubPlayerCount()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	inArena[player] = nil
end

function HubWorldManager.broadcastLobby()
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			LobbyReady:FireClient(player, buildLobbyPayload(player))
		end
	end
end

function HubWorldManager.sendLobby(player)
	if inArena[player] then return end
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	HubWorldManager.sendLobby(player)
	HubWorldManager.broadcastLobby()
end

function HubWorldManager.onMatchResult(player, won)
	PlayerDataManager.recordMatch(player, won)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	PlayerDataManager.persist(player)
	HubWorldManager.returnToHub(player)
end

function HubWorldManager.isInArena(player)
	return inArena[player] ~= nil
end

local function canUseZone(zoneId)
	local hubCount = getHubPlayerCount()
	if zoneId == "Training" then
		return true
	elseif zoneId == "OneVOne" then
		return hubCount >= 2
	elseif zoneId == "FFA" then
		return hubCount >= 3
	elseif zoneId == "BeySelect" then
		return true
	end
	return false
end

local function enterArena(player, source)
	if inArena[player] then return end
	if source ~= "LobbyButton" and not canUseZone(source) then
		return
	end
	inArena[player] = source
	HubWorldManager.broadcastLobby()
end

local function bindPortal(portal)
	local zoneId = portal:GetAttribute("ZoneId")
	local pad = portal:FindFirstChild("Pad")
	if not pad then return end
	local prompt = pad:FindFirstChild("EnterPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if zoneId == "BeySelect" then
			OpenBeySelect:FireClient(player)
			return
		end
		enterArena(player, zoneId)
	end)
end

function HubWorldManager.init()
	HubWorldBuilder.build()

	for _, portal in HubWorldBuilder.getZonePortals() do
		bindPortal(portal)
	end

	EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player, "LobbyButton")
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		inArena[player] = nil

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not inArena[player] then
					teleportToHub(player)
					HubWorldManager.sendLobby(player)
					HubWorldManager.broadcastLobby()
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
		task.defer(HubWorldManager.broadcastLobby)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.sendLobby(player)
	end
end

return HubWorldManager
