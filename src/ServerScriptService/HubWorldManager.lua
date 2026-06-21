local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}
HubWorldManager._hub = nil
HubWorldManager._remotes = nil
HubWorldManager._leaderboardManager = nil
HubWorldManager._playerDataManager = nil
HubWorldManager._modeResolver = nil

function HubWorldManager.configure(deps)
	HubWorldManager._leaderboardManager = deps.leaderboardManager
	HubWorldManager._playerDataManager = deps.playerDataManager
	HubWorldManager._modeResolver = deps.modeResolver
end

function HubWorldManager.getRemotes()
	if not HubWorldManager._remotes then
		HubWorldManager._remotes = RemotesSetup.ensure()
	end
	return HubWorldManager._remotes
end

function HubWorldManager.ensureHub()
	if HubWorldManager._hub and HubWorldManager._hub.Parent then
		return HubWorldManager._hub
	end
	HubWorldManager._hub = HubWorldBuilder.build()
	return HubWorldManager._hub
end

function HubWorldManager.getHubSpawnCFrame()
	local hub = HubWorldManager.ensureHub()
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN)
end

function HubWorldManager.findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = folder:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
			local bowl = folder:FindFirstChild("Bowl") or folder
			if bowl:IsA("BasePart") then
				return bowl.CFrame + Vector3.new(0, 6, 0)
			end
		end
	end
	return nil
end

function HubWorldManager.getModeLabel()
	if HubWorldManager._modeResolver then
		return HubWorldManager._modeResolver()
	end
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.buildLeaderboardLines()
	local lines = { "Top Spieler:" }
	if not HubWorldManager._leaderboardManager then
		table.insert(lines, "Keine Daten")
		return lines
	end

	local entries = HubWorldManager._leaderboardManager.getTop(5)
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return lines
end

function HubWorldManager.refreshLeaderboardBoard()
	local hub = HubWorldManager.ensureHub()
	HubWorldBuilder.buildLeaderboardBoard(hub, HubWorldManager.buildLeaderboardLines())
end

function HubWorldManager.buildLobbyPayload(player)
	local data = HubWorldManager._playerDataManager and HubWorldManager._playerDataManager.get(player)
	local wins = data and data.Wins or 0
	local losses = data and data.Losses or 0
	local rankPoints = HubWorldManager._playerDataManager
		and HubWorldManager._playerDataManager.getRankPoints(data)
		or 0

	local rank = 0
	local leaderboard = HubWorldManager._leaderboardManager
		and HubWorldManager._leaderboardManager.getTop(5)
		or {}

	for _, entry in leaderboard do
		if entry.points == rankPoints then
			rank = entry.rank
			break
		end
	end

	return {
		inHub = true,
		wins = wins,
		losses = losses,
		rank = rank,
		modeLabel = HubWorldManager.getModeLabel(),
		leaderboard = leaderboard,
	}
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubWorldManager.getHubSpawnCFrame()
	end
end

function HubWorldManager.sendLobbyReady(player)
	local remotes = HubWorldManager.getRemotes()
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.teleportToArena(player)
	local target = HubWorldManager.findArenaSpawn()
	if not target then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — HubWorldManager")
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = target
	end
	return true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onPlayerAdded(player)
	if HubWorldManager._playerDataManager then
		HubWorldManager._playerDataManager.load(player)
	end

	local function handleCharacter()
		HubWorldManager.spawnInHub(player)
		HubWorldManager.sendLobbyReady(player)
	end

	if player.Character then
		handleCharacter()
	else
		player.CharacterAdded:Connect(handleCharacter)
	end
end

function HubWorldManager.start()
	HubWorldManager.ensureHub()
	HubWorldManager.refreshLeaderboardBoard()

	local remotes = HubWorldManager.getRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		remotes.OpenBeySelect:FireClient(player)
	end)

	remotes.HubZoneHint.OnServerEvent:Connect(function(player, hintId)
		if hintId == "leaderboard" then
			HubWorldManager.refreshLeaderboardBoard()
			remotes.HubZoneHint:FireClient(player, "leaderboard")
		end
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)

	task.spawn(function()
		while true do
			task.wait(30)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
