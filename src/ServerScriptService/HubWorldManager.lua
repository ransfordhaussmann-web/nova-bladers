local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubFolder
local playerStates = {}
local enterArenaCallbacks = {}

local function getRemotes()
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	local remotes = nova:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = nova
	end
	local function ensure(name, className)
		local remote = remotes:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = remotes
		end
		return remote
	end
	return {
		LobbyReady = ensure("LobbyReady", "RemoteEvent"),
		EnterArena = ensure("EnterArena", "RemoteEvent"),
		OpenBeySelect = ensure("OpenBeySelect", "RemoteEvent"),
	}
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training vs. Dummy"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	else
		return string.format("Modus: FFA (%d Spieler)", count)
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	}
end

function HubWorldManager.sendLobbyReady(player)
	local remotes = getRemotes()
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	if hubFolder then
		HubWorldBuilder.updateLeaderboard(hubFolder, buildLobbyPayload(player).leaderboard)
		HubWorldBuilder.updateModeBoard(hubFolder, getModeLabel())
	end
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = HubWorldBuilder.getSpawnCFrame()
end

function HubWorldManager.returnToHub(player)
	playerStates[player] = "hub"
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.isInHub(player)
	return playerStates[player] == "hub"
end

function HubWorldManager.onEnterArena(callback)
	table.insert(enterArenaCallbacks, callback)
end

local function fireEnterArena(player)
	for _, callback in enterArenaCallbacks do
		task.spawn(callback, player)
	end
end

local function handleEnterArena(player)
	if playerStates[player] ~= "hub" then return end
	playerStates[player] = "entering"
	fireEnterArena(player)
end

local function connectPrompts()
	if not hubFolder then return end

	local portalGate = hubFolder:FindFirstChild("PortalGate", true)
	if portalGate then
		local prompt = portalGate:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				handleEnterArena(triggerPlayer)
			end)
		end
	end

	local kiosk = hubFolder:FindFirstChild("BeySelectKiosk", true)
	if kiosk then
		local prompt = kiosk:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				getRemotes().OpenBeySelect:FireClient(triggerPlayer)
			end)
		end
	end
end

local function onPlayerAdded(player)
	playerStates[player] = "hub"
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		if playerStates[player] == "hub" then
			task.defer(function()
				HubWorldManager.teleportToHub(player)
			end)
		end
	end)

	task.defer(function()
		HubWorldManager.teleportToHub(player)
		HubWorldManager.sendLobbyReady(player)
	end)
end

local function onPlayerRemoving(player)
	playerStates[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	if hubFolder and hubFolder.Parent then
		hubFolder:Destroy()
	end
	hubFolder = HubWorldBuilder.build()
	connectPrompts()

	local remotes = getRemotes()
	remotes.EnterArena.OnServerEvent:Connect(handleEnterArena)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function()
		task.defer(function()
			for _, player in Players:GetPlayers() do
				if playerStates[player] == "hub" then
					HubWorldManager.sendLobbyReady(player)
				end
			end
		end)
	end)
end

return HubWorldManager
