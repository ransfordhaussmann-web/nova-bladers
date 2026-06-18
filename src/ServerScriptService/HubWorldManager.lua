local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")

local HubWorldManager = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	end
	if playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

function HubWorldManager.buildPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then
		return CFrame.new(HubConfig.SPAWN_POSITION)
	end
	local spawn = hub:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

function HubWorldManager.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return nil
	end
	local spawn = arena:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	local spawnLocation = arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end
	return nil
end

function HubWorldManager.teleportCharacter(player, targetCFrame)
	if not targetCFrame then
		return false
	end
	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	hrp.CFrame = targetCFrame
	return true
end

function HubWorldManager.teleportToHub(player)
	player:SetAttribute("inHub", true)
	return HubWorldManager.teleportCharacter(player, HubWorldManager.getHubSpawnCFrame())
end

function HubWorldManager.teleportToArena(player)
	local arenaCFrame = HubWorldManager.getArenaSpawnCFrame()
	if not arenaCFrame then
		return false
	end
	player:SetAttribute("inHub", false)
	return HubWorldManager.teleportCharacter(player, arenaCFrame)
end

function HubWorldManager.sendLobbyReady(player)
	Remotes.LobbyReady:FireClient(player, HubWorldManager.buildPayload(player))
end

function HubWorldManager.onPlayerAdded(player)
	player:SetAttribute("inHub", true)
	PlayerDataManager.load(player)

	local function onCharacter()
		task.defer(function()
			HubWorldManager.teleportToHub(player)
			HubWorldManager.sendLobbyReady(player)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter()
	end
end

function HubWorldManager.returnPlayerToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
	Remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.init()
	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not player:GetAttribute("inHub") then
			return
		end
		HubWorldManager.teleportToArena(player)
	end)

	Remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnPlayerToHub(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
