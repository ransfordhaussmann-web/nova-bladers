local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes = RemotesSetup
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.pushLobbyState(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = LeaderboardManager.getPlayerRank(player.UserId),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
	})
end

function HubWorldManager.sendToArena(player)
	inArena[player] = true
	remotes.HubState:FireClient(player, { inHub = false })
	teleportCharacter(player, HubWorldBuilder.getArenaSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	remotes.HubState:FireClient(player, { inHub = true })
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
	HubWorldManager.pushLobbyState(player)
end

local function onZoneTriggered(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "arena" then
		HubWorldManager.sendToArena(player)
	elseif action == "beySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "stats" then
		HubWorldManager.pushLobbyState(player)
	end
end

local function connectZonePrompts(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, pedestal in zones:GetChildren() do
		local prompt = pedestal:FindFirstChild("HubPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, prompt:GetAttribute("ZoneAction"))
			end)
		end
	end
end

function HubWorldManager.init()
	HubWorldBuilder.build()

	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		connectZonePrompts(hub)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInArena(player) then
			return
		end
		HubWorldManager.sendToArena(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		HubWorldManager.pushLobbyState(player)
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	inArena[player] = nil

	local function spawnInHub(character)
		task.defer(function()
			teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
			remotes.HubState:FireClient(player, { inHub = true })
			HubWorldManager.pushLobbyState(player)
		end)
	end

	if player.Character then
		spawnInHub(player.Character)
	end
	player.CharacterAdded:Connect(spawnInHub)
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

return HubWorldManager
