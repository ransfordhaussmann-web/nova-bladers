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

local function getRemotes()
	if remotes then return remotes end
	local folder = NovaBladers:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = NovaBladers
	end
	remotes = RemotesSetup.ensure(folder)
	return remotes
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_PATHS do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
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

local function findPlayerRank(userId, leaderboard)
	for _, entry in leaderboard do
		if entry.userId == userId then
			return entry.rank
		end
	end
	return 0
end

local function teleportCharacter(character, position)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(position)
	end
end

function HubWorldManager.refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboard(entries)
end

function HubWorldManager.sendLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local leaderboard = LeaderboardManager.getTop(5)

	getRemotes().LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = findPlayerRank(player.UserId, leaderboard),
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub ~= false,
	})
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if character then
		teleportCharacter(character, HubConfig.SPAWN_POSITION)
	end
end

function HubWorldManager.enterArena(player)
	local character = player.Character
	if not character then return end

	local spawn = findArenaSpawn()
	if spawn then
		teleportCharacter(character, spawn.Position + Vector3.new(0, 3, 0))
	else
		teleportCharacter(character, Vector3.new(0, 8, 80))
	end

	getRemotes().LobbyReady:FireClient(player, {
		wins = PlayerDataManager.get(player).Wins,
		losses = PlayerDataManager.get(player).Losses,
		rank = 0,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = false,
	})
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyPayload(player, true)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	HubWorldManager.refreshLeaderboardBoard()

	local function onCharacter(character)
		task.defer(function()
			HubWorldManager.teleportToHub(player)
			HubWorldManager.sendLobbyPayload(player, true)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function HubWorldManager.init()
	HubWorldBuilder.build()
	getRemotes()

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	getRemotes().HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if zoneId == "ArenaGate" then
			HubWorldManager.enterArena(player)
		elseif zoneId == "BeyLab" then
			getRemotes().OpenBeySelect:FireClient(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
