local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubData
local zoneDebounce = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end

	local bowl = workspace:FindFirstChild("Bowl", true)
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(position)
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubData or not hubData.leaderboardBoard then
		return
	end
	HubWorldBuilder.updateLeaderboardBoard(hubData.leaderboardBoard, LeaderboardManager.getTop(5))
end

function HubWorldManager.teleportToHub(player)
	teleportCharacter(player, HubConfig.SPAWN)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Kein Arena-Spawn gefunden (Arena.Spawn / Bowl)")
		return
	end

	local target = spawn.Position + Vector3.new(0, 4, 0)
	if spawn:IsA("BasePart") then
		target = spawn.Position + Vector3.new(0, spawn.Size.Y / 2 + 3, 0)
	end

	teleportCharacter(player, target)
end

local function onZoneTouched(zone, hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local key = player.UserId .. "_" .. zone.Name
	if zoneDebounce[key] then
		return
	end
	zoneDebounce[key] = true
	task.delay(3, function()
		zoneDebounce[key] = nil
	end)

	local hint = zone:GetAttribute("Hint")
	if hint then
		remotes.HubZoneHint:FireClient(player, {
			zoneId = zone:GetAttribute("ZoneId"),
			hint = hint,
		})
	end
end

local function connectZone(zone)
	zone.Touched:Connect(function(hit)
		onZoneTouched(zone, hit)
	end)

	local prompt = zone:FindFirstChild("ZonePrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			local action = prompt:GetAttribute("Action")
			if action == "enterArena" then
				HubWorldManager.enterArena(player)
			elseif action == "openBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			end
		end)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	local function setupCharacter(character)
		HubWorldManager.teleportToHub(player)

		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		HubWorldManager.sendLobbyReady(player)
		HubWorldManager.refreshLeaderboardBoard()
	end

	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubData = HubWorldBuilder.build()

	for _, zone in hubData.zones do
		connectZone(zone)
	end

	HubWorldManager.refreshLeaderboardBoard()

	task.spawn(function()
		while true do
			task.wait(60)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
