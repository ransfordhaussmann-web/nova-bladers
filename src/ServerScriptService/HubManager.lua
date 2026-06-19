local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubManager = {}

local function getRemotes()
	local folder = ReplicatedStorage:WaitForChild("NovaBladers")
	local remotes = folder:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = folder
	end
	return remotes
end

local function ensureRemote(name, className)
	local remotes = getRemotes()
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = 0,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubManager.init()
	HubWorldBuilder.build()
	ensureRemote("LobbyReady", "RemoteEvent")
	ensureRemote("EnterArena", "RemoteEvent")
	ensureRemote("OpenBeySelect", "RemoteEvent")
	ensureRemote("ReturnToHub", "RemoteEvent")
end

function HubManager.spawnInHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN)
	end
	player:SetAttribute("InHub", true)
end

function HubManager.sendLobbyState(player)
	local payload = buildLobbyPayload(player)
	ensureRemote("LobbyReady", "RemoteEvent"):FireClient(player, payload)
end

function HubManager.onPlayerReady(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubManager.spawnInHub(player)
	HubManager.sendLobbyState(player)
end

function HubManager.enterArena(player)
	player:SetAttribute("InHub", false)
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	local target = HubConfig.ARENA_SPAWN
	if arena then
		local arenaSpawn = arena:FindFirstChild("Spawn", true)
		if arenaSpawn and arenaSpawn:IsA("BasePart") then
			target = arenaSpawn.Position + Vector3.new(0, 3, 0)
		end
	end

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(target)
		end
	end
end

function HubManager.returnToHub(player)
	HubManager.spawnInHub(player)
	HubManager.sendLobbyState(player)
end

return HubManager
