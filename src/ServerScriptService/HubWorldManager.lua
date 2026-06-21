local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerZones = {}
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 3, 0)
	end
	return CFrame.new(0, 10, 0)
end

local function getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyData(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	playerZones[player] = nil
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyData(player)
	remotes.HubZoneHint:FireClient(player, { visible = false })
end

local function enterArena(player)
	if inArena[player] then return end
	inArena[player] = true
	teleportCharacter(player, findArenaSpawn())
	remotes.HubZoneHint:FireClient(player, { visible = false })
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, action)
	if action == "arena" then
		enterArena(player)
	elseif action == "beySelect" then
		openBeySelect(player)
	end
end

local function onZoneTouched(zonePart, hit)
	local character = hit.Parent
	if not character then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or inArena[player] then return end

	local zoneId = zonePart:GetAttribute("ZoneId")
	local action = zonePart:GetAttribute("Action")
	if not zoneId then return end

	if playerZones[player] ~= zoneId then
		playerZones[player] = zoneId
		local zoneConfig = HubConfig.ZONES[zoneId]
		if zoneConfig then
			remotes.HubZoneHint:FireClient(player, {
				visible = true,
				zoneId = zoneId,
				name = zoneConfig.name,
				hint = zoneConfig.hint,
				action = action,
			})
		end
	end
end

local function wireZones(hub)
	local zonesFolder = hub:FindFirstChild("Zones")
	if not zonesFolder then return end
	for _, zonePart in zonesFolder:GetChildren() do
		if zonePart:IsA("BasePart") and zonePart:GetAttribute("ZoneId") then
			zonePart.Touched:Connect(function(hit)
				onZoneTouched(zonePart, hit)
			end)
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local leaderboard = LeaderboardManager.getTop(5)
	local hub = HubWorldBuilder.build(leaderboard)
	wireZones(hub)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if not inArena[player] then
					teleportCharacter(player, getHubSpawnCFrame())
					HubWorldManager.sendLobbyData(player)
				end
			end)
		end)

		if player.Character then
			task.defer(function()
				teleportCharacter(player, getHubSpawnCFrame())
				HubWorldManager.sendLobbyData(player)
			end)
		end
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		teleportCharacter(player, getHubSpawnCFrame())
		HubWorldManager.sendLobbyData(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
		inArena[player] = nil
	end)
end

return HubWorldManager
