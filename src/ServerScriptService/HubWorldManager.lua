local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubConfig = require(NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local arenaState = {}
local hubFolder

local function getRemotes()
	return NovaBladers:WaitForChild("Remotes")
end

local function resolveArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
			or arena:FindFirstChild("ArenaSpawn", true)
			or arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		if spawn and spawn:IsA("SpawnLocation") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ARENA_SPAWN)
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
	local board = HubWorldBuilder.findLeaderboardBoard()
	if not board then return end
	local surface = board:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surface then return end
	local list = surface:FindFirstChild("List", true)
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

function HubWorldManager.init()
	hubFolder = HubWorldBuilder.build()
	task.spawn(function()
		while hubFolder and hubFolder.Parent do
			updateLeaderboardBoard(LeaderboardManager.getTop(5))
			task.wait(30)
		end
	end)
end

function HubWorldManager.isInArena(player)
	return arenaState[player] == true
end

function HubWorldManager.teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.returnToHub(player)
	arenaState[player] = nil
	HubWorldManager.teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())

	local remotes = getRemotes()
	local payload = HubWorldManager.buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	updateLeaderboardBoard(payload.leaderboard)
end

function HubWorldManager.sendToArena(player)
	arenaState[player] = true
	HubWorldManager.teleportCharacter(player, resolveArenaSpawn())

	local lobby = player:FindFirstChild("PlayerGui")
		and player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				HubWorldManager.teleportCharacter(player, resolveArenaSpawn())
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	arenaState[player] = nil
	PlayerDataManager.save(player)
end

return HubWorldManager
