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
local hubFolder
local playersInHub = {}

local function getRemotes()
	if not remotes then
		remotes = RemotesSetup.ensure()
	end
	return remotes
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return nil
	end

	local bowl = arena:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn")
			or bowl:FindFirstChild("SpawnLocation")
			or bowl:FindFirstChildWhichIsA("SpawnLocation")
		if spawn then
			return spawn
		end
	end

	return arena:FindFirstChildWhichIsA("SpawnLocation")
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

function HubWorldManager.updateLeaderboardBoard()
	if not hubFolder then
		return
	end

	local board = hubFolder:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end

	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then
		return
	end

	local list = surface:FindFirstChild("List")
	if not list then
		return
	end

	local entries = LeaderboardManager.getTop(5)
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

function HubWorldManager.sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)

	getRemotes().LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		leaderboard = LeaderboardManager.getTop(5),
		modeLabel = inHub and "Im Hub — Arena-Tor betreten" or "Modus: Training",
		inHub = inHub,
	})
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	teleportCharacter(player, HubConfig.SPAWN)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
	HubWorldManager.updateLeaderboardBoard()
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = false

	local spawn = findArenaSpawn()
	local target = spawn and spawn.Position or HubConfig.ARENA_FALLBACK_SPAWN
	if spawn and spawn:IsA("BasePart") then
		target = spawn.Position + Vector3.new(0, 3, 0)
	end

	teleportCharacter(player, target)
	getRemotes().LobbyReady:FireClient(player, { inHub = false })
end

function HubWorldManager.openBeySelect(player)
	getRemotes().OpenBeySelect:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "BeyLab" then
		HubWorldManager.openBeySelect(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.updateLeaderboardBoard()
		getRemotes().HubZoneHint:FireClient(player, {
			zoneId = zoneId,
			name = HubConfig.ZONES.HallOfFame.name,
			hint = "Rangliste am Board aktualisiert",
			actionLabel = "",
		})
	end
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.init()
	getRemotes()
	hubFolder = HubWorldBuilder.build()
	HubWorldManager.updateLeaderboardBoard()

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			if playersInHub[player] ~= false then
				task.defer(function()
					HubWorldManager.spawnInHub(player)
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end
end

return HubWorldManager
