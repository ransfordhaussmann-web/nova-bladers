local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local hubFolder
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
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				continue
			end
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
end

local function sendLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	})
end

local function refreshLeaderboardBoard()
	if not hubFolder then return end
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
end

local function onZonePromptTriggered(player, zonePart)
	local action = zonePart:GetAttribute("ZoneAction")
	local zoneName = zonePart.Name
	for _, zone in HubConfig.ZONES do
		if zone.id == zonePart.Name then
			zoneName = zone.name
			break
		end
	end

	if action == "arena" then
		HubWorldManager.enterArena(player)
	elseif action == "beySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "leaderboard" then
		refreshLeaderboardBoard()
	end

	remotes.HubZoneHint:FireClient(player, {
		zoneName = zoneName,
		hint = zonePart:GetAttribute("ZoneHint"),
	})
end

local function bindZonePrompts()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZonePromptTriggered(player, zonePart)
			end)
		end

		zonePart.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end

			local key = player.UserId .. "_" .. zonePart.Name
			if zoneDebounce[key] then return end
			zoneDebounce[key] = true
			task.delay(2, function()
				zoneDebounce[key] = nil
			end)

			local zoneName = zonePart.Name
			for _, zone in HubConfig.ZONES do
				if zone.id == zonePart.Name then
					zoneName = zone.name
					break
				end
			end

			remotes.HubZoneHint:FireClient(player, {
				zoneName = zoneName,
				hint = zonePart:GetAttribute("ZoneHint"),
			})
		end)
	end
end

function HubWorldManager.enterArena(player)
	local spawn = resolveArenaSpawn()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 5, 0)
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyPayload(player, true)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			teleportToHub(player)
			sendLobbyPayload(player, true)
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end
	sendLobbyPayload(player, true)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build(LeaderboardManager.getTop(5))
	bindZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
