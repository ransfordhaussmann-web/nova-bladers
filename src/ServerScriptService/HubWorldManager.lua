local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hub
local remotes

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
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

function HubWorldManager.getHub()
	return hub
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	if not hub then return end
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubWorldBuilder.getSpawnCFrame(hub)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
	remotes.HubReturned:FireClient(player)
end

function HubWorldManager.onPlayerReady(player)
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

	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure(NovaBladers)
	hub = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if typeof(_G.NovaBladersStartArena) == "function" then
			_G.NovaBladersStartArena(player)
		end
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		remotes.OpenBeySelect:FireClient(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		HubWorldManager.onPlayerReady(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerReady(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
