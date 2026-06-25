local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes = nil
local hubModel = nil

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function getPlayerRank(player)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 1
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherPoints = PlayerDataManager.getRankPoints(PlayerDataManager.get(other))
			if otherPoints > points then
				rank += 1
			end
		end
	end
	return rank
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyStats(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	if remotes then
		remotes.CloseHubPanel:FireClient(player)
		remotes.HubReturned:FireClient(player)
	end
end

local function startArena(player)
	if typeof(_G.NovaBladersStartArena) == "function" then
		_G.NovaBladersStartArena(player)
	else
		warn("[NovaBladers] NovaBladersStartArena nicht verfügbar — GameManager in Studio einbinden.")
	end
end

local function openBeySelect(player)
	if remotes then
		remotes.OpenBeySelect:FireClient(player)
	end
end

local function onZoneTriggered(player, action)
	if action == "EnterArena" then
		if remotes then
			remotes.CloseHubPanel:FireClient(player)
		end
		startArena(player)
	elseif action == "OpenBeySelect" then
		openBeySelect(player)
	elseif action == "ShowHubPanel" then
		HubWorldManager.sendLobbyStats(player)
	end
end

local function connectZonePrompts()
	if not hubModel then return end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end

	for _, zone in zones:GetChildren() do
		local prompt = zone:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local action = prompt:GetAttribute("HubAction") or zone:GetAttribute("HubAction")
				if action then
					onZoneTriggered(player, action)
				end
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		HubWorldManager.spawnInHub(player)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if remotes then
			remotes.CloseHubPanel:FireClient(player)
		end
		startArena(player)
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
