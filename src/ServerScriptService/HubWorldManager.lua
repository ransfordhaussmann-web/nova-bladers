local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}
local hubBuilt = false
local playersInHub = {}

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
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if arena then
		for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(spawnName, true)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
		local bowl = arena:FindFirstChild("Bowl", true)
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 4, 0)
		end
	end
	return CFrame.new(0, 8, 120)
end

local function getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

function HubWorldManager.buildHub()
	if hubBuilt then
		return
	end
	local leaderboard = LeaderboardManager.getTop(5)
	HubWorldBuilder.build(leaderboard)
	hubBuilt = true
	HubWorldManager.bindZonePrompts()
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubBuilt then
		return
	end
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then
		return
	end
	HubWorldBuilder.createLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = playersInHub[player] == true,
	}
	Remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = nil
	teleportCharacter(player, getArenaSpawnCFrame())
	Remotes.HubZoneHint:FireClient(player, { visible = false })
end

function HubWorldManager.openBeySelect(player)
	Remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.showZoneHint(player, zone)
	Remotes.HubZoneHint:FireClient(player, {
		visible = true,
		zoneId = zone.id,
		label = zone.label,
		hint = zone.hint,
	})
end

local function handleZoneAction(player, zone)
	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		HubWorldManager.openBeySelect(player)
	elseif zone.action == "showLeaderboard" then
		HubWorldManager.refreshLeaderboardBoard()
		HubWorldManager.showZoneHint(player, zone)
	end
end

function HubWorldManager.bindZonePrompts()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then
		return
	end

	for _, zone in HubConfig.ZONES do
		local marker = hub:FindFirstChild(zone.id)
		if marker then
			local prompt = marker:FindFirstChild("ZonePrompt")
			if prompt and not prompt:GetAttribute("HubBound") then
				prompt:SetAttribute("HubBound", true)
				prompt.Triggered:Connect(function(player)
					handleZoneAction(player, zone)
				end)
			end
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	HubWorldManager.buildHub()
	HubWorldManager.spawnInHub(player)

	player.CharacterAdded:Connect(function()
		if playersInHub[player] then
			task.defer(function()
				teleportCharacter(player, getHubSpawnCFrame())
			end)
		end
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)
end

return HubWorldManager
