local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes = nil
local inArena = {}

local function getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ARENA_SPAWN)
end

local function getHubSpawn()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.HUB_SPAWN)
end

local function teleportCharacter(player, cf)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = HubWorldManager.getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.setHubState(player, inHub)
	inArena[player] = not inHub
	if remotes and remotes.HubState then
		remotes.HubState:FireClient(player, { inHub = inHub })
	end
end

function HubWorldManager.sendLobbyReady(player)
	if remotes and remotes.LobbyReady then
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.setHubState(player, true)
	teleportCharacter(player, getHubSpawn())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.sendToArena(player)
	HubWorldManager.setHubState(player, false)
	teleportCharacter(player, getArenaSpawn())
end

function HubWorldManager.onPlayerAdded(player)
	inArena[player] = false
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				teleportCharacter(player, getArenaSpawn())
			else
				teleportCharacter(player, getHubSpawn())
				HubWorldManager.sendLobbyReady(player)
			end
		end)
	end)
end

function HubWorldManager.init(hubFolder)
	remotes = RemotesSetup.ensureAll()

	if remotes.EnterArena then
		remotes.EnterArena.OnServerEvent:Connect(function(player)
			HubWorldManager.sendToArena(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)

	return hubFolder
end

return HubWorldManager
