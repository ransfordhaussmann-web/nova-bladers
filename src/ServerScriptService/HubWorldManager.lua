local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerZones = {}
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function isInZone(position, zone)
	local half = zone.size / 2
	return math.abs(position.X - zone.center.X) <= half.X
		and math.abs(position.Y - zone.center.Y) <= half.Y + 5
		and math.abs(position.Z - zone.center.Z) <= half.Z
end

local function findPlayerZone(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	for zoneKey, zone in HubConfig.ZONES do
		if isInZone(hrp.Position, zone) then
			return zoneKey, zone
		end
	end
	return nil
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
	return CFrame.new(0, 5, 0)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(HubConfig.SPAWN)
	end
	inArena[player] = nil
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = getArenaSpawnCFrame()
	end
	inArena[player] = true
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, { inArena = true })
end

local function handleZoneAction(player, zoneKey)
	if inArena[player] then
		return
	end
	local zone = HubConfig.ZONES[zoneKey]
	if not zone then
		return
	end
	if zone.action == "enter_arena" then
		HubWorldManager.teleportToArena(player)
	elseif zone.action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if not inArena[player] then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	inArena[player] = nil
end

local function refreshLeaderboardBoard()
	local hub = workspace:FindFirstChild(HubConfig.FOLDER_NAME)
	if hub then
		HubWorldBuilder.createLeaderboardBoard(hub, LeaderboardManager.getTop(5))
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inArena[player] then
			return
		end
		HubWorldManager.teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneKey)
		if typeof(zoneKey) ~= "string" then
			return
		end
		handleZoneAction(player, zoneKey)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			if inArena[player] then
				-- skip zone tracking while in arena
			else
				local character = player.Character
				if character then
					local zoneKey = findPlayerZone(character)
					if playerZones[player] ~= zoneKey then
						playerZones[player] = zoneKey
						if zoneKey then
							local zone = HubConfig.ZONES[zoneKey]
							remotes.HubZoneHint:FireClient(player, {
								zoneKey = zoneKey,
								zoneId = zone.id,
								label = zone.label,
								hint = zone.hint,
								action = zone.action,
							})
						else
							remotes.HubZoneHint:FireClient(player, { zoneId = nil })
						end
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			refreshLeaderboardBoard()
		end
	end)
end

_G.NovaBladersReturnToHub = HubWorldManager.returnToHub

return HubWorldManager
