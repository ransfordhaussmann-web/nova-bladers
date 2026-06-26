local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local hubFolder = nil
local playersInArena = {}

local function getRemotes()
	return NovaBladers:WaitForChild("Remotes")
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.getHub()
	return hubFolder
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.buildHub()
	hubFolder = HubWorldBuilder.build()
	return hubFolder
end

function HubWorldManager.spawnInHub(player)
	playersInArena[player] = nil
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	local pos = spawn and spawn.Position or HubConfig.SPAWN_OFFSET
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

function HubWorldManager.sendLobbyReady(player)
	local remotes = getRemotes()
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true
	local arenaSpawn = workspace:FindFirstChild("ArenaSpawn", true)
	if arenaSpawn and player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = arenaSpawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end

function HubWorldManager.onPlayerJoin(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		if not HubWorldManager.isInArena(player) then
			task.defer(function()
				HubWorldManager.spawnInHub(player)
			end)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onPlayerLeave(player)
	playersInArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.bindProximityPrompts()
	if not hubFolder then return end

	local arenaPortal = hubFolder:FindFirstChild("ArenaPortal", true)
	if arenaPortal then
		local prompt = arenaPortal:FindFirstChild("ArenaPortalPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				HubWorldManager.sendToArena(player)
			end)
		end
	end

	local beyPedestal = hubFolder:FindFirstChild("BeySelectPedestal", true)
	if beyPedestal then
		local prompt = beyPedestal:FindFirstChild("BeySelectPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				getRemotes().OpenBeySelect:FireClient(player)
			end)
		end
	end
end

function HubWorldManager.init()
	HubWorldManager.buildHub()
	HubWorldManager.bindProximityPrompts()

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerJoin)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerLeave)

	for _, player in Players:GetPlayers() do
		task.spawn(HubWorldManager.onPlayerJoin, player)
	end

	local remotes = getRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)
end

return HubWorldManager
