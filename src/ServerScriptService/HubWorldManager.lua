local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local inArena = {}
local remotes

local function resolvePath(pathStr)
	local current = game
	for segment in string.gmatch(pathStr, "[^.]+") do
		if segment == "Workspace" then
			current = Workspace
		else
			local child = current:FindFirstChild(segment)
			if not child then
				return nil
			end
			current = child
		end
	end
	return current
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1"
	end
	return "Modus: Training"
end

function HubWorldManager.getArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local spawn = resolvePath(path)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return nil
end

function HubWorldManager.getHubSpawn()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		return hub:FindFirstChild("HubSpawn")
	end
	return nil
end

function HubWorldManager.buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = PlayerDataManager.getRankPoints(data),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

function HubWorldManager.sendLobbyPayload(player, inHub)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player, inHub))
end

function HubWorldManager.teleportCharacter(player, target)
	if not target or not player.Character then
		return false
	end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	local offset = Vector3.new(0, 3, 0)
	if target:IsA("SpawnLocation") or target:IsA("BasePart") then
		hrp.CFrame = target.CFrame + offset
		return true
	end
	return false
end

function HubWorldManager.teleportToHub(player)
	inArena[player] = nil
	HubWorldManager.teleportCharacter(player, HubWorldManager.getHubSpawn())
	HubWorldManager.sendLobbyPayload(player, true)
end

function HubWorldManager.teleportToArena(player)
	local arenaSpawn = HubWorldManager.getArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — prüfe Workspace.Arena.ArenaSpawn")
		return false
	end

	inArena[player] = true
	return HubWorldManager.teleportCharacter(player, arenaSpawn)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if not HubWorldManager.isInArena(player) then
			HubWorldManager.teleportToHub(player)
		end
	end)
end

local function onPlayerRemoving(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	PlayerDataManager.save(player)
	inArena[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.setup()
	HubWorldBuilder.build(HubConfig)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		-- Client öffnet BeySelect; Server bestätigt nur den Hub-Status.
		if not HubWorldManager.isInArena(player) then
			HubWorldManager.sendLobbyPayload(player, true)
		end
	end)

	remotes.ShowHallOfFame.OnServerEvent:Connect(function(player)
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player, false))
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
