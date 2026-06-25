local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}
local hubFolder
local leaderboardBoard

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

function HubWorldManager.getArenaFolder()
	return Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
end

function HubWorldManager.getArenaSpawnCFrame()
	local arena = HubWorldManager.getArenaFolder()
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 6, -60)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		hubMode = HubConfig.USE_3D_HUB,
	})

	if leaderboardBoard then
		HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, leaderboard)
	end
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	root.CFrame = HubConfig.HUB_SPAWN
	inArena[player] = nil

	if hubFolder then
		hubFolder.Parent = Workspace
	end

	HubWorldManager.sendLobbyPayload(player)
end

function HubWorldManager.sendToArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	inArena[player] = true
	root.CFrame = HubWorldManager.getArenaSpawnCFrame()

	if hubFolder then
		hubFolder.Parent = nil
	end

	remotes.EnterArena:FireClient(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowLeaderboard" then
		HubWorldManager.sendLobbyPayload(player)
		remotes.HubZoneHint:FireClient(player, {
			zone = "Leaderboard",
			message = "Rangliste aktualisiert",
		})
	end
end

function HubWorldManager.onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				HubWorldManager.sendToArena(player)
			else
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder

	hubFolder, leaderboardBoard = HubWorldBuilder.build(function(player, action)
		HubWorldManager.handleZoneAction(player, action)
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
