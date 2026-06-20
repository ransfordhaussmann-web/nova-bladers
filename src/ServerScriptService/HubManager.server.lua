local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubConfig = require(NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")
local LobbyReady = Remotes:WaitForChild("LobbyReady")
local EnterArena = Remotes:WaitForChild("EnterArena")
local HubZoneAction = Remotes:FindFirstChild("HubZoneAction")
if not HubZoneAction then
	HubZoneAction = Instance.new("RemoteEvent")
	HubZoneAction.Name = "HubZoneAction"
	HubZoneAction.Parent = Remotes
end

local EnterArenaBridge = NovaBladers:FindFirstChild("EnterArenaBridge")
if not EnterArenaBridge then
	EnterArenaBridge = Instance.new("BindableEvent")
	EnterArenaBridge.Name = "EnterArenaBridge"
	EnterArenaBridge.Parent = NovaBladers
end

local hubModel = workspace:FindFirstChild("HubWorld")
if not hubModel then
	hubModel = HubWorldBuilder.build(HubConfig.ORIGIN)
end

local function modeLabelFor(playerCount)
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
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function sendLobbyReady(player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame(HubConfig.ORIGIN)
end

local function enterArena(player)
	EnterArenaBridge:Fire(player)
end

local function onHubAction(player, action)
	if action == "enterArena" then
		enterArena(player)
	elseif action == "openBeySelect" or action == "showLeaderboard" or action == "showStats" then
		HubZoneAction:FireClient(player, action, buildLobbyPayload(player))
	end
end

local function connectZonePrompts()
	for _, descendant in hubModel:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "HubPrompt" then
			descendant.Triggered:Connect(function(player)
				local action = descendant:GetAttribute("HubAction")
				if action then
					onHubAction(player, action)
				end
			end)
		end
	end
end

connectZonePrompts()

EnterArena.OnServerEvent:Connect(enterArena)

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end)

	if player.Character then
		task.defer(function()
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return {
	sendLobbyReady = sendLobbyReady,
	teleportToHub = teleportToHub,
	getHubModel = function()
		return hubModel
	end,
}
