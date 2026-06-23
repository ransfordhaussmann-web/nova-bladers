local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local zoneTriggers = {}
local playerZones = {}
local leaderboardBoard

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function getArenaSpawnCFrame()
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
	return CFrame.new(0, 10, 0)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = targetCFrame
	end
end

function HubWorldManager.sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub == true,
	})
end

function HubWorldManager.refreshLeaderboardBoard()
	if leaderboardBoard then
		HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, LeaderboardManager.getTop(5))
	end
end

function HubWorldManager.returnToHub(player)
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
	HubWorldManager.sendLobbyReady(player, true)
end

local function playerInZone(player, zoneId)
	local trigger = zoneTriggers[zoneId]
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not trigger or not hrp then
		return false
	end
	local offset = hrp.Position - trigger.Position
	local half = trigger.Size / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

local function handleZoneAction(player, zoneId)
	if typeof(zoneId) ~= "string" or not HubConfig.ZONES[zoneId] then
		return
	end
	if not playerInZone(player, zoneId) then
		return
	end

	local action = HubConfig.ZONES[zoneId].action
	if action == "EnterArena" then
		teleportCharacter(player, getArenaSpawnCFrame())
		playerZones[player] = nil
		remotes.HubZoneHint:FireClient(player, nil)
		HubWorldManager.sendLobbyReady(player, false)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ViewLeaderboard" then
		HubWorldManager.refreshLeaderboardBoard()
	end
end

local function updatePlayerZone(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local activeZone = nil
	for zoneId, trigger in zoneTriggers do
		if playerInZone(player, zoneId) then
			activeZone = zoneId
			break
		end
	end

	if playerZones[player] == activeZone then
		return
	end

	playerZones[player] = activeZone
	if activeZone then
		local zone = HubConfig.ZONES[activeZone]
		remotes.HubZoneHint:FireClient(player, {
			zoneId = activeZone,
			name = zone.name,
			hint = zone.hint,
			action = zone.action,
		})
	else
		remotes.HubZoneHint:FireClient(player, nil)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	local leaderboard = LeaderboardManager.getTop(5)
	local _, triggers = HubWorldBuilder.build(leaderboard)
	zoneTriggers = triggers

	local hub = workspace:FindFirstChild("NovaHub")
	if hub then
		leaderboardBoard = hub:FindFirstChild("LeaderboardBoard")
	end

	remotes.HubZoneAction.OnServerEvent:Connect(handleZoneAction)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportCharacter(player, getArenaSpawnCFrame())
		playerZones[player] = nil
		remotes.HubZoneHint:FireClient(player, nil)
		HubWorldManager.sendLobbyReady(player, false)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
				HubWorldManager.sendLobbyReady(player, true)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
	end

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			updatePlayerZone(player)
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
