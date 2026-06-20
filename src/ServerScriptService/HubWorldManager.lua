local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubModel
local zoneDebounce = {}
local playersInHub = {}

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
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y * 0.5 + 3, 0)
	end

	return CFrame.new(0, 10, 0)
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(entries)
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	playersInHub[player] = true
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = findArenaSpawn()
	playersInHub[player] = nil

	local lobby = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
	refreshLeaderboardBoard()
end

local function sendPlayerToHub(player)
	teleportToHub(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

local function onZoneTrigger(player, zoneId)
	local zoneDef = HubConfig.ZONES[zoneId]
	if not zoneDef then return end

	local key = player.UserId .. "_" .. zoneId
	if zoneDebounce[key] and tick() - zoneDebounce[key] < 2 then
		return
	end
	zoneDebounce[key] = tick()

	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zoneDef.name,
		hint = zoneDef.hint,
		action = zoneDef.action,
	})

	if zoneDef.action == "enterArena" then
		HubWorldManager.teleportToArena(player)
	elseif zoneDef.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneDef.action == "showLeaderboard" then
		refreshLeaderboardBoard()
	end
end

local function connectZoneTriggers()
	local zonesFolder = hubModel:FindFirstChild("Zones")
	if not zonesFolder then return end

	for _, zoneFolder in zonesFolder:GetChildren() do
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if trigger then
			trigger.Touched:Connect(function(hit)
				local character = hit.Parent
				if not character then return end
				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end
				local zoneId = trigger:GetAttribute("ZoneId")
				if zoneId then
					onZoneTrigger(player, zoneId)
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
		task.wait(0.2)
		if playersInHub[player] ~= false then
			sendPlayerToHub(player)
		end
	end)

	if player.Character then
		sendPlayerToHub(player)
	end

	refreshLeaderboardBoard()
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	connectZoneTriggers()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
