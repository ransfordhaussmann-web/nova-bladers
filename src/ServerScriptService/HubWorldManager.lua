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
local hubFolder
local playersInHub = {}
local playerZones = {}

local function resolveArenaSpawn()
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node:FindFirstChild(name)
		if not node then
			return nil
		end
	end
	if node:IsA("BasePart") then
		return node.CFrame + Vector3.new(0, 3, 0)
	end
	if node:IsA("Model") then
		return node:GetPivot() + Vector3.new(0, 3, 0)
	end
	return nil
end

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

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	hrp.CFrame = HubConfig.SPAWN_CFRAME
	playersInHub[player] = true
end

local function teleportToArena(player)
	local spawnCFrame = resolveArenaSpawn()
	if not spawnCFrame then
		warn("[NovaBladers] Arena spawn not found — expected Workspace." .. table.concat(HubConfig.ARENA_SPAWN_PATH, "."))
		return false
	end

	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	hrp.CFrame = spawnCFrame
	playersInHub[player] = nil
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
	return true
end

local function getNearestZone(position)
	local nearest
	local nearestDist = HubConfig.INTERACT_RANGE

	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function sendPlayerToHub(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	teleportToHub(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function handleZoneAction(player, action)
	if not playersInHub[player] then
		return
	end

	if action == "enterArena" then
		teleportToArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

function HubWorldManager.returnToHub(player)
	sendPlayerToHub(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build(HubConfig, LeaderboardManager.getTop(5))

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			teleportToArena(player)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		handleZoneAction(player, action)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			sendPlayerToHub(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		if player.Character then
			task.spawn(function()
				sendPlayerToHub(player)
			end)
		else
			player.CharacterAdded:Once(function()
				task.wait(0.2)
				sendPlayerToHub(player)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for player, _ in playersInHub do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local zone = getNearestZone(hrp.Position)
					if zone ~= playerZones[player] then
						playerZones[player] = zone
						if zone then
							remotes.HubZoneHint:FireClient(player, {
								zoneId = zone.id,
								name = zone.name,
								hint = zone.hint,
								action = zone.action,
							})
						else
							remotes.HubZoneHint:FireClient(player, nil)
						end
					end
				end
			end
		end
	end)
end

return HubWorldManager
