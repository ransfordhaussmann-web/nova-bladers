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
local playersInHub = {}
local zoneDebounce = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y * 0.5 + 3, 0)
	end

	return CFrame.new(0, 10, 60)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD.topCount)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

function HubWorldManager.refreshLeaderboard()
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if board then
		local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD.topCount)
		HubWorldBuilder.updateLeaderboardBoard(board, entries)
	end
end

function HubWorldManager.sendLobbyReady(player, inHub)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPart = hub and hub:FindFirstChild("HubSpawn")
	local target = spawnPart and spawnPart.CFrame or CFrame.new(HubConfig.SPAWN)
	root.CFrame = target + Vector3.new(0, 3, 0)

	playersInHub[player] = true
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
	HubWorldManager.refreshLeaderboard()
end

function HubWorldManager.teleportToArena(player)
	playersInHub[player] = nil

	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = getArenaSpawnCFrame()
	HubWorldManager.sendLobbyReady(player, false)
end

local function onZoneTouched(player, zonePart)
	if not playersInHub[player] then return end

	local now = tick()
	local key = player.UserId .. "_" .. zonePart.Name
	if zoneDebounce[key] and now - zoneDebounce[key] < 1.5 then
		return
	end
	zoneDebounce[key] = now

	local action = zonePart:FindFirstChild("Action")
	local hintText = zonePart:FindFirstChild("HintText")
	local actionName = action and action.Value or ""
	local hint = hintText and hintText.Value or zonePart.Name

	remotes.HubZoneHint:FireClient(player, {
		zone = zonePart.Name,
		hint = hint,
		action = actionName,
	})

	if actionName == "EnterArena" then
		HubWorldManager.teleportToArena(player)
	elseif actionName == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif actionName == "ShowStats" then
		HubWorldManager.sendLobbyReady(player, false)
	end
end

local function connectZone(zonePart)
	zonePart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			onZoneTouched(player, zonePart)
		end
	end)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	local zones = hub:FindFirstChild("Zones")
	if zones then
		for _, zonePart in zones:GetChildren() do
			if zonePart:IsA("BasePart") and zonePart:FindFirstChild("Action") then
				connectZone(zonePart)
			end
		end
	end

	HubWorldManager.refreshLeaderboard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playersInHub[player] ~= false then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		task.defer(function()
			HubWorldManager.spawnInHub(player)
		end)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	zoneDebounce[player.UserId] = nil
	PlayerDataManager.save(player)
end

return HubWorldManager
