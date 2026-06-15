local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubBuilder = require(ReplicatedStorage.NovaBladers.HubBuilder)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local novaFolder = ReplicatedStorage:WaitForChild("NovaBladers")
local remotesFolder = novaFolder:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = novaFolder

local function ensureRemote(name, className)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local lobbyReadyRemote = ensureRemote("LobbyReady", "RemoteEvent")
local enterArenaRemote = ensureRemote("EnterArena", "RemoteEvent")
local returnHubRemote = ensureRemote("ReturnToHub", "RemoteEvent")

local hubModel = HubBuilder.build(Workspace)
HubBuilder.applyLighting()

local function getModeLabel(playerCount)
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
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubBuilder.getSpawnCFrame()
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = HubConfig.HUB_WALK_SPEED
		humanoid.JumpPower = 50
	end

	player:SetAttribute("InHub", true)
	player:SetAttribute("InArena", false)
end

local function sendLobbyReady(player)
	lobbyReadyRemote:FireClient(player, buildLobbyPayload(player))
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)

	player:SetAttribute("InHub", true)
	player:SetAttribute("InArena", false)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if player:GetAttribute("InArena") then
				return
			end
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end

	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

local function onEnterArena(player)
	if player:GetAttribute("InArena") then
		return
	end

	player:SetAttribute("InHub", false)
	player:SetAttribute("InArena", true)
end

local function onReturnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player)
end

local arenaGate = hubModel:WaitForChild("ArenaGate")
local gatePrompt = arenaGate:WaitForChild("EnterArenaPrompt")
gatePrompt.Triggered:Connect(onEnterArena)

enterArenaRemote.OnServerEvent:Connect(onEnterArena)
returnHubRemote.OnServerEvent:Connect(onReturnToHub)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return {
	sendLobbyReady = sendLobbyReady,
	teleportToHub = teleportToHub,
	onReturnToHub = onReturnToHub,
	getHubModel = function()
		return hubModel
	end,
}
