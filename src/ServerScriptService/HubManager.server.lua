local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorld = require(script.Parent.HubWorld)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")
local HubConfig = require(NovaBladers.HubConfig)

local lobbyReady = Remotes:WaitForChild("LobbyReady")
local enterArena = Remotes:WaitForChild("EnterArena")
local selectMode = Remotes:FindFirstChild("SelectLobbyMode")

local inHub = {}
local preferredMode = {}

local MODE_LABELS = {
	Training = "Modus: Training",
	PvP = "Modus: 1v1 PvP",
	FFA = "Modus: FFA",
}

local function modeLabelFor(player)
	local modeId = preferredMode[player] or "Training"
	return MODE_LABELS[modeId] or MODE_LABELS.Training
end

local function playerCountLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return MODE_LABELS.Training
	elseif count == 2 then
		return MODE_LABELS.PvP
	end
	return MODE_LABELS.FFA
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	HubWorld.updateLeaderboard(leaderboard)

	lobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = preferredMode[player] and modeLabelFor(player) or playerCountLabel(),
		leaderboard = leaderboard,
		inHub = true,
	})
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = HubWorld.getSpawnCFrame()
	end
end

local function enterHub(player)
	inHub[player] = true
	player:SetAttribute("InHub", true)
	player:SetAttribute("InArena", false)
	teleportToHub(player)
	sendLobbyReady(player)
end

local function leaveHub(player)
	inHub[player] = nil
	player:SetAttribute("InHub", false)
	player:SetAttribute("InArena", true)
end

local function onEnterArena(player)
	if not inHub[player] then return end
	leaveHub(player)

	local arenaSpawn = workspace:FindFirstChild("ArenaSpawn")
	if arenaSpawn and arenaSpawn:IsA("BasePart") then
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = arenaSpawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end

local function bindZonePrompts()
	local root = HubWorld.getRoot()
	if not root then return end

	local gate = root:FindFirstChild("ArenaGate")
	if gate then
		local trigger = gate:FindFirstChild("GateTrigger")
		local prompt = trigger and trigger:FindFirstChild("EnterArenaPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onEnterArena(player)
			end)
		end
	end

	local zones = root:FindFirstChild("Zones")
	if not zones then return end

	for _, pad in zones:GetChildren() do
		local modePrompt = pad:FindFirstChild("ModePrompt")
		if modePrompt then
			modePrompt.Triggered:Connect(function(player)
				local modeId = modePrompt:GetAttribute("ModeId")
				if modeId then
					preferredMode[player] = modeId
					if inHub[player] then
						sendLobbyReady(player)
					end
				end
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inHub[player] ~= false then
				enterHub(player)
			end
		end)
	end)

	if player.Character then
		enterHub(player)
	end
end

local function onPlayerRemoving(player)
	inHub[player] = nil
	preferredMode[player] = nil
	PlayerDataManager.save(player)
end

HubWorld.ensure()
bindZonePrompts()

enterArena.OnServerEvent:Connect(onEnterArena)

if selectMode then
	selectMode.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and MODE_LABELS[modeId] then
			preferredMode[player] = modeId
			if inHub[player] then
				sendLobbyReady(player)
			end
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return {
	enterHub = enterHub,
	leaveHub = leaveHub,
	sendLobbyReady = sendLobbyReady,
}
