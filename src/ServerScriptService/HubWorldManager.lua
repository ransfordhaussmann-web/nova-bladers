local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubBuilt = false
local playersInHub = {}

local function resolveArenaSpawn()
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("BasePart") then
		return node
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.refreshLeaderboardBoard()
	local listLabel = HubWorldBuilder.getLeaderboardList()
	if not listLabel then return end

	local entries = LeaderboardManager.getTop(5)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		listLabel.Text = "Noch keine Einträge.\nSei der Erste!"
	else
		listLabel.Text = table.concat(lines, "\n")
	end
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end

	hrp.CFrame = HubConfig.SPAWN * CFrame.new(0, 2, 0)
	playersInHub[player] = true
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.enterArena(player)
	local spawnPart = resolveArenaSpawn()
	if not spawnPart then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Workspace.Arena.Bowl.Spawn anlegen.")
		return
	end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	playersInHub[player] = nil
	hrp.CFrame = spawnPart.CFrame * CFrame.new(0, 3, 0)
	remotes.HubZoneHint:FireClient(player, { visible = false })
end

function HubWorldManager.returnToHub(player)
	if not player or not player.Parent then return end
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
	HubWorldManager.refreshLeaderboardBoard()
end

local function onZonePromptTriggered(prompt, player)
	local zonePart = prompt.Parent
	if not zonePart or not zonePart:IsA("BasePart") then return end

	local action = zonePart:GetAttribute("ZoneAction")
	if action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowLeaderboard" then
		HubWorldManager.refreshLeaderboardBoard()
		remotes.HubZoneHint:FireClient(player, {
			visible = true,
			title = zonePart:GetAttribute("ZoneName") or "Ruhmeshalle",
			text = "Rangliste am Board rechts — kämpfe für deinen Platz!",
		})
	end
end

local function bindZonePrompts(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onZonePromptTriggered(prompt, player)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	playersInHub[player] = true

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playersInHub[player] == true then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local hub = HubWorldBuilder.build()
	hubBuilt = true
	bindZonePrompts(hub)
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
