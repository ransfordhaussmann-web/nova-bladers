local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}
local remotes
local inHub = {}
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA (" .. count .. " Spieler)"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
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

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	hrp.CFrame = HubWorldBuilder.getSpawnCFrame()
	inHub[player] = true
	inArena[player] = nil
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	if inArena[player] then return end
	if not inHub[player] then return end

	local spawnCFrame = HubWorldBuilder.findArenaSpawn()
	if not spawnCFrame then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden — Workspace.Arena.ArenaSpawn anlegen")
		return
	end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	hrp.CFrame = spawnCFrame
	inHub[player] = nil
	inArena[player] = true
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if not inArena[player] then
			HubWorldManager.teleportToHub(player)
			HubWorldManager.sendLobbyReady(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
	HubWorldManager.sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	inHub[player] = nil
	inArena[player] = nil
	PlayerDataManager.save(player)
end

local function connectRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if not inHub[player] then return end

		if action == "enterArena" then
			HubWorldManager.enterArena(player)
		elseif action == "openBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "showHallPanel" then
			remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
		end
	end)
end

local function connectProximityPrompts()
	local hub = HubWorldBuilder.build()
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, zone in zones:GetChildren() do
		local trigger = zone:FindFirstChild("Trigger")
		if not trigger then continue end
		local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then continue end

		local action = prompt:GetAttribute("HubAction")
		prompt.Triggered:Connect(function(player)
			if not inHub[player] then return end
			if action == "enterArena" then
				HubWorldManager.enterArena(player)
			elseif action == "openBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif action == "showHallPanel" then
				remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	connectRemotes()
	connectProximityPrompts()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
