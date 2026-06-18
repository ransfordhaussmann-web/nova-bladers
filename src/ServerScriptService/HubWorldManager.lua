local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hub
local remotes
local inArena = {}
local viewingStats = {}

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = workspace
		for _, name in path do
			current = current and current:FindFirstChild(name)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function formatLeaderboardLines(entries)
	local lines = { "🏆 Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return lines
end

local function refreshLeaderboardBoard()
	if not hub then
		return
	end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(hub, formatLeaderboardLines(entries))
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local entries = LeaderboardManager.getTop(5)
	local playerRank = 0
	for _, entry in entries do
		if entry.name == player.Name then
			playerRank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = playerRank,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = entries,
		inHub = not inArena[player] and not viewingStats[player],
	}
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then
		return
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not hub then
		return
	end
	inArena[player] = nil
	viewingStats[player] = nil
	root.CFrame = HubWorldBuilder.getSpawnCFrame(hub)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

local function enterArena(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — HubWorldManager.enterArena")
		return
	end

	inArena[player] = true
	viewingStats[player] = nil
	root.CFrame = arenaSpawn.CFrame + Vector3.new(0, 3, 0)
	HubWorldManager.sendLobbyReady(player)
end

local function openBeySelect(player)
	if not remotes then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, action)
	if action == "EnterArena" then
		enterArena(player)
	elseif action == "OpenBeySelect" then
		openBeySelect(player)
	elseif action == "ViewStats" then
		if viewingStats[player] then
			viewingStats[player] = nil
			HubWorldManager.sendLobbyReady(player)
		else
			viewingStats[player] = true
			local payload = buildLobbyPayload(player)
			payload.inHub = false
			remotes.LobbyReady:FireClient(player, payload)
		end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			handleZoneAction(player, action)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if inArena[player] then
					local arenaSpawn = findArenaSpawn()
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if arenaSpawn and root then
						root.CFrame = arenaSpawn.CFrame + Vector3.new(0, 3, 0)
					end
				else
					HubWorldManager.teleportToHub(player)
				end
			end)
		end)

		task.defer(function()
			refreshLeaderboardBoard()
			HubWorldManager.sendLobbyReady(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
		viewingStats[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
	end
end

return HubWorldManager
