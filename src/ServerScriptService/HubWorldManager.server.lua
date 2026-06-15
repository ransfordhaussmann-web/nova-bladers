local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
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
local ReturnToHub = ensureRemote("ReturnToHub")

local hub = HubWorldBuilder.build()
local playersInMatch = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA (" .. count .. " Spieler)"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function formatLeaderboard(entries)
	local lines = { "🏆 Top Spieler" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return lines
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboard(hub, formatLeaderboard(entries))
	return entries
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(HubWorldConfig.SPAWN)
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = refreshLeaderboardBoard()

	LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		hubWorld = true,
	})
end

local function enterArenaFor(player)
	if playersInMatch[player] then return end
	playersInMatch[player] = true
	EnterArena:FireClient(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(PlayerDataManager.get(player)))

	player.CharacterAdded:Connect(function()
		if playersInMatch[player] then return end
		task.defer(function()
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end)

	if player.Character then
		task.defer(function()
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end
end

local function bindZonePrompts()
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, pad in zones:GetChildren() do
		if not pad:IsA("BasePart") then
			continue
		end
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			continue
		end

		prompt.Triggered:Connect(function(player)
			if playersInMatch[player] then return end
			local action = pad:GetAttribute("HubZone")
			if action == "enterArena" then
				enterArenaFor(player)
			elseif action == "beySelect" then
				OpenBeySelect:FireClient(player)
			end
		end)
	end
end

EnterArena.OnServerEvent:Connect(enterArenaFor)

ReturnToHub.OnServerEvent:Connect(function(player)
	playersInMatch[player] = nil
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	teleportToHub(player)
	sendLobbyReady(player)
	ReturnToHub:FireClient(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	playersInMatch[player] = nil
	PlayerDataManager.save(player)
end)

bindZonePrompts()
