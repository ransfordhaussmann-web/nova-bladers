local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local inHub = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = game
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local leaderboard = LeaderboardManager.getTop(5)

	local playerRank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			playerRank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = playerRank,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = options.inHub ~= false,
		showStats = options.showStats == true,
	}
end

function HubWorldManager.sendLobbyReady(player, options)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, options))
end

function HubWorldManager.spawnInHub(player)
	inHub[player] = true
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPart = hubModel and hubModel:FindFirstChild("HubSpawn")
	local target = (spawnPart and spawnPart.CFrame or CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET))
	root.CFrame = target + Vector3.new(0, 3, 0)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end

	HubWorldManager.sendLobbyReady(player, { inHub = true })
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	local spawn = resolveArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — HubWorldManager")
		return false
	end

	inHub[player] = false
	local character = player.Character
	if not character then return false end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	HubWorldManager.sendLobbyReady(player, { inHub = false })
	return true
end

local function onZoneTriggered(player, zoneId)
	if not inHub[player] then return end

	if zoneId == "ArenaGate" then
		HubWorldManager.teleportToArena(player)
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyReady(player, { inHub = true, showStats = true })
	end
end

local function wireZonePrompts()
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				local zoneId = prompt:GetAttribute("ZoneId") or zonePart.Name
				onZoneTriggered(triggerPlayer, zoneId)
			end)
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	wireZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				if inHub[player] ~= false then
					HubWorldManager.spawnInHub(player)
				end
			end)
		end)

		if player.Character then
			HubWorldManager.spawnInHub(player)
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
		HubWorldManager.spawnInHub(player)
	end
end

return HubWorldManager
