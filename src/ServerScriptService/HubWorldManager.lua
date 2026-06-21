local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local HubWorldManager = {}
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

function HubWorldManager.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, 5, 0)
	end

	return CFrame.new(0, 10, 60)
end

function HubWorldManager.teleportToHub(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	local owner = Players:GetPlayerFromCharacter(character)
	if owner then
		inArena[owner] = nil
	end
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	local character = player.Character
	if character then
		HubWorldManager.teleportToHub(character)
	end
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local playerCount = #Players:GetPlayers()
	Remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	})
end

function HubWorldManager.onPlayerJoin(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function(character)
		if inArena[player] then return end
		task.defer(function()
			HubWorldManager.teleportToHub(character)
			HubWorldManager.sendLobbyReady(player)
		end)
	end)

	if player.Character and not inArena[player] then
		HubWorldManager.teleportToHub(player.Character)
	end
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = HubWorldManager.getArenaSpawnCFrame()
	Remotes.LobbyReady:FireClient(player, { inHub = false })
end

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	if inArena[player] then return end
	HubWorldManager.enterArena(player)
end)

Remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
	if inArena[player] then return end
	Remotes.OpenBeySelect:FireClient(player)
end)

return HubWorldManager
