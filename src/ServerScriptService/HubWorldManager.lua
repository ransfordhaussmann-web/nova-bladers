local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playersInHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyPanel(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	end
	playersInHub[player] = true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	remotes.ReturnToHub:FireClient(player)
	remotes.LeaveHubPanel:FireClient(player)
end

local function onEnterArena(player)
	playersInHub[player] = nil
	remotes.LeaveHubPanel:FireClient(player)
	if _G.NovaBladersStartArena then
		_G.NovaBladersStartArena(player)
	end
end

local function onZoneAction(player, action)
	if action == "enterArena" then
		onEnterArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "openLobbyPanel" then
		HubWorldManager.sendLobbyPanel(player)
	end
end

local function wireZonePrompt(prompt)
	prompt.Triggered:Connect(function(player)
		local action = prompt:GetAttribute("ZoneAction")
		if action then
			onZoneAction(player, action)
		end
	end)
end

local function wireHubZones()
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end
	for _, zoneFolder in zones:GetChildren() do
		local pillar = zoneFolder:FindFirstChild("Pillar")
		if pillar then
			local prompt = pillar:FindFirstChild("ZonePrompt")
			if prompt then
				wireZonePrompt(prompt)
			end
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.getOrCreate()
	hubFolder = HubWorldBuilder.build()
	wireHubZones()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				HubWorldManager.teleportToHub(player)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		if player.Character then
			HubWorldManager.teleportToHub(player)
		end
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
