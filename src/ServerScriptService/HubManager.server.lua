local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubWorldConfig = require(NovaBladers.HubWorldConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
end

local function ensureRemote(name, className)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local LobbyReady = ensureRemote("LobbyReady", "RemoteEvent")
local EnterArena = ensureRemote("EnterArena", "RemoteEvent")
local SelectHubMode = ensureRemote("SelectHubMode", "RemoteEvent")
local HubModeChanged = ensureRemote("HubModeChanged", "RemoteEvent")

local hub = HubWorldBuilder.getOrCreate(workspace)
local playerModes = {}
local DEFAULT_MODE = "Training"

local function getModeLabel(modeId)
	for _, pad in HubWorldConfig.MODE_PADS do
		if pad.id == modeId then
			return pad.modeLabel
		end
	end
	return "Modus: Training"
end

local function getModeConfig(modeId)
	for _, pad in HubWorldConfig.MODE_PADS do
		if pad.id == modeId then
			return pad
		end
	end
	return HubWorldConfig.MODE_PADS[1]
end

local function buildLobbyPayload(player, modeId)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(modeId),
		modeId = modeId,
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
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame(hub)
	player:SetAttribute("NovaInHub", true)
	player:SetAttribute("NovaInArena", false)
end

local function setPlayerMode(player, modeId)
	playerModes[player] = modeId
	player:SetAttribute("NovaSelectedMode", modeId)
	HubModeChanged:FireClient(player, {
		modeId = modeId,
		modeLabel = getModeLabel(modeId),
	})
end

local function sendLobbyReady(player)
	local modeId = playerModes[player] or DEFAULT_MODE
	LobbyReady:FireClient(player, buildLobbyPayload(player, modeId))
end

local function enterArena(player, modeId)
	modeId = modeId or playerModes[player] or DEFAULT_MODE
	local modeConfig = getModeConfig(modeId)

	if #Players:GetPlayers() < modeConfig.minPlayers and modeId ~= "Training" then
		modeId = DEFAULT_MODE
		modeConfig = getModeConfig(modeId)
	end

	setPlayerMode(player, modeId)
	player:SetAttribute("NovaInHub", false)
	player:SetAttribute("NovaInArena", true)

	local arenaCFrame = HubWorldBuilder.findArenaSpawn(modeId)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and arenaCFrame then
			root.CFrame = arenaCFrame
		end
	end

	local payload = buildLobbyPayload(player, modeId)
	payload.inHub = false
	LobbyReady:FireClient(player, payload)
end

local function bindModePads()
	local interactables = hub:FindFirstChild("Interactables")
	if not interactables then
		return
	end

	for _, padConfig in HubWorldConfig.MODE_PADS do
		local pad = interactables:FindFirstChild("ModePad_" .. padConfig.id)
		if not pad then
			continue
		end

		local prompt = pad:FindFirstChild("EnterPrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			continue
		end

		prompt.Triggered:Connect(function(player)
			setPlayerMode(player, padConfig.id)
			enterArena(player, padConfig.id)
		end)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	playerModes[player] = DEFAULT_MODE
	player:SetAttribute("NovaSelectedMode", DEFAULT_MODE)
	player:SetAttribute("NovaInHub", true)
	player:SetAttribute("NovaInArena", false)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player:GetAttribute("NovaInArena") then
				local modeId = playerModes[player] or DEFAULT_MODE
				local arenaCFrame = HubWorldBuilder.findArenaSpawn(modeId)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and arenaCFrame then
					root.CFrame = arenaCFrame
				end
			else
				teleportToHub(player)
			end
			sendLobbyReady(player)
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end
	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.persist(player)
	playerModes[player] = nil
end

EnterArena.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) == "string" and getModeConfig(modeId) then
		enterArena(player, modeId)
		return
	end
	enterArena(player, playerModes[player])
end)

SelectHubMode.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	if not getModeConfig(modeId) then
		return
	end
	setPlayerMode(player, modeId)
	sendLobbyReady(player)
end)

bindModePads()

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
