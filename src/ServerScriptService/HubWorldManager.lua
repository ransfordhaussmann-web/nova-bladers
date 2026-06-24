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
local playerState = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local rank = 0
	for i, entry in ipairs(LeaderboardManager.getTop(50)) do
		if entry.name == player.Name then
			rank = i
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		rankPoints = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		showPanel = false,
	}
end

local function getHubSpawnCFrame()
	local look = HubConfig.SPAWN_LOOK_AT
	local pos = HubConfig.SPAWN_POSITION
	return CFrame.lookAt(pos, look)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = getHubSpawnCFrame()
	end
end

function HubWorldManager.sendLobbyData(player, showPanel)
	local payload = buildPayload(player)
	payload.showPanel = showPanel == true
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.returnToHub(player)
	playerState[player] = "hub"
	HubWorldManager.teleportToHub(player)
	remotes.HubReturned:FireClient(player)
	HubWorldManager.sendLobbyData(player, false)
end

function HubWorldManager.markInArena(player)
	playerState[player] = "arena"
end

local function isNearZone(player, zoneId)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not hubFolder then
		return false
	end

	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return false
	end
	local zonePart = zones:FindFirstChild(zoneId)
	if not zonePart then
		return false
	end

	local distance = (root.Position - zonePart.Position).Magnitude
	return distance <= HubConfig.INTERACT_DISTANCE + 4
end

local function onZoneTriggered(player, zoneId)
	if playerState[player] ~= "hub" then
		return
	end
	if not isNearZone(player, zoneId) then
		return
	end

	if zoneId == "arena_gate" then
		HubWorldManager.markInArena(player)
		if _G.NovaBladersStartArena then
			_G.NovaBladersStartArena(player)
		end
		return
	end

	if zoneId == "bey_lab" then
		remotes.OpenBeySelect:FireClient(player)
		return
	end

	if zoneId == "hall_of_fame" then
		HubWorldManager.sendLobbyData(player, true)
		remotes.ShowHubPanel:FireClient(player, "leaderboard")
	end
end

local function bindZonePrompts()
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local prompt = zonePart:FindFirstChild("ZonePrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					local zoneId = prompt:GetAttribute("ZoneId") or zonePart:GetAttribute("ZoneId")
					if zoneId then
						onZoneTriggered(player, zoneId)
					end
				end)
			end
		end
	end
end

local function onPlayerAdded(player)
	playerState[player] = "hub"
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		if playerState[player] == "hub" then
			task.defer(function()
				HubWorldManager.teleportToHub(player)
			end)
		end
	end)

	local character = player.Character or player.CharacterAdded:Wait()
	task.wait(0.2)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyData(player, false)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	bindZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playerState[player] ~= "hub" then
			return
		end
		HubWorldManager.markInArena(player)
		if _G.NovaBladersStartArena then
			_G.NovaBladersStartArena(player)
		end
	end)

	remotes.CloseHubPanel.OnServerEvent:Connect(function(player)
		HubWorldManager.sendLobbyData(player, false)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
