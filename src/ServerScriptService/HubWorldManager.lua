local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local inArena = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local current = workspace
		for segment in string.split(path, ".") do
			current = current and current:FindFirstChild(segment)
		end

		if current and current:IsA("BasePart") then
			return current
		end

		if current and current:IsA("Model") then
			local spawn = current:FindFirstChild("Spawn") or current.PrimaryPart
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("Arena")
	if bowl then
		if bowl:IsA("BasePart") then
			return bowl
		end
		return bowl:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function sendLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
	})

	if inHub then
		HubWorldBuilder.updateLeaderboardBoard(leaderboard)
	end
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local spawn = hubModel and hubModel:FindFirstChild("HubSpawn")
	local position = spawn and spawn.Position or HubConfig.SPAWN_POSITION
	root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	inArena[player] = nil
end

local function teleportToArena(player)
	local spawn = resolveArenaSpawn()
	local character = player.Character
	if not character or not spawn then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	inArena[player] = true
	return true
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyPayload(player, true)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)

		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if not inArena[player] then
				teleportToHub(player)
				sendLobbyPayload(player, true)
			end
		end)

		if player.Character then
			teleportToHub(player)
		end
		sendLobbyPayload(player, true)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "enterArena" then
			teleportToArena(player)
		elseif action == "openBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "viewLeaderboard" then
			sendLobbyPayload(player, true)
			local zone = HubConfig.ZONES.HallOfFame
			remotes.HubZoneHint:FireClient(player, {
				zoneId = "HallOfFame",
				name = zone.name,
				hint = zone.hint,
			})
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			HubWorldBuilder.updateLeaderboardBoard(LeaderboardManager.getTop(5))
		end
	end)
end

return HubWorldManager
