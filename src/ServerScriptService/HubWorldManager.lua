local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes

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
		inHub = player:GetAttribute("InHub") == true,
	}
end

function HubWorldManager.sendLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function setInHub(player, inHub)
	player:SetAttribute("InHub", inHub)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = HubWorldBuilder.getHubSpawnCFrame()
	setInHub(player, true)
	HubWorldManager.sendLobbyPayload(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnCFrame = HubWorldBuilder.getArenaSpawnCFrame()
	if not spawnCFrame then
		warn("[HubWorldManager] Arena spawn not found — add Workspace.Arena with a Spawn part")
		return
	end

	root.CFrame = spawnCFrame
	setInHub(player, false)
end

local function updateHallOfFameBoard(hub)
	local zone = hub:FindFirstChild("Zones") and hub.Zones:FindFirstChild("HallOfFame")
	if not zone then return end

	local surface = zone:FindFirstChild("LeaderboardSurface")
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Name = "LeaderboardSurface"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 40
		surface.Parent = zone

		local label = Instance.new("TextLabel")
		label.Name = "Board"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		label.BackgroundTransparency = 0.2
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(240, 220, 160)
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = surface
	end

	local lines = { "🏆 Ruhmeshalle", "" }
	local entries = LeaderboardManager.getTop(5)
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	surface.Board.Text = table.concat(lines, "\n")
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local hub = HubWorldBuilder.build()
	updateHallOfFameBoard(hub)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if player:GetAttribute("InHub") ~= true then return end
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToHub(player)
	end)

	remotes.ShowHallOfFame.OnServerEvent:Connect(function(player)
		if player:GetAttribute("InHub") ~= true then return end
		updateHallOfFameBoard(hub)
		remotes.ShowHallOfFame:FireClient(player, LeaderboardManager.getTop(5))
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				HubWorldManager.teleportToHub(player)
			end)
		end)

		if player.Character then
			HubWorldManager.teleportToHub(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(60)
			updateHallOfFameBoard(hub)
		end
	end)
end

return HubWorldManager
