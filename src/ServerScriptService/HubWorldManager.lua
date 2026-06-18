local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local RemotesSetup = require(NovaBladers.RemotesSetup)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end
	return workspace:FindFirstChild("ArenaSpawn")
end

local function buildLobbyPayload(player, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = LeaderboardManager.getPlayerRank(player.UserId),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
		showPanel = showPanel == true,
	}
end

function HubWorldManager.getHubFolder()
	return hubFolder
end

function HubWorldManager.sendLobbyReady(player, showPanel)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, showPanel))
end

function HubWorldManager.spawnInHub(player)
	if not hubFolder then return end
	local spawn = hubFolder:FindFirstChild("HubSpawn")
	if not spawn then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 3, 0))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player, false)
end

function HubWorldManager.teleportToArena(player)
	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] ArenaSpawn nicht gefunden — Hub-Arena-Tor deaktiviert.")
		return false
	end

	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local target = arenaSpawn:IsA("BasePart") and arenaSpawn.CFrame
		or (arenaSpawn:IsA("Model") and arenaSpawn:GetPivot())
	if target then
		root.CFrame = target + Vector3.new(0, 3, 0)
	end
	return true
end

local function onZoneTriggered(player, action)
	if action == "EnterArena" then
		HubWorldManager.teleportToArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowLobbyStats" then
		HubWorldManager.sendLobbyReady(player, true)
	end
end

local function connectZonePrompts()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local action = zonePart:GetAttribute("ZoneAction")
				if action then
					onZoneTriggered(player, action)
				end
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	local function onCharacterAdded()
		task.defer(function()
			HubWorldManager.spawnInHub(player)
			HubWorldManager.sendLobbyReady(player, false)
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure(NovaBladers)
	hubFolder = HubWorldBuilder.build(workspace)
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			onZoneTriggered(player, action)
		end
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)
end

return HubWorldManager
