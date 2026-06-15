local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local function ensureRemotes()
	local remotes = NovaBladers:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = NovaBladers
	end

	local function remote(name)
		local r = remotes:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = remotes
		end
		return r
	end

	return {
		LobbyReady = remote("LobbyReady"),
		EnterArena = remote("EnterArena"),
		HubZoneHint = remote("HubZoneHint"),
	}
end

local Remotes = ensureRemotes()
local hubRoot = HubWorldBuilder.build()
local playerState = {}

local function modeLabelFor(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		hubEnabled = true,
	}
end

local function sendLobbyReady(player)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(HubConfig.SPAWN)
end

local function setInHub(player, inHub)
	playerState[player] = playerState[player] or {}
	playerState[player].inHub = inHub
	player:SetAttribute("InHub", inHub)
end

local function enterArena(player, mode)
	if not playerState[player] or not playerState[player].inHub then
		return
	end
	setInHub(player, false)
	player:SetAttribute("HubMatchMode", mode or "auto")
	Remotes.EnterArena:FireClient(player, { mode = mode or "auto" })
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	setInHub(player, true)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playerState[player] and playerState[player].inHub then
				teleportToHub(player)
			end
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end

	sendLobbyReady(player)
end

local function wireZonePrompts()
	local zones = hubRoot:WaitForChild("Zones")
	for _, part in zones:GetChildren() do
		local prompt = part:FindFirstChild("HubPrompt")
		if not prompt then continue end

		prompt.Triggered:Connect(function(player)
			local action = prompt:GetAttribute("HubAction")
			if action == "EnterArena" or action == "EnterTraining" then
				local mode = action == "EnterTraining" and "training" or "auto"
				enterArena(player, mode)
			elseif action == "ShowStats" or action == "ShowLeaderboard" then
				sendLobbyReady(player)
				Remotes.HubZoneHint:FireClient(player, {
					zoneId = prompt:GetAttribute("ZoneId"),
					action = action,
				})
			end
		end)
	end
end

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	enterArena(player, "auto")
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local lighting = HubConfig.LIGHTING
Lighting.Ambient = lighting.ambient
Lighting.OutdoorAmbient = lighting.ambient
Lighting.Brightness = lighting.brightness

wireZonePrompts()

return {}
