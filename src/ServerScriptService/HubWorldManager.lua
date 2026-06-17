local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local hubFolder
local remotes
local playersInArena = {}

local function getRemotes()
	if remotes then
		return remotes
	end
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	remotes = nova:WaitForChild("Remotes")
	return remotes
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildZoneMarker(parent, zoneKey, zone)
	local marker = Instance.new("Part")
	marker.Name = "Zone_" .. zoneKey
	marker.Anchored = true
	marker.CanCollide = true
	marker.Size = zone.size
	marker.Position = HubConfig.FloorPosition + zone.position
	marker.Color = zone.color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = zone.hint
	prompt.HoldDuration = HubConfig.PromptHoldDuration
	prompt.MaxActivationDistance = HubConfig.PromptMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker

	prompt:SetAttribute("ZoneAction", zone.action)
	prompt:SetAttribute("ZoneHint", zone.hint)

	return marker
end

local function buildWalls(parent, floorSize, floorPos)
	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WallHeight
	local thick = HubConfig.WallThickness

	local walls = {
		{ size = Vector3.new(floorSize.X + thick * 2, wallH, thick), pos = Vector3.new(0, wallH * 0.5, -halfZ - thick * 0.5) },
		{ size = Vector3.new(floorSize.X + thick * 2, wallH, thick), pos = Vector3.new(0, wallH * 0.5, halfZ + thick * 0.5) },
		{ size = Vector3.new(thick, wallH, floorSize.Z), pos = Vector3.new(-halfX - thick * 0.5, wallH * 0.5, 0) },
		{ size = Vector3.new(thick, wallH, floorSize.Z), pos = Vector3.new(halfX + thick * 0.5, wallH * 0.5, 0) },
	}

	for i, wall in walls do
		local part = Instance.new("Part")
		part.Name = "Wall" .. i
		part.Anchored = true
		part.CanCollide = true
		part.Size = wall.size
		part.Position = floorPos + wall.pos
		part.Color = Color3.fromRGB(50, 55, 70)
		part.Material = Enum.Material.Concrete
		part.Parent = parent
	end
end

function HubWorldManager.buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = Workspace:FindFirstChild(HubConfig.HubFolderName)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HubFolderName
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = HubConfig.FloorSize
	floor.Position = HubConfig.FloorPosition
	floor.Color = Color3.fromRGB(45, 50, 65)
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	buildWalls(hubFolder, HubConfig.FloorSize, HubConfig.FloorPosition)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.FloorPosition + HubConfig.SpawnOffset
	spawn.Color = Color3.fromRGB(100, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hubFolder

	for zoneKey, zone in HubConfig.Zones do
		buildZoneMarker(hubFolder, zoneKey, zone)
	end

	local lighting = HubConfig.HubLighting
	Lighting.Ambient = lighting.Ambient
	Lighting.Brightness = lighting.Brightness
	Lighting.ClockTime = lighting.ClockTime

	return hubFolder
end

local function getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ArenaFolderName)
	if not arena then
		return HubConfig.FloorPosition + Vector3.new(0, 6, 40)
	end
	local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return arena:GetPivot().Position + Vector3.new(0, 6, 0)
end

local function getHubSpawn()
	if not hubFolder then
		HubWorldManager.buildHubWorld()
	end
	local spawn = hubFolder:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return HubConfig.FloorPosition + HubConfig.SpawnOffset
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		hubMode = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
	}
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.sendLobbyData(player)
	local payload = buildLobbyPayload(player)
	getRemotes().LobbyReady:FireClient(player, payload)
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true
	teleportCharacter(player, getArenaSpawn())
	getRemotes().HubZoneHint:FireClient(player, { hideHud = true })
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	teleportCharacter(player, getHubSpawn())
	HubWorldManager.sendLobbyData(player)
end

local function onZonePromptTriggered(player, prompt)
	local action = prompt:GetAttribute("ZoneAction")
	if action == "enterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "openBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif action == "showLeaderboard" then
		local payload = buildLobbyPayload(player)
		local lines = { "Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		getRemotes().HubZoneHint:FireClient(player, {
			text = table.concat(lines, "\n"),
			duration = 6,
		})
	end
end

local function connectZonePrompts()
	if not hubFolder then
		return
	end
	for _, descendant in hubFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "ZonePrompt" then
			descendant.Triggered:Connect(function(player)
				onZonePromptTriggered(player, descendant)
			end)

			descendant.PromptShown:Connect(function(player)
				local hint = descendant:GetAttribute("ZoneHint")
				if hint then
					getRemotes().HubZoneHint:FireClient(player, { text = hint })
				end
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	playersInArena[player] = nil

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				teleportCharacter(player, getArenaSpawn())
			else
				teleportCharacter(player, getHubSpawn())
				HubWorldManager.sendLobbyData(player)
			end
		end)
	end)

	if player.Character then
		teleportCharacter(player, getHubSpawn())
	end
	HubWorldManager.sendLobbyData(player)
end

function HubWorldManager.init()
	HubWorldManager.buildHubWorld()
	connectZonePrompts()

	local remoteFolder = getRemotes()
	remoteFolder.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)
	remoteFolder.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
end

return HubWorldManager
