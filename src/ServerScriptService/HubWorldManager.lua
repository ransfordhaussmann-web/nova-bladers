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

local remotes
local hubWorld
local playerZones = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	local bowl = Workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, 4, 0)
	end

	return CFrame.new(0, 6, 0)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateLeaderboardBoard()
	if not hubWorld or not hubWorld.LeaderboardBoard then return end
	local boardGui = hubWorld.LeaderboardBoard:FindFirstChild("BoardGui")
	if not boardGui then return end
	local list = boardGui:FindFirstChild("List")
	if not list then return end

	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP)
	list.Text = formatLeaderboard(entries)
end

local function buildPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP)

	local playerRank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			playerRank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = playerRank,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildPayload(player, inHub))
end

local function getZoneAtPosition(position)
	if not hubWorld or not hubWorld.Zones then return nil end
	for _, zonePart in hubWorld.Zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local localPos = zonePart.CFrame:PointToObjectSpace(position)
			local half = zonePart.Size / 2
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z then
				return zonePart:GetAttribute("ZoneId"), zonePart:GetAttribute("ZoneAction")
			end
		end
	end
	return nil, nil
end

local function getZoneHint(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone.name, zone.hint
		end
	end
	return nil, nil
end

function HubWorldManager.enterArena(player)
	teleportCharacter(player, findArenaSpawn())
	sendLobbyReady(player, false)
end

function HubWorldManager.returnToHub(player)
	if not hubWorld or not hubWorld.Spawn then return end
	teleportCharacter(player, hubWorld.Spawn.CFrame + Vector3.new(0, 3, 0))
	sendLobbyReady(player, true)
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "BeyLab" then
		HubWorldManager.openBeySelect(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		HubWorldManager.returnToHub(player)
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	end
end

local function startZonePolling()
	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and hubWorld and hubWorld.Floor then
					local zoneId, _ = getZoneAtPosition(root.Position)
					local previous = playerZones[player]
					if zoneId ~= previous then
						playerZones[player] = zoneId
						if zoneId then
							local name, hint = getZoneHint(zoneId)
							remotes.HubZoneHint:FireClient(player, {
								zoneId = zoneId,
								name = name,
								hint = hint,
							})
						else
							remotes.HubZoneHint:FireClient(player, { zoneId = nil })
						end
					end
				end
			end
		end
	end)
end

local function startLeaderboardRefresh()
	task.spawn(function()
		while true do
			updateLeaderboardBoard()
			task.wait(HubConfig.LEADERBOARD_REFRESH)
		end
	end)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER
	hubFolder.Parent = Workspace

	hubWorld = HubWorldBuilder.build(hubFolder)
	updateLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			HubWorldManager.handleZoneAction(player, zoneId)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	startZonePolling()
	startLeaderboardRefresh()
end

return HubWorldManager
