local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inHub = {}

local function getArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(0, 5, 0)
end

local function modeLabelFor(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboard(entries)
	for _, player in Players:GetPlayers() do
		if inHub[player] then
			HubWorldManager.sendLobbyReady(player)
		end
	end
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(HubConfig.SPAWN)
	inHub[player] = true
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	inHub[player] = nil
	hrp.CFrame = getArenaSpawn()
end

local function onEnterArena(player)
	if not inHub[player] then return end
	HubWorldManager.teleportToArena(player)
end

local function onOpenBeySelect(player)
	if not inHub[player] then return end
	remotes.OpenBeySelect:FireClient(player)
end

local function onZoneAction(player, zoneId)
	if not inHub[player] then return end
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			if zone.action == "EnterArena" then
				onEnterArena(player)
			elseif zone.action == "OpenBeySelect" then
				onOpenBeySelect(player)
			elseif zone.action == "ShowLeaderboard" then
				HubWorldManager.sendLobbyReady(player)
			end
			return
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.build(entries)

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.HubZoneAction.OnServerEvent:Connect(onZoneAction)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			HubWorldManager.teleportToHub(player)
		end)

		if player.Character then
			HubWorldManager.teleportToHub(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inHub[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		if player.Character then
			HubWorldManager.teleportToHub(player)
		end
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
