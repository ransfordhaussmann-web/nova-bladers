local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local inHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local arena = workspace:FindFirstChild(folderName)
		if arena then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = arena:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
			local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChild("Arena")
			if bowl and bowl:IsA("BasePart") then
				return bowl
			end
		end
	end
	return nil
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_BOARD.maxEntries)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub[player] == true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboard()
	if not hubFolder then return end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_BOARD.maxEntries)
	HubWorldBuilder.updateLeaderboardBoard(hubFolder, entries)
end

function HubWorldManager.spawnInHub(player)
	local hub = hubFolder or workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then return end
	local spawn = hub:FindFirstChild("HubSpawn")
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp or not spawn then return end

	inHub[player] = true
	hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	if not player.Parent then return end
	inHub[player] = true
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	inHub[player] = false
	if spawn then
		hrp.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
	else
		warn("[NovaBladers] Kein Arena-Spawn gefunden — Spieler bleibt im Hub")
		inHub[player] = true
	end
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.openBeySelect(player)
	if not remotes then return end
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.onZoneAction(player, action)
	if action == "EnterArena" then
		HubWorldManager.teleportToArena(player)
	elseif action == "OpenBeySelect" then
		HubWorldManager.openBeySelect(player)
	elseif action == "HallOfFame" then
		HubWorldManager.refreshLeaderboard()
		if remotes then
			remotes.HubZoneHint:FireClient(player, "Ruhmeshalle — Top 5 auf dem Board.")
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build(LeaderboardManager.getTop(HubConfig.LEADERBOARD_BOARD.maxEntries))

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		HubWorldManager.openBeySelect(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inHub[player] = nil
	end)
end

return HubWorldManager
