local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playerZones = {}

local function getRemotes()
	if remotes then return remotes end
	remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	return remotes
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

local function resolveArenaSpawn()
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("BasePart") then
		return node.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 6, 0)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.getHubSpawnCFrame()
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

function HubWorldManager.refreshLeaderboard()
	if not hubModel then return end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.createLeaderboardBoard(hubModel, entries)
end

function HubWorldManager.sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	local playerRank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			playerRank = entry.rank
			break
		end
	end

	getRemotes().LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = playerRank,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub ~= false,
	})
end

function HubWorldManager.returnToHub(player)
	teleportCharacter(player, HubWorldManager.getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player, true)
end

local function zoneContains(zonePart, position)
	local relative = zonePart.CFrame:PointToObjectSpace(position)
	local half = zonePart.Size / 2
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Y) <= half.Y + 4
		and math.abs(relative.Z) <= half.Z
end

local function findZoneAt(position)
	if not hubModel then return nil end
	for _, zoneCfg in HubConfig.ZONES do
		local zonePart = hubModel:FindFirstChild(zoneCfg.id)
		if zonePart and zoneContains(zonePart, position) then
			return zonePart
		end
	end
	return nil
end

local function handleZoneAction(player, action)
	if action == "enter_arena" then
		teleportCharacter(player, resolveArenaSpawn())
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			local lobby = gui:FindFirstChild("Lobby")
			if lobby then lobby.Enabled = false end
		end
	elseif action == "open_bey_select" then
		getRemotes().OpenBeySelect:FireClient(player)
	end
end

local function pollZones()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local zonePart = findZoneAt(root.Position)
		local zoneId = zonePart and zonePart:GetAttribute("ZoneId") or nil
		local previous = playerZones[player]

		if zoneId ~= previous then
			playerZones[player] = zoneId
			if zonePart then
				getRemotes().HubZoneHint:FireClient(player, {
					zoneId = zoneId,
					name = zonePart:GetAttribute("ZoneName"),
					hint = zonePart:GetAttribute("ZoneHint"),
					action = zonePart:GetAttribute("ZoneAction"),
					actionLabel = zonePart:GetAttribute("ZoneActionLabel"),
				})
			else
				getRemotes().HubZoneHint:FireClient(player, nil)
			end
		end
	end
end

function HubWorldManager.init()
	hubModel = HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboard()

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		teleportCharacter(player, resolveArenaSpawn())
	end)

	getRemotes().HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		local zoneId = playerZones[player]
		if not zoneId then return end

		local zonePart = hubModel:FindFirstChild(zoneId)
		if not zonePart or zonePart:GetAttribute("ZoneAction") ~= action then return end
		handleZoneAction(player, action)
	end)

	task.spawn(function()
		while true do
			pollZones()
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
		end
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	local function onCharacter()
		task.defer(function()
			teleportCharacter(player, HubWorldManager.getHubSpawnCFrame())
			HubWorldManager.sendLobbyReady(player, true)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playerZones[player] = nil
	PlayerDataManager.save(player)
	HubWorldManager.refreshLeaderboard()
end

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player)
end

return HubWorldManager
