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
local hub
local playersInHub = {}
local zoneDebounce = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function resolveArenaSpawn()
	for _, path in ipairs(HubConfig.ARENA_SPAWN_PATHS) do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				continue
			end
			current = current and current:FindFirstChild(segment)
		end
		if current then
			if current:IsA("BasePart") then
				return current.CFrame + Vector3.new(0, 3, 0)
			elseif current:IsA("SpawnLocation") then
				return current.CFrame + Vector3.new(0, 3, 0)
			elseif current:IsA("Model") and current.PrimaryPart then
				return current.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("Arena")
	if bowl then
		local part = bowl:IsA("BasePart") and bowl or bowl:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.CFrame + Vector3.new(0, 6, 0)
		end
	end

	return CFrame.new(0, 8, 0)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	local rank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		rankPoints = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	}
end

local function updateLeaderboardBoard()
	local content = HubWorldBuilder.getLeaderboardGui()
	if not content then return end
	local entries = content:FindFirstChild("Entries")
	if not entries then return end
	entries.Text = HubWorldBuilder.formatLeaderboard(LeaderboardManager.getTop(5))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubConfig.SPAWN
	playersInHub[player] = true
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	local payload = buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	updateLeaderboardBoard()
end

local function enterArena(player)
	playersInHub[player] = nil
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = resolveArenaSpawn()
end

local function onZoneTouch(player, trigger)
	if not playersInHub[player] then return end

	local key = player.UserId .. ":" .. trigger:GetAttribute("ZoneId")
	if zoneDebounce[key] then return end
	zoneDebounce[key] = true
	task.delay(1.5, function()
		zoneDebounce[key] = nil
	end)

	local action = trigger:GetAttribute("Action")
	if action == "EnterArena" then
		enterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowLeaderboard" then
		updateLeaderboardBoard()
	end
end

local function bindZoneTriggers()
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, zone in zones:GetChildren() do
		local trigger = zone:FindFirstChild("Trigger")
		if trigger then
			trigger.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				if not character then return end
				local player = Players:GetPlayerFromCharacter(character)
				if player then
					onZoneTouch(player, trigger)
				end
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playersInHub[player] ~= false then
				teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end

	local payload = buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	updateLeaderboardBoard()
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	zoneDebounce[player.UserId] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()
	bindZoneTriggers()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			enterArena(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	updateLeaderboardBoard()
end

return HubWorldManager
