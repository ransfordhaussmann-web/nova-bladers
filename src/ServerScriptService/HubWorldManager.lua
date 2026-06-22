local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes = RemotesSetup
local playerZone: { [Player]: string? } = {}
local playerLocation: { [Player]: string } = {}

local function getModeLabel(): string
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function getArenaSpawnCFrame(): CFrame
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn") or bowl:FindFirstChild("SpawnLocation")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(0, 10, 0)
end

local function teleportCharacter(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function zoneAtPosition(position: Vector3): string?
	for zoneId, zoneCfg in HubConfig.ZONES do
		local half = zoneCfg.size / 2
		local offset = position - zoneCfg.position
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y + 4 and math.abs(offset.Z) <= half.Z then
			return zoneId
		end
	end
	return nil
end

local function buildLobbyPayload(player: Player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local location = playerLocation[player]
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = location == "hub",
		inArena = location == "arena",
	}
end

function HubWorldManager.sendLobbyReady(player: Player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboardBoard()
	local hub = workspace:FindFirstChild("NovaHub")
	if hub then
		HubWorldBuilder.buildLeaderboardBoard(hub, LeaderboardManager.getTop(5))
	end
end

function HubWorldManager.spawnInHub(player: Player)
	playerLocation[player] = "hub"
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player: Player)
	playerLocation[player] = "hub"
	HubWorldManager.spawnInHub(player)
	HubWorldManager.refreshLeaderboardBoard()
end

function HubWorldManager.enterArena(player: Player)
	playerLocation[player] = "arena"
	teleportCharacter(player, getArenaSpawnCFrame())
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function handleZoneAction(player: Player, zoneId: string)
	local zoneCfg = HubConfig.ZONES[zoneId]
	if not zoneCfg or zoneCfg.action == "none" then
		return
	end

	if playerZone[player] ~= zoneId then
		return
	end

	if zoneCfg.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zoneCfg.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

function HubWorldManager.onPlayerAdded(player: Player)
	playerLocation[player] = "hub"
	playerZone[player] = nil

	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playerLocation[player] == "hub" then
				HubWorldManager.spawnInHub(player)
			elseif playerLocation[player] == "arena" then
				teleportCharacter(player, getArenaSpawnCFrame())
			end
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end

	HubWorldManager.refreshLeaderboardBoard()
end

function HubWorldManager.onPlayerRemoving(player: Player)
	PlayerDataManager.save(player)
	playerZone[player] = nil
	playerLocation[player] = nil
end

function HubWorldManager.startZoneLoop()
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			if playerLocation[player] ~= "hub" then
				continue
			end

			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end

			local currentZone = zoneAtPosition(root.Position)
			if currentZone ~= playerZone[player] then
				playerZone[player] = currentZone
				local hint = ""
				if currentZone then
					hint = HubConfig.ZONES[currentZone].hint
				end
				remotes.HubZoneHint:FireClient(player, {
					zoneId = currentZone,
					hint = hint,
				})
			end
		end
	end)
end

function HubWorldManager.bindRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playerLocation[player] == "hub" and playerZone[player] == "ArenaGate" then
			HubWorldManager.enterArena(player)
			return
		end
		if playerLocation[player] ~= "arena" then
			HubWorldManager.enterArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId: string)
		if typeof(zoneId) ~= "string" then
			return
		end
		handleZoneAction(player, zoneId)
	end)
end

function HubWorldManager.init()
	HubWorldBuilder.build()
	HubWorldManager.bindRemotes()
	HubWorldManager.startZoneLoop()

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)
end

return HubWorldManager
