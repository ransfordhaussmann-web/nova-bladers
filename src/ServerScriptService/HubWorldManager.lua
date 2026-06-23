local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local inArena = {}
local remotes

local function getArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end
	local bowl = arena:FindFirstChild("Bowl")
	if not bowl then return nil end
	local spawn = bowl:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return nil
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

local function updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if list then
		list.Text = formatLeaderboard(entries)
	end
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

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = not inArena[player],
	})
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	inArena[player] = nil
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.enterArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnCFrame = getArenaSpawn()
	if not spawnCFrame then
		warn("[NovaBladers] Arena spawn not found — add Workspace.Arena.Bowl.Spawn")
		return
	end

	inArena[player] = true
	root.CFrame = spawnCFrame
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

function HubWorldManager.handleZoneAction(player, action)
	if action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(5)
	updateLeaderboardBoard(entries)
	return entries
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			HubWorldManager.handleZoneAction(player, action)
		end
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				HubWorldManager.teleportToHub(player)
			end
		end)

		if player.Character then
			task.defer(function()
				HubWorldManager.teleportToHub(player)
			end)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	HubWorldManager.refreshLeaderboard()
end

return HubWorldManager
