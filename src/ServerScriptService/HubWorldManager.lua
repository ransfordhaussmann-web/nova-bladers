local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
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
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local delta = position - zone.position
		if math.abs(delta.X) <= half.X and math.abs(delta.Z) <= half.Z then
			return zone
		end
	end
	return nil
end

function HubWorldManager.getPlayerZone(player)
	return playerZones[player]
end

function HubWorldManager.sendLobbyReady(player)
	if inArena[player] then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	playerZones[player] = nil
	teleportCharacter(player, HubWorldBuilder.getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	playerZones[player] = nil
	teleportCharacter(player, HubWorldBuilder.getArenaSpawnCFrame())
	remotes.HubZoneAction:FireClient(player, { state = "leftHub" })
end

local function handleZoneAction(player, zone)
	if inArena[player] or not zone then return end

	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showHall" then
		remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "interact" then
			local zone = playerZones[player]
			handleZoneAction(player, zone)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		inArena[player] = false
		playerZones[player] = nil

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if inArena[player] then
				teleportCharacter(player, HubWorldBuilder.getArenaSpawnCFrame())
			else
				teleportCharacter(player, HubWorldBuilder.getHubSpawnCFrame())
				HubWorldManager.sendLobbyReady(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
		playerZones[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				if inArena[player] then continue end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root then continue end

				local zone = getZoneAtPosition(root.Position)
				local previous = playerZones[player]
				if zone ~= previous then
					playerZones[player] = zone
					if zone then
						remotes.HubZoneAction:FireClient(player, {
							state = "entered",
							zoneId = zone.id,
							name = zone.name,
							hint = zone.hint,
							action = zone.action,
						})
					else
						remotes.HubZoneAction:FireClient(player, { state = "left" })
					end
				end
			end
		end
	end)
end

return HubWorldManager
