local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inArena = {}

local function resolveArenaCFrame()
	for _, path in HubConfig.ArenaSpawnPaths do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ArenaFallback)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.buildHub()
	return HubWorldBuilder.build()
end

function HubWorldManager.sendLobbyData(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	})
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	inArena[player] = nil
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	HubWorldManager.sendLobbyData(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	inArena[player] = true
	root.CFrame = resolveArenaCFrame()
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not inArena[player] then
				HubWorldManager.teleportToHub(player)
			end
		end)
	end)
	if player.Character and not inArena[player] then
		HubWorldManager.teleportToHub(player)
	end
	HubWorldManager.sendLobbyData(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		-- Bey-Auswahl wird clientseitig geöffnet; Server bestätigt nur den Hub-Kontext.
		if not inArena[player] then
			HubWorldManager.sendLobbyData(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if inArena[player] then return end
		if action == "EnterArena" then
			HubWorldManager.teleportToArena(player)
		elseif action == "OpenBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "ShowHallPanel" then
			remotes.ShowHallPanel:FireClient(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
	end)
end

return HubWorldManager
