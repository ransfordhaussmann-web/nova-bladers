local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubConfig = require(NovaBladers.HubConfig)
local RemotesSetup = require(NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hub
local remotes
local playerZones = {}
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn then
			if spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
			if spawn:IsA("SpawnLocation") then
				return spawn.CFrame
			end
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 3, 0)
	end

	return CFrame.new(0, 8, 0)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(targetCFrame)
end

local function formatLeaderboardLines(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

function HubWorldManager.updateLeaderboardBoard()
	if not hub then return end
	local label = HubWorldBuilder.getLeaderboardBoard(hub)
	if not label then return end
	local entries = LeaderboardManager.getTop(5)
	label.Text = formatLeaderboardLines(entries)
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function setPlayerZone(player, zoneId)
	local previous = playerZones[player]
	if previous == zoneId then return end
	playerZones[player] = zoneId

	if inArena[player] then return end

	if zoneId then
		local zoneData = HubConfig.ZONES[zoneId]
		if zoneData then
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zoneId,
				name = zoneData.name,
				hint = zoneData.hint,
				action = zoneData.action,
				visible = true,
			})
		end
	elseif previous then
		remotes.HubZoneHint:FireClient(player, { visible = false })
	end
end

local function bindZoneDetection(zonePart)
	local zoneId = zonePart:GetAttribute("ZoneId")
	if not zoneId then return end

	zonePart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or inArena[player] then return end
		setPlayerZone(player, zoneId)
	end)
end

local function startZonePolling()
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in Players:GetPlayers() do
				if not inArena[player] then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root then
						local foundZone
						local zonesFolder = hub and hub:FindFirstChild("Zones")
						if zonesFolder then
							for _, zonePart in zonesFolder:GetChildren() do
								if zonePart:IsA("BasePart") then
									local localPos = zonePart.CFrame:PointToObjectSpace(root.Position)
									local half = zonePart.Size / 2
									if math.abs(localPos.X) <= half.X
										and math.abs(localPos.Y) <= half.Y + 4
										and math.abs(localPos.Z) <= half.Z
									then
										foundZone = zonePart:GetAttribute("ZoneId")
										break
									end
								end
							end
						end

						if playerZones[player] and not foundZone then
							setPlayerZone(player, nil)
						elseif foundZone and playerZones[player] ~= foundZone then
							setPlayerZone(player, foundZone)
						end
					end
				end
			end
		end
	end)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	setPlayerZone(player, nil)
	remotes.HubZoneHint:FireClient(player, { visible = false })
	teleportCharacter(player, findArenaSpawnCFrame())
	sendLobbyReady(player, false)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	if not hub then return end
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame(hub))
	sendLobbyReady(player, true)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	HubWorldManager.updateLeaderboardBoard()

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then return end
			teleportCharacter(player, HubWorldBuilder.getSpawnCFrame(hub))
			sendLobbyReady(player, true)
		end)
	end)

	if player.Character then
		teleportCharacter(player, HubWorldBuilder.getSpawnCFrame(hub))
	end
	sendLobbyReady(player, true)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	inArena[player] = nil
end

local function onHubZoneAction(player, action)
	if inArena[player] then return end
	if action == "arena" then
		HubWorldManager.enterArena(player)
	elseif action == "beySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	local zonesFolder = hub:FindFirstChild("Zones")
	if zonesFolder then
		for _, zonePart in zonesFolder:GetChildren() do
			bindZoneDetection(zonePart)
		end
	end

	startZonePolling()
	HubWorldManager.updateLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)
	remotes.HubZoneAction.OnServerEvent:Connect(onHubZoneAction)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
