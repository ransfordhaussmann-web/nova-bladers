local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local playerDataManager
local leaderboardManager
local inHub = {}
local hubFolder

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(5)

	local rank = 0
	for _, entry in leaderboard do
		if entry.points <= rankPoints then
			break
		end
		rank += 1
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank + 1,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.getArenaSpawn()
	local arena = workspace:FindFirstChild("Arena") or workspace:FindFirstChild("Bowl")
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name, true)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
		local bowl = arena:FindFirstChild("Bowl", true)
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 3, 0)
		end
	end
	return CFrame.new(0, 5, 0)
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	hrp.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	inHub[player] = true
end

function HubWorldManager.returnToHub(player)
	if not player.Parent then
		return
	end
	inHub[player] = true
	HubWorldManager.spawnInHub(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubFolder then
		return
	end
	local hall = hubFolder:FindFirstChild("Zones")
	if not hall then
		return
	end
	local hallZone = hall:FindFirstChild("hall_of_fame")
	if not hallZone then
		return
	end
	HubWorldBuilder.buildHallOfFameBoard(hallZone, leaderboardManager.getTop(5))
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.leaveHub(player)
	inHub[player] = nil
end

local function wireZoneTriggers()
	if not hubFolder then
		return
	end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zone in HubConfig.ZONES do
		local zoneFolder = zones:FindFirstChild(zone.id)
		if not zoneFolder then
			continue
		end
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if not trigger then
			continue
		end

		trigger.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player and inHub[player] then
				remotes.HubZoneHint:FireClient(player, zone.id)
			end
		end)

		trigger.TouchEnded:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player and inHub[player] then
				remotes.HubZoneHint:FireClient(player, nil)
			end
		end)

		local prompt = trigger:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if not inHub[player] then
					return
				end
				if zone.action == "enterArena" then
					onEnterArena(player)
				elseif zone.action == "openBeySelect" then
					onOpenBeySelect(player)
				end
			end)
		end
	end
end

local function onEnterArena(player)
	if not inHub[player] then
		return
	end
	HubWorldManager.leaveHub(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = HubWorldManager.getArenaSpawn()
	end
end

local function onOpenBeySelect(player)
	if not inHub[player] then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end

local function onPlayerAdded(player)
	playerDataManager.load(player)
	local data = playerDataManager.get(player)
	leaderboardManager.submit(player, playerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if inHub[player] ~= false then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end

	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function onPlayerRemoving(player)
	playerDataManager.save(player)
	inHub[player] = nil
end

function HubWorldManager.init(deps)
	playerDataManager = deps.playerDataManager
	leaderboardManager = deps.leaderboardManager

	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.OpenBeySelect.OnServerEvent:Connect(onOpenBeySelect)

	wireZoneTriggers()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(HubConfig.LEADERBOARD_REFRESH)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
