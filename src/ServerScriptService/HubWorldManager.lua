local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubRefs = nil
local remotes = nil
local inArena = {}

local function getRemotes()
	if remotes then
		return remotes
	end
	local folder = NovaBladers:FindFirstChild("Remotes")
	if not folder then
		return nil
	end
	remotes = {
		LobbyReady = folder:WaitForChild("LobbyReady"),
		EnterArena = folder:WaitForChild("EnterArena"),
		OpenBeySelect = folder:WaitForChild("OpenBeySelect"),
		HubBoardUpdate = folder:WaitForChild("HubBoardUpdate"),
	}
	return remotes
end

local function findArenaSpawn()
	for _, name in HubConfig.ARENA_FOLDER_NAMES do
		local arena = workspace:FindFirstChild(name)
		if arena then
			local spawn = arena:FindFirstChild("Spawn", true)
				or arena:FindFirstChild("ArenaSpawn", true)
				or arena:FindFirstChildWhichIsA("SpawnLocation", true)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + HubConfig.TELEPORT_OFFSET
			end
			if arena:IsA("Model") and arena.PrimaryPart then
				return arena.PrimaryPart.CFrame + HubConfig.TELEPORT_OFFSET
			end
		end
	end
	return nil
end

local function formatStatsText(wins, losses, rank, modeLabel)
	return string.format(
		"Wins: %d\nLosses: %d\nRang: %d\n\n%s",
		wins,
		losses,
		rank,
		modeLabel or "Modus: Training"
	)
end

local function formatLeaderboardText(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateBoardParts(statsText, leaderboardText)
	if not hubRefs then
		return
	end
	local statsBody = hubRefs.StatsBoard
		and hubRefs.StatsBoard:FindFirstChild("BoardGui")
		and hubRefs.StatsBoard.BoardGui:FindFirstChild("Root")
		and hubRefs.StatsBoard.BoardGui.Root:FindFirstChild("Body")
	if statsBody then
		statsBody.Text = statsText
	end
	local lbBody = hubRefs.LeaderboardBoard
		and hubRefs.LeaderboardBoard:FindFirstChild("BoardGui")
		and hubRefs.LeaderboardBoard.BoardGui:FindFirstChild("Root")
		and hubRefs.LeaderboardBoard.BoardGui.Root:FindFirstChild("Body")
	if lbBody then
		lbBody.Text = leaderboardText
	end
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, leaderboard)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		hubWorld = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		statsText = formatStatsText(data.Wins, data.Losses, rankPoints, getModeLabel(playerCount)),
		leaderboardText = formatLeaderboardText(leaderboard),
	}
end

function HubWorldManager.broadcastBoards()
	local leaderboard = LeaderboardManager.getTop(5)
	local samplePlayer = Players:GetPlayers()[1]
	local statsText = "Wins: 0\nLosses: 0\nRang: 0\n\nModus: Training"
	if samplePlayer then
		local data = PlayerDataManager.get(samplePlayer)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		statsText = formatStatsText(data.Wins, data.Losses, rankPoints, getModeLabel(#Players:GetPlayers()))
	end
	updateBoardParts(statsText, formatLeaderboardText(leaderboard))

	local remoteFolder = getRemotes()
	if remoteFolder and remoteFolder.HubBoardUpdate then
		remoteFolder.HubBoardUpdate:FireAllClients({
			leaderboardText = formatLeaderboardText(leaderboard),
		})
	end
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local leaderboard = LeaderboardManager.getTop(5)
	local payload = buildLobbyPayload(player, leaderboard)
	updateBoardParts(payload.statsText, payload.leaderboardText)

	local remoteFolder = getRemotes()
	if remoteFolder then
		remoteFolder.LobbyReady:FireClient(player, payload)
		remoteFolder.HubBoardUpdate:FireClient(player, {
			statsText = payload.statsText,
			leaderboardText = payload.leaderboardText,
		})
	end
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	inArena[player] = nil
	root.CFrame = HubConfig.getSpawnCFrame() + HubConfig.TELEPORT_OFFSET
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	local arenaCFrame = findArenaSpawn()
	if arenaCFrame then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = arenaCFrame
		end
	end
end

function HubWorldManager.onMatchResult(player, won)
	PlayerDataManager.recordMatch(player, won)
	PlayerDataManager.persist(player)
	HubWorldManager.returnToHub(player)
	HubWorldManager.broadcastBoards()
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.init()
	hubRefs = HubWorldBuilder.build()

	local remoteFolder = getRemotes()
	if remoteFolder then
		remoteFolder.EnterArena.OnServerEvent:Connect(function(player)
			if HubWorldManager.isInArena(player) then
				return
			end
			HubWorldManager.enterArena(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataManager.load(player)
			HubWorldManager.returnToHub(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			if not HubWorldManager.isInArena(player) then
				task.defer(function()
					HubWorldManager.teleportToHub(player)
					HubWorldManager.sendLobbyReady(player)
				end)
			end
		end)
		if player.Character then
			HubWorldManager.returnToHub(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	Players.PlayerAdded:Connect(function()
		task.defer(HubWorldManager.broadcastBoards)
	end)
end

return HubWorldManager
