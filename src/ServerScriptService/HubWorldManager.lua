local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubFolder
local zones = {}
local leaderboardBoard
local remotes
local playersInHub = {}
local zoneTouchCounts = {}

local function getNovaFolder()
	return ReplicatedStorage:WaitForChild("NovaBladers")
end

local function getRemotes()
	if remotes then return remotes end
	local nova = getNovaFolder()
	local folder = nova:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = nova
	end
	remotes = RemotesSetup.ensure(folder)
	return remotes
end

local function resolveArenaSpawn()
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node:FindFirstChild(name)
		if not node then return nil end
	end
	if node:IsA("BasePart") then
		return node
	end
	return node:FindFirstChildWhichIsA("BasePart")
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT),
		inHub = inHub,
	}
end

function HubWorldManager.refreshLeaderboard()
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, entries)
	for _, player in Players:GetPlayers() do
		if playersInHub[player] then
			getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player, true))
		end
	end
end

local function teleportCharacter(character, position, facing)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.lookAt(position, position + facing)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	teleportCharacter(character, HubConfig.SPAWN_POSITION, HubConfig.SPAWN_FACING)
	playersInHub[player] = true
	getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.teleportToHub(player)
end

local function leaveHub(player)
	playersInHub[player] = nil
	zoneTouchCounts[player] = nil
end

local function enterArena(player)
	leaveHub(player)
	local spawnPart = resolveArenaSpawn()
	local character = player.Character
	if character and spawnPart then
		local offset = spawnPart.CFrame * CFrame.new(0, 3, 0)
		teleportCharacter(character, offset.Position, spawnPart.CFrame.LookVector)
	elseif character then
		teleportCharacter(character, Vector3.new(0, 5, 0), Vector3.new(0, 0, 1))
	end
end

local function openBeySelect(player)
	getRemotes().OpenBeySelect:FireClient(player)
end

local ZONE_ACTIONS = {
	EnterArena = enterArena,
	OpenBeySelect = openBeySelect,
	ViewLeaderboard = function(player)
		getRemotes().HubZoneAction:FireClient(player, "ViewLeaderboard")
	end,
}

local function bindZone(zoneId, zonePart)
	local zoneDef = HubConfig.ZONES[zoneId]
	if not zoneDef then return end

	local marker = zonePart:FindFirstChild("Marker")
	local prompt = marker and marker:FindFirstChild("ZonePrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			local action = ZONE_ACTIONS[zoneDef.action]
			if action then
				action(player)
			end
		end)
	end

	local touchRegion = zonePart:FindFirstChild("TouchRegion")
	if not touchRegion then return end

	touchRegion.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or not playersInHub[player] then return end

		local counts = zoneTouchCounts[player]
		if not counts then
			counts = {}
			zoneTouchCounts[player] = counts
		end
		counts[zoneId] = (counts[zoneId] or 0) + 1

		getRemotes().HubZoneHint:FireClient(player, {
			zoneId = zoneId,
			name = zoneDef.name,
			hint = zoneDef.hint,
			actionLabel = zoneDef.actionLabel,
			entering = true,
		})
	end)

	touchRegion.TouchEnded:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local counts = zoneTouchCounts[player]
		if not counts or not counts[zoneId] then return end
		counts[zoneId] -= 1
		if counts[zoneId] <= 0 then
			counts[zoneId] = nil
			getRemotes().HubZoneHint:FireClient(player, {
				zoneId = zoneId,
				entering = false,
			})
		end
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	playersInHub[player] = true

	local function onCharacter(character)
		task.defer(function()
			if playersInHub[player] then
				HubWorldManager.teleportToHub(player)
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	task.defer(function()
		getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player, true))
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	zoneTouchCounts[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	getRemotes()

	hubFolder, zones, leaderboardBoard = HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboard()

	for zoneId, zonePart in zones do
		bindZone(zoneId, zonePart)
	end

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		enterArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
