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

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findHubSpawnCFrame()
	if not hubFolder then
		return CFrame.new(HubConfig.FLOOR_CENTER + HubConfig.SPAWN_OFFSET)
	end
	local spawn = hubFolder:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.FLOOR_CENTER + HubConfig.SPAWN_OFFSET)
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return CFrame.new(0, 5, 0)
	end

	local spawn = arena:FindFirstChild("Spawn")
		or arena:FindFirstChild("ArenaSpawn")
		or arena:FindFirstChildWhichIsA("SpawnLocation", true)

	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end

	return arena:GetPivot() + Vector3.new(0, 5, 0)
end

local function teleportPlayer(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(targetCFrame)
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.setInHub(player, inHub)
	player:SetAttribute("inHub", inHub)
end

function HubWorldManager.spawnPlayerInHub(player)
	HubWorldManager.setInHub(player, true)
	teleportPlayer(player, findHubSpawnCFrame())
end

function HubWorldManager.returnPlayerToHub(player)
	HubWorldManager.spawnPlayerInHub(player)
	remotes.ReturnToHub:FireClient(player)
end

local function onEnterArena(player)
	if not player:GetAttribute("inHub") then
		return
	end

	HubWorldManager.setInHub(player, false)
	teleportPlayer(player, findArenaSpawnCFrame())
end

local function onZonePrompt(prompt, player)
	local zonePart = prompt.Parent
	if not zonePart or not zonePart:IsA("BasePart") then
		return
	end

	local action = zonePart:GetAttribute("ZoneAction")
	if action == "showLobby" then
		HubWorldManager.sendLobbyReady(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

local function bindZonePrompts()
	local zones = hubFolder and hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onZonePrompt(prompt, player)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.setInHub(player, true)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player:GetAttribute("inHub") then
				teleportPlayer(player, findHubSpawnCFrame())
			end
		end)
	end)

	if player.Character then
		HubWorldManager.spawnPlayerInHub(player)
	end
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	bindZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnPlayerToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
