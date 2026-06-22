local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local hubBuilt = false
local inArena = {}

local function getZoneById(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function isNearZone(character, zone)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local delta = root.Position - zone.position
	return delta.Magnitude <= HubConfig.PROXIMITY_RANGE
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local arenaSpawn = workspace:FindFirstChild("ArenaSpawn")
	if arenaSpawn and arenaSpawn:IsA("BasePart") then
		return arenaSpawn.CFrame + Vector3.new(0, 3, 0)
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl then
		local part = if bowl:IsA("BasePart") then bowl else bowl:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.CFrame + Vector3.new(0, 5, 0)
		end
	end

	return CFrame.new(0, 10, 0)
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then
		return
	end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end
	local gui = board:FindFirstChildWhichIsA("SurfaceGui")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

local function sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()

	RemotesSetup.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		inHub = inHub,
	})
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	inArena[player] = nil
	sendLobbyReady(player, true)
end

function HubWorldManager.ensureHub()
	if hubBuilt then
		return
	end
	HubWorldBuilder.build()
	hubBuilt = true
	updateLeaderboardBoard(LeaderboardManager.getTop(5))
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
end

function HubWorldManager.onPlayerAdded(player)
	HubWorldManager.ensureHub()
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if inArena[player] then
			return
		end
		teleportToHub(player)
	end)

	if player.Character then
		task.defer(function()
			if not inArena[player] then
				teleportToHub(player)
			end
		end)
	end

	sendLobbyReady(player, true)
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

local function enterArena(player)
	if inArena[player] then
		return
	end
	local character = player.Character
	local zone = getZoneById("arena_gate")
	if zone and not isNearZone(character, zone) then
		return
	end

	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	inArena[player] = true
	root.CFrame = findArenaSpawnCFrame()
	sendLobbyReady(player, false)
end

local function openBeySelect(player)
	local character = player.Character
	local zone = getZoneById("bey_lab")
	if zone and not isNearZone(character, zone) then
		return
	end
	RemotesSetup.OpenBeySelect:FireClient(player)
end

local function showLeaderboard(player)
	local character = player.Character
	local zone = getZoneById("hall_of_fame")
	if zone and not isNearZone(character, zone) then
		return
	end
	local entries = LeaderboardManager.getTop(5)
	updateLeaderboardBoard(entries)
	RemotesSetup.HubZoneHint:FireClient(player, {
		zoneId = "hall_of_fame",
		title = "Ruhmeshalle",
		lines = entries,
	})
end

function HubWorldManager.init()
	HubWorldManager.ensureHub()

	RemotesSetup.EnterArena.OnServerEvent:Connect(enterArena)
	RemotesSetup.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	RemotesSetup.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		local zone = getZoneById(zoneId)
		if not zone or not isNearZone(player.Character, zone) then
			return
		end
		if zone.action == "enter_arena" then
			enterArena(player)
		elseif zone.action == "open_bey_select" then
			openBeySelect(player)
		elseif zone.action == "show_leaderboard" then
			showLeaderboard(player)
		end
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(HubWorldManager.onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(30)
			updateLeaderboardBoard(LeaderboardManager.getTop(5))
		end
	end)
end

return HubWorldManager
