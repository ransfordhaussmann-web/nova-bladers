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
local playerZones = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return nil
	end

	local bowl = arena:FindFirstChild("Bowl")
	if bowl then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = bowl:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end

	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	return nil
end

local function updateLeaderboardBoard(entries)
	local zones = hubFolder and hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	local board = zones:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end

	local gui = board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("Entries")
	if not list then
		return
	end

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

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end

	root.CFrame = HubConfig.SPAWN_CFRAME
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Workspace.Arena.Bowl.Spawn anlegen")
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	return true
end

function HubWorldManager.returnToHub(player)
	playerZones[player] = nil
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player)
end

local function onZoneEntered(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		return
	end

	playerZones[player] = zoneId
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zone.name,
		hint = zone.hint,
		action = zone.action,
	})
end

local function onZoneLeft(player)
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
end

local function trackZonePads()
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, pad in zones:GetChildren() do
		if pad:IsA("BasePart") and pad:GetAttribute("ZoneId") then
			pad.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if not player then
					return
				end

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end

				onZoneEntered(player, pad:GetAttribute("ZoneId"))
			end)

			pad.TouchEnded:Connect(function(hit)
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if not player then
					return
				end

				if playerZones[player] == pad:GetAttribute("ZoneId") then
					onZoneLeft(player)
				end
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			HubWorldManager.spawnInHub(player)
			HubWorldManager.sendLobbyReady(player)
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end

	HubWorldManager.sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	playerZones[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	trackZonePads()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playerZones[player] ~= "ArenaGate" then
			return
		end
		HubWorldManager.teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "enterArena" and playerZones[player] == "ArenaGate" then
			HubWorldManager.teleportToArena(player)
		elseif action == "openBeySelect" and playerZones[player] == "BeyLab" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "viewLeaderboard" and playerZones[player] == "HallOfFame" then
			updateLeaderboardBoard(LeaderboardManager.getTop(5))
			HubWorldManager.sendLobbyReady(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			updateLeaderboardBoard(LeaderboardManager.getTop(5))
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
