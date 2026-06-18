local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local hubModel = nil
local remotes = nil

local function getRank(data)
	return PlayerDataManager.getRankPoints(data)
end

local function buildModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function formatLeaderboardLines(entries)
	local lines = { "🏆 Top Spieler:" }
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	end
	return lines
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = getRank(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = buildModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = player:GetAttribute("inHub") == true,
	}
end

local function refreshLeaderboardBoard()
	if not hubModel then
		return
	end
	HubWorldBuilder.updateLeaderboardBoard(hubModel, formatLeaderboardLines(LeaderboardManager.getTop(5)))
end

local function findArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end
	local spawn = arena:FindFirstChild(HubConfig.ARENA_SPAWN_NAME, true)
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	local fallback = arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if fallback then
		return fallback
	end
	return arena:FindFirstChildWhichIsA("BasePart", true)
end

function HubWorldManager.setInHub(player, inHub)
	player:SetAttribute("inHub", inHub)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not hubModel then
		return
	end
	local spawn = hubModel:FindFirstChild("HubSpawn")
	local target = spawn and spawn.CFrame or CFrame.new(HubConfig.SPAWN_POSITION)
	root.CFrame = target + Vector3.new(0, 3, 0)
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Arena-Spawn nicht gefunden — Workspace.Arena mit ArenaSpawn anlegen.")
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

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.setInHub(player, true)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	if not HubWorldManager.teleportToArena(player) then
		return
	end
	HubWorldManager.setInHub(player, false)
	HubWorldManager.sendLobbyReady(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, getRank(data))

	HubWorldManager.setInHub(player, true)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player:GetAttribute("inHub") then
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end

	HubWorldManager.sendLobbyReady(player)
	refreshLeaderboardBoard()
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	refreshLeaderboardBoard()
end

local function connectZonePrompts()
	if not hubModel then
		return
	end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if not prompt then
			continue
		end

		prompt.Triggered:Connect(function(player)
			local action = zonePart:GetAttribute("ZoneAction")
			if action == "EnterArena" then
				HubWorldManager.enterArena(player)
			elseif action == "OpenBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif action == "ShowLeaderboard" then
				HubWorldManager.sendLobbyReady(player)
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build(Workspace)
	connectZonePrompts()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
