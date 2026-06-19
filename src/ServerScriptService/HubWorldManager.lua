local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldManager = {}

local remotes
local playerData
local leaderboard
local inHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function getArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end
	return workspace:FindFirstChild("ArenaSpawn")
end

local function teleportTo(partOrCFrame, character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if typeof(partOrCFrame) == "CFrame" then
		hrp.CFrame = partOrCFrame + Vector3.new(0, 3, 0)
	elseif partOrCFrame:IsA("BasePart") then
		hrp.CFrame = partOrCFrame.CFrame + Vector3.new(0, 3, 0)
	elseif partOrCFrame:IsA("Model") and partOrCFrame.PrimaryPart then
		hrp.CFrame = partOrCFrame.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
	end
end

function HubWorldManager.init(remoteFolder, dataManager, leaderboardManager)
	remotes = remoteFolder
	playerData = dataManager
	leaderboard = leaderboardManager
end

function HubWorldManager.isInHub(player)
	return inHub[player] ~= false
end

function HubWorldManager.buildLobbyPayload(player)
	local data = playerData.get(player)
	local points = playerData.getRankPoints(data)
	leaderboard.submit(player, points)

	local rank = 0
	local ok, entries = pcall(function()
		return leaderboard.getTop(50)
	end)
	if ok then
		for _, entry in entries do
			if entry.name == player.Name then
				rank = entry.rank
				break
			end
		end
	end

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard.getTop(5),
	}
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then
		return
	end
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character
	if not character then
		return
	end

	local hub = workspace:FindFirstChild(HubConfig.FOLDER_NAME)
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn then
		teleportTo(spawn.CFrame, character)
	else
		teleportTo(HubConfig.SPAWN_CFRAME, character)
	end
end

function HubWorldManager.enterArena(player)
	if not HubWorldManager.isInHub(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local arenaSpawn = getArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] ArenaSpawn nicht gefunden — Workspace.Arena.ArenaSpawn anlegen.")
		return
	end

	inHub[player] = false
	teleportTo(arenaSpawn, character)

	remotes.LobbyReady:FireClient(player, {
		inHub = false,
		wins = playerData.get(player).Wins,
		losses = playerData.get(player).Losses,
		rank = 0,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard.getTop(5),
	})
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onPlayerReady(player)
	inHub[player] = true
	playerData.load(player)

	local function onCharacter(character)
		if not HubWorldManager.isInHub(player) then
			return
		end
		task.defer(function()
			HubWorldManager.spawnInHub(player)
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	task.defer(function()
		HubWorldManager.sendLobbyReady(player)
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	inHub[player] = nil
end

return HubWorldManager
