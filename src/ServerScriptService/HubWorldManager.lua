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
local hubFolder
local playersInArena = {}

local function modeLabelForPlayerCount(count)
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	local bowl = workspace:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return nil
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
end

local function buildLobbyPayload(player, opts)
	opts = opts or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local activePlayers = #Players:GetPlayers()
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelForPlayerCount(activePlayers),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = opts.inHub == true,
		inArena = opts.inArena == true,
	}
end

local function sendLobbyReady(player, opts)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, opts))
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(hubFolder, entries)
end

function HubWorldManager.spawnInHub(player)
	playersInArena[player] = nil
	teleportCharacter(player, HubConfig.SPAWN)
	sendLobbyReady(player, { inHub = true })
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function enterArena(player)
	local spawnPart = findArenaSpawn()
	if not spawnPart then
		warn("[NovaBladers] Kein Arena-Spawn gefunden (Workspace.Arena.Spawn oder Bowl.Spawn)")
		return
	end

	playersInArena[player] = true
	teleportCharacter(player, spawnPart.Position + Vector3.new(0, 3, 0))
	sendLobbyReady(player, { inArena = true })

	local hud = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = true
	end
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function onPromptTriggered(prompt, player)
	local action = prompt:GetAttribute("HubAction")
	if action == "arena" then
		enterArena(player)
	elseif action == "beySelect" then
		openBeySelect(player)
	elseif action == "leaderboard" then
		refreshLeaderboardBoard()
		local zoneId = prompt:GetAttribute("HubZoneId")
		local zone = HubConfig.Zones[3]
		for _, z in HubConfig.Zones do
			if z.id == zoneId then
				zone = z
				break
			end
		end
		remotes.HubZoneHint:FireClient(player, {
			zoneId = zoneId,
			title = zone.name,
			text = HubWorldBuilder.formatLeaderboard(LeaderboardManager.getTop(5)),
		})
	end
end

local function bindZonePrompts()
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, part in zones:GetDescendants() do
		if part:IsA("ProximityPrompt") and part.Name == "HubPrompt" then
			part.Triggered:Connect(function(player)
				onPromptTriggered(part, player)
			end)
		end
	end
end

local function onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	local function onCharacter()
		task.defer(function()
			if playersInArena[player] then
				return
			end
			HubWorldManager.spawnInHub(player)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter()
	end
end

local function onPlayerRemoving(player)
	playersInArena[player] = nil
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	local entries = LeaderboardManager.getTop(5)
	hubFolder = HubWorldBuilder.build(HubWorldBuilder.formatLeaderboard(entries))
	bindZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
