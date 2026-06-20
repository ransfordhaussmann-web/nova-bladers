local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubModel
local remotes

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawn()
	local ws = workspace
	local direct = ws:FindFirstChild("ArenaSpawn")
	if direct and direct:IsA("BasePart") then
		return direct.CFrame + Vector3.new(0, 3, 0)
	end

	local arena = ws:FindFirstChild("Arena")
	if arena then
		local nested = arena:FindFirstChild("ArenaSpawn")
		if nested and nested:IsA("BasePart") then
			return nested.CFrame + Vector3.new(0, 3, 0)
		end
	end

	return HubConfig.ARENA_FALLBACK
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame
end

function HubWorldManager.getHub()
	return hubModel
end

function HubWorldManager.sendLobbyData(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	})
end

function HubWorldManager.teleportToHub(player)
	player:SetAttribute("InArena", false)
	if not hubModel then return end
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame(hubModel))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyData(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	player:SetAttribute("InArena", true)
	teleportCharacter(player, findArenaSpawn())
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)

	local function onCharacter(character)
		task.defer(function()
			if player:GetAttribute("InArena") then return end
			HubWorldManager.teleportToHub(player)
			HubWorldManager.sendLobbyData(player)
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

local function connectZonePrompts()
	if not hubModel then return end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") then continue end

		prompt.Triggered:Connect(function(player)
			local action = prompt:GetAttribute("HubAction")
			if action == "enterArena" then
				HubWorldManager.enterArena(player)
			elseif action == "openBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif action == "showHall" then
				HubWorldManager.sendLobbyData(player)
				remotes.ShowHallPanel:FireClient(player)
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build(workspace)
	connectZonePrompts()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)
end

return HubWorldManager
