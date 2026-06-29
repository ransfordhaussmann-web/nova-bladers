local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")
local LobbyReady = Remotes:WaitForChild("LobbyReady")
local EnterArena = Remotes:WaitForChild("EnterArena")

local hubPlayers = {}
local hubBuilt = false

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
		inHub = true,
	}
end

local function sendLobbyReady(player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET)
end

local function ensureHub()
	if hubBuilt then return end
	HubWorldBuilder.build(Workspace)
	hubBuilt = true
end

local function setPlayerInHub(player, inHub)
	hubPlayers[player] = inHub or nil
	player:SetAttribute("InHub", inHub == true)
end

local function enterArena(player)
	if not hubPlayers[player] then return end
	setPlayerInHub(player, false)

	local arena = Workspace:FindFirstChild("Arena") or Workspace:FindFirstChild("BowlArena")
	if arena then
		local spawn = arena:FindFirstChild("SpawnLocation", true)
			or arena:FindFirstChild("ArenaSpawn", true)
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				if spawn and spawn:IsA("BasePart") then
					root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
				else
					root.CFrame = CFrame.new(0, 5, 0)
				end
			end
		end
	end

	-- GameManager in Studio handles match start; signal via attribute
	player:SetAttribute("EnterArenaRequested", true)
end

local function onPlayerAdded(player)
	ensureHub()
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if hubPlayers[player] ~= false then
			setPlayerInHub(player, true)
			teleportToHub(player)
			sendLobbyReady(player)
		end
	end)

	if player.Character then
		setPlayerInHub(player, true)
		teleportToHub(player)
	end
	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	hubPlayers[player] = nil
end

ensureHub()

EnterArena.OnServerEvent:Connect(enterArena)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return {
	sendLobbyReady = sendLobbyReady,
	returnToHub = function(player)
		setPlayerInHub(player, true)
		teleportToHub(player)
		sendLobbyReady(player)
	end,
}
