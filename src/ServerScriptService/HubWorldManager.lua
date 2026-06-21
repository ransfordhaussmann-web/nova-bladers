local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local zoneCooldowns = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

local function findArenaSpawn()
	local arena = Workspace:FindFirstChild("Arena")
	if not arena then return nil end

	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChild("BowlFloor")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = CFrame.new(HubConfig.SPAWN + Vector3.new(0, 3, 0))

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = HubConfig.PLAYER_WALK_SPEED
		humanoid.JumpPower = HubConfig.PLAYER_JUMP_POWER
	end
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden")
		return false
	end

	local character = player.Character
	if not character then return false end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local offset = Vector3.new(0, 4, 0)
	if spawn:IsA("BasePart") then
		root.CFrame = spawn.CFrame + offset
	else
		root.CFrame = CFrame.new(spawn.Position + offset)
	end
	return true
end

function HubWorldManager.sendLobbyReady(player, inHub)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubFolder then return end
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	HubWorldManager.sendLobbyReady(player, true)
end

local function onZoneEnter(player, zonePart)
	local zoneId = zonePart:GetAttribute("ZoneId")
	if not zoneId then return end

	local now = os.clock()
	local key = player.UserId .. "_" .. zoneId
	if zoneCooldowns[key] and now - zoneCooldowns[key] < HubConfig.ZONE_COOLDOWN then
		return
	end
	zoneCooldowns[key] = now

	local action = zonePart:GetAttribute("ZoneAction")
	local hint = zonePart:GetAttribute("ZoneHint") or ""
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zonePart:GetAttribute("ZoneName"),
		hint = hint,
	})

	if action == "enterArena" then
		if teleportToArena(player) then
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, false))
		end
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		local payload = buildLobbyPayload(player, true)
		payload.showStatsPanel = true
		remotes.LobbyReady:FireClient(player, payload)
	end
end

local function bindZone(zonePart)
	zonePart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		onZoneEnter(player, zonePart)
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		teleportToHub(player)
		HubWorldManager.sendLobbyReady(player, true)
	end)

	if player.Character then
		teleportToHub(player)
		HubWorldManager.sendLobbyReady(player, true)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()

	for _, zonePart in hubFolder.Zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			bindZone(zonePart)
		end
	end

	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if teleportToArena(player) then
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, false))
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
