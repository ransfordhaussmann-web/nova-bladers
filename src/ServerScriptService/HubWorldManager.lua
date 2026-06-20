local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local inArena = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y * 0.5 + 3, 0)
	end

	return CFrame.new(0, 10, 80)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local leaderboard = LeaderboardManager.getTop(5)
	if hubFolder then
		HubWorldBuilder.buildLeaderboardBoard(hubFolder, leaderboard)
	end

	local playerCount = #Players:GetPlayers()
	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		inHub = not inArena[player],
	})
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	local cframe = spawn and spawn.CFrame or CFrame.new(HubConfig.SPAWN)
	teleportCharacter(player, cframe + Vector3.new(0, 3, 0))
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	teleportCharacter(player, getArenaSpawnCFrame())
	remotes.LobbyReady:FireClient(player, {
		inHub = false,
	})
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function onZoneTriggered(player, action)
	if action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "OpenBeySelect" then
		HubWorldManager.openBeySelect(player)
	elseif action == "ShowLeaderboard" then
		HubWorldManager.sendLobbyReady(player)
	end
end

local function bindZoneTriggers()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, marker in zones:GetChildren() do
		local trigger = marker:FindFirstChild("Trigger")
		if not trigger then continue end

		local actionValue = trigger:FindFirstChild("ZoneAction")
		local action = actionValue and actionValue.Value

		local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
		if prompt and action then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, action)
			end)
		end

		trigger.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player or inArena[player] then return end
			remotes.HubZoneHint:FireClient(player, {
				zoneId = marker.Name,
				action = action,
			})
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	bindZoneTriggers()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				HubWorldManager.spawnInHub(player)
			end
		end)
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.spawnInHub(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)
end

return HubWorldManager
