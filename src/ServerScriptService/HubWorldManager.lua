local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")

local HubWorldManager = {}

local hubRefs = {}
local playerInHub = {}

local function getArenaSpawnCFrame()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_MODEL_NAME)
	if arena then
		local pivot = arena:GetPivot()
		return pivot * CFrame.new(HubConfig.ARENA_SPAWN_OFFSET)
	end
	return CFrame.new(HubConfig.ORIGIN + Vector3.new(0, 6, 80))
end

local function getHubSpawnCFrame()
	if hubRefs.spawn then
		return hubRefs.spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(targetCFrame)
end

local function formatLeaderboardBoard(entries)
	local lines = { "🏆 Top Spieler" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function formatBeyInfoBoard()
	return table.concat({
		"Bey-Labor",
		"Wähle deinen Kämpfer:",
		"Nova Striker · Iron Shell",
		"Volt Dash · Shadow Bite",
	}, "\n")
end

local function updateBoards()
	if hubRefs.leaderboardLabel then
		hubRefs.leaderboardLabel.Text = formatLeaderboardBoard(LeaderboardManager.getTop(5))
	end
	if hubRefs.beyInfoLabel then
		hubRefs.beyInfoLabel.Text = formatBeyInfoBoard()
	end
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
	local hubModel
	hubModel, hubRefs = HubWorldBuilder.build(Workspace)
	updateBoards()
	return hubModel
end

function HubWorldManager.isInHub(player)
	return playerInHub[player] == true
end

function HubWorldManager.sendLobbyReady(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	updateBoards()

	Remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		showPanel = options.showPanel == true,
		inHub = HubWorldManager.isInHub(player),
	})
end

function HubWorldManager.spawnInHub(player)
	playerInHub[player] = true
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player, { showPanel = false })
end

function HubWorldManager.enterArena(player)
	playerInHub[player] = false
	teleportCharacter(player, getArenaSpawnCFrame())
	Remotes.LobbyReady:FireClient(player, {
		inHub = false,
		showPanel = false,
	})
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function onZonePromptTriggered(player, zoneId)
	if zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "BeyLab" then
		Remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyReady(player, { showPanel = true })
	end
end

local function bindZonePrompts()
	if not hubRefs.zonesFolder then
		return
	end

	for _, zoneModel in hubRefs.zonesFolder:GetChildren() do
		local zoneId = zoneModel:GetAttribute("ZoneId")
		local anchor = zoneModel:FindFirstChild("PromptAnchor", true)
		local prompt = anchor and anchor:FindFirstChild("ZonePrompt")
		if prompt and zoneId then
			prompt.Triggered:Connect(function(triggerPlayer)
				onZonePromptTriggered(triggerPlayer, zoneId)
			end)
		end
	end
end

function HubWorldManager.init()
	HubWorldManager.buildHub()
	bindZonePrompts()

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			if playerInHub[player] ~= false then
				task.defer(function()
					HubWorldManager.spawnInHub(player)
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerInHub[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end
end

return HubWorldManager
