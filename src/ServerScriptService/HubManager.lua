local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldConfig = require(NovaBladers.HubWorldConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubManager = {}

local remotes
local inArena = {}
local hubRefs

local function ensureRemotes()
	local folder = NovaBladers:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = NovaBladers
	end

	local function getRemote(name)
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote
	end

	return {
		LobbyReady = getRemote("LobbyReady"),
		EnterArena = getRemote("EnterArena"),
		ReturnToHub = getRemote("ReturnToHub"),
	}
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

local function getPlayerRank(player, rankPoints)
	local ok, pages = pcall(function()
		return game:GetService("DataStoreService")
			:GetOrderedDataStore("NovaBladers_GlobalRank_v1")
			:GetSortedAsync(false, 100)
	end)
	if not ok or not pages then
		return 0
	end

	for rank, item in pages:GetCurrentPage() do
		if tonumber(item.key) == player.UserId then
			return rank
		end
	end
	return 0
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player, rankPoints),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

function HubManager.isInArena(player)
	return inArena[player] == true
end

function HubManager.sendToHub(player)
	inArena[player] = nil
	teleportCharacter(player, HubWorldConfig.getSpawnPosition())
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubManager.sendToArena(player)
	inArena[player] = true
	teleportCharacter(player, HubWorldConfig.ARENA_SPAWN)
end

function HubManager.refreshLobby(player)
	if inArena[player] then
		return
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubManager.init()
	remotes = ensureRemotes()
	hubRefs = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inArena[player] then
			return
		end
		HubManager.sendToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubManager.sendToHub(player)
	end)

	local function onCharacterAdded()
		task.defer(function()
			if inArena[player] then
				teleportCharacter(player, HubWorldConfig.ARENA_SPAWN)
			else
				HubManager.sendToHub(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			onCharacterAdded()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.persist(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		if player.Character then
			HubManager.sendToHub(player)
		end
	end

	return hubRefs
end

return HubManager
