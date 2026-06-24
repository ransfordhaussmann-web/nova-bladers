local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local hubPlayers = {}
local zoneParts = {}

local function modeLabelFor(count)
	if count <= 1 then return "Modus: Training" end
	if count == 2 then return "Modus: 1v1 PvP" end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_PATHS do
		local current = game
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end

	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name, true)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end
	return nil
end

local function teleportCharacter(player, position, lookAt)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local cf = CFrame.new(position)
	if lookAt then
		cf = CFrame.lookAt(position, lookAt)
	end
	root.CFrame = cf + Vector3.new(0, 3, 0)
end

local function collectZoneParts()
	table.clear(zoneParts)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end
	for _, part in zones:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("ZoneId") then
			table.insert(zoneParts, part)
		end
	end
end

local function zoneForPosition(position)
	for _, part in zoneParts do
		local rel = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 4 and math.abs(rel.Z) <= half.Z then
			return part:GetAttribute("ZoneId"), part:GetAttribute("ZoneAction")
		end
	end
	return nil, nil
end

function HubWorldManager.refreshLeaderboard()
	local hub = workspace:FindFirstChild("NovaHub")
	if hub then
		HubWorldBuilder.buildLeaderboardBoard(hub, LeaderboardManager.getTop(5))
	end
end

function HubWorldManager.sendLobbyReady(player, inHub)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildPayload(player, inHub))
end

function HubWorldManager.enterArena(player)
	if not hubPlayers[player] then return end
	hubPlayers[player] = false

	local spawn = findArenaSpawn()
	if spawn then
		teleportCharacter(player, spawn.Position, spawn.Position + spawn.CFrame.LookVector)
	else
		warn("[NovaBladers] Arena-Spawn nicht gefunden — prüfe Workspace.Arena.Bowl.Spawn")
	end
end

function HubWorldManager.returnToHub(player)
	hubPlayers[player] = true
	local character = player.Character
	if character then
		teleportCharacter(player, HubConfig.SPAWN)
	end
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.openBeySelect(player)
	if not remotes then return end
	remotes.OpenBeySelect:FireClient(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	hubPlayers[player] = true

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if hubPlayers[player] then
			teleportCharacter(player, HubConfig.SPAWN)
			HubWorldManager.sendLobbyReady(player, true)
		end
	end)

	if player.Character then
		teleportCharacter(player, HubConfig.SPAWN)
	end
	HubWorldManager.sendLobbyReady(player, true)
end

local function onPlayerRemoving(player)
	hubPlayers[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build(LeaderboardManager.getTop(5))
	collectZoneParts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if not hubPlayers[player] then return end
		if action == "enter_arena" then
			HubWorldManager.enterArena(player)
		elseif action == "open_bey_select" then
			HubWorldManager.openBeySelect(player)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(0.35)
			for player, inHub in hubPlayers do
				if inHub and player.Parent then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root then
						local zoneId, action = zoneForPosition(root.Position)
						remotes.HubZoneHint:FireClient(player, zoneId, action)
					end
				end
			end
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
