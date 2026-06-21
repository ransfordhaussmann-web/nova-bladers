local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubModel
local playersInHub = {}
local lastZoneHint = {}
local zoneEntered = {}

local function getRemotes()
	if not remotes then
		remotes = RemotesSetup.ensure()
	end
	return remotes
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	else
		return "Modus: FFA (" .. count .. " Spieler)"
	end
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rank = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
	return payload
end

local function sendLobbyReady(player, inHub)
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function refreshLeaderboardBoard()
	if not hubModel then return end
	HubWorldBuilder.buildLeaderboardBoard(hubModel, LeaderboardManager.getTop(5))
end

local function isInZone(character, zone)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local half = zone.size / 2
	local pos = root.Position
	local center = zone.position

	return math.abs(pos.X - center.X) <= half.X
		and math.abs(pos.Z - center.Z) <= half.Z
		and math.abs(pos.Y - center.Y) <= 8
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION + Vector3.new(0, 3, 0))
	playersInHub[player] = true
	sendLobbyReady(player, true)
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden")
		return false
	end

	local character = player.Character
	if not character then return false end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local offset = Vector3.new(0, 3, 0)
	if spawn:IsA("BasePart") then
		root.CFrame = spawn.CFrame + offset
	else
		root.CFrame = CFrame.new(spawn.Position) + offset
	end

	playersInHub[player] = nil
	sendLobbyReady(player, false)
	return true
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
end

local function handleZoneAction(player, zone)
	if zone.action == "enterArena" then
		HubWorldManager.teleportToArena(player)
	elseif zone.action == "openBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif zone.action == "showLeaderboard" then
		refreshLeaderboardBoard()
	end
end

local function checkPlayerZones(player)
	if not playersInHub[player] then return end

	local character = player.Character
	if not character then return end

	local inAnyZone = false
	for _, zone in HubConfig.ZONES do
		if isInZone(character, zone) then
			inAnyZone = true
			local now = os.clock()
			local last = lastZoneHint[player]
			if not last or last.zoneId ~= zone.id or (now - last.time) >= HubConfig.ZONE_HINT_COOLDOWN then
				lastZoneHint[player] = { zoneId = zone.id, time = now }
				getRemotes().HubZoneHint:FireClient(player, {
					zoneId = zone.id,
					label = zone.label,
					hint = zone.hint,
				})
			end

			if zone.action == "enterArena" and not zoneEntered[player] then
				zoneEntered[player] = true
				handleZoneAction(player, zone)
			end
			return
		end
	end

	if not inAnyZone then
		zoneEntered[player] = nil
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		teleportToHub(player)
	end)

	if player.Character then
		task.defer(function()
			teleportToHub(player)
		end)
	end

	sendLobbyReady(player, true)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	lastZoneHint[player] = nil
	zoneEntered[player] = nil
	PlayerDataManager.save(player)
end

local function setupZonePrompts()
	if not hubModel then return end
	local zonesFolder = hubModel:FindFirstChild("Zones")
	if not zonesFolder then return end

	for _, zone in HubConfig.ZONES do
		if zone.action ~= "enterArena" then
			local pad = zonesFolder:FindFirstChild(zone.id)
			if pad then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "ZonePrompt"
				prompt.ActionText = zone.label
				prompt.ObjectText = "Nova Hub"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.Parent = pad

				prompt.Triggered:Connect(function(player)
					if playersInHub[player] then
						handleZoneAction(player, zone)
					end
				end)
			end
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	refreshLeaderboardBoard()
	setupZonePrompts()

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				checkPlayerZones(player)
			end
		end
	end)
end

return HubWorldManager
