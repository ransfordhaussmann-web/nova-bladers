local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}

local function resolveArenaSpawn()
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node:FindFirstChild(name)
		if not node then
			return CFrame.new(HubConfig.ARENA_FALLBACK)
		end
	end
	if node:IsA("BasePart") then
		return node.CFrame + Vector3.new(0, 3, 0)
	end
	if node:IsA("SpawnLocation") then
		return node.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.ARENA_FALLBACK)
end

local function getHubSpawn()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	local spawn = hub and hub:FindFirstChild(HubConfig.SPAWN_NAME)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 5, 0)
end

local function teleportCharacter(player, cf)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end

local function buildModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = buildModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	teleportCharacter(player, getHubSpawn())
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	teleportCharacter(player, resolveArenaSpawn())
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		remotes.OpenBeySelect:FireClient(player)
	end)

	remotes.ShowHallPanel.OnServerEvent:Connect(function(player)
		HubWorldManager.sendLobbyReady(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if inArena[player] then
				teleportCharacter(player, resolveArenaSpawn())
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
	end
end

return HubWorldManager
