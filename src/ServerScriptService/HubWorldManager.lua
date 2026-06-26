local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local HubWorldManager = {}
HubWorldManager.hub = nil
HubWorldManager.remotes = nil

local function ensureRemotes()
	local folder = NovaBladers:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = NovaBladers
	end

	local function remote(name)
		local existing = folder:FindFirstChild(name)
		if existing then return existing end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end

	return {
		LobbyReady = remote("LobbyReady"),
		EnterArena = remote("EnterArena"),
		OpenBeySelect = remote("OpenBeySelect"),
		HubBoardUpdate = remote("HubBoardUpdate"),
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

local function updateLeaderboardBoard(entries)
	if not HubWorldManager.hub then return end
	local board = HubWorldManager.hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local body = gui:FindFirstChild("LeaderboardBody", true)
	if body then
		body.Text = HubWorldBuilder.formatLeaderboard(entries)
	end
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

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(5)
	updateLeaderboardBoard(entries)
	if HubWorldManager.remotes then
		HubWorldManager.remotes.HubBoardUpdate:FireAllClients({
			leaderboardText = HubWorldBuilder.formatLeaderboard(entries),
		})
	end
	return entries
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not HubWorldManager.hub then return end
	root.CFrame = HubWorldBuilder.getSpawnCFrame(HubWorldManager.hub)
	player:SetAttribute("InHub", true)
end

function HubWorldManager.sendLobbyReady(player)
	local payload = HubWorldManager.buildLobbyPayload(player)
	if HubWorldManager.remotes then
		HubWorldManager.remotes.LobbyReady:FireClient(player, payload)
	end

	local statsText = HubWorldBuilder.formatStats(payload.wins, payload.losses, payload.rank)
	if HubWorldManager.remotes then
		HubWorldManager.remotes.HubBoardUpdate:FireClient(player, {
			statsText = statsText,
			leaderboardText = HubWorldBuilder.formatLeaderboard(payload.leaderboard),
		})
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onMatchResult(player, won)
	PlayerDataManager.recordMatch(player, won)
	PlayerDataManager.persist(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.refreshLeaderboard()
	HubWorldManager.returnToHub(player)
end

function HubWorldManager.requestEnterArena(player)
	if not player:GetAttribute("InHub") then return end
	player:SetAttribute("InHub", false)

	local bindable = ServerScriptService:FindFirstChild("ArenaRequested")
	if bindable and bindable:IsA("BindableEvent") then
		bindable:Fire(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player:SetAttribute("InHub", true)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player:GetAttribute("InHub") then
				HubWorldManager.teleportToHub(player)
				HubWorldManager.sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
	HubWorldManager.sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	HubWorldManager.remotes = ensureRemotes()
	HubWorldManager.hub = HubWorldBuilder.build(HubConfig.HUB_ORIGIN)
	HubWorldManager.refreshLeaderboard()

	HubWorldManager.remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.requestEnterArena(player)
	end)

	HubWorldManager.remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not player:GetAttribute("InHub") then return end
		HubWorldManager.remotes.OpenBeySelect:FireClient(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(HubConfig.LEADERBOARD_REFRESH)
			HubWorldManager.refreshLeaderboard()
		end
	end)
end

return HubWorldManager
