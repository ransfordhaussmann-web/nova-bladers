local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local inArena = {}
local initialized = false

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count >= 2 then
		return "Modus: 1v1"
	end
	return "Modus: Training"
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function attachPrompt(part, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.actionText
	prompt.ObjectText = zone.label
	prompt.MaxActivationDistance = HubConfig.PROMPT_DISTANCE
	prompt.HoldDuration = HubConfig.PROMPT_HOLD
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("InteractType", zone.interactType)
	prompt.Parent = part
	CollectionService:AddTag(part, "HubInteractable")
	part:SetAttribute("InteractType", zone.interactType)
	return prompt
end

local function buildZone(zoneName, zone)
	local pedestal = makePart({
		Name = zoneName,
		Size = zone.size,
		Position = zone.position,
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = true,
	})
	pedestal.Parent = hubFolder

	local sign = makePart({
		Name = zoneName .. "Sign",
		Size = Vector3.new(zone.size.X, 2, 1),
		Position = zone.position + Vector3.new(0, zone.size.Y * 0.5 + 1.5, 0),
		Color = Color3.fromRGB(20, 22, 30),
		Material = Enum.Material.SmoothPlastic,
	})
	sign.Parent = hubFolder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.label
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	attachPrompt(pedestal, zone)
end

local function buildHubWorld()
	if hubFolder then
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = makePart({
		Name = "HubFloor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
	})
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.HUB_SPAWN
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = hubFolder

	local titleSign = makePart({
		Name = "HubTitle",
		Size = Vector3.new(24, 6, 1),
		Position = Vector3.new(0, 10, -20),
		Color = Color3.fromRGB(18, 20, 28),
		Material = Enum.Material.SmoothPlastic,
	})
	titleSign.Parent = hubFolder

	local titleGui = Instance.new("SurfaceGui")
	titleGui.Face = Enum.NormalId.Front
	titleGui.Parent = titleSign

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "NOVA BLADERS"
	titleLabel.TextColor3 = HubConfig.ACCENT_COLOR
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = titleGui

	local corners = {
		Vector3.new(55, 4, 55),
		Vector3.new(-55, 4, 55),
		Vector3.new(55, 4, -55),
		Vector3.new(-55, 4, -55),
	}
	for index, cornerPos in corners do
		local pillar = makePart({
			Name = "HubPillar" .. index,
			Size = Vector3.new(4, 8, 4),
			Position = cornerPos,
			Color = Color3.fromRGB(45, 50, 65),
			Material = Enum.Material.Concrete,
		})
		pillar.Parent = hubFolder

		local light = Instance.new("PointLight")
		light.Color = HubConfig.ACCENT_COLOR
		light.Brightness = 1.2
		light.Range = 18
		light.Parent = pillar
	end

	for zoneName, zone in HubConfig.ZONES do
		buildZone(zoneName, zone)
	end

	return hubFolder
end

local function getArenaSpawnCFrame()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn then
			return spawn.CFrame
		end
		local floor = arena:FindFirstChildWhichIsA("BasePart", true)
		if floor then
			return floor.CFrame * CFrame.new(HubConfig.ARENA_SPAWN_OFFSET)
		end
	end
	return CFrame.new(HubConfig.ARENA_SPAWN_OFFSET)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function setHubState(player, isInHub)
	player:SetAttribute("InHub", isInHub)
	inArena[player] = not isInHub
	remotes.HubStateChanged:FireClient(player, { inHub = isInHub })
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	})
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendToArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end

	setHubState(player, false)
	teleportCharacter(player, getArenaSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	setHubState(player, true)
	teleportCharacter(player, CFrame.new(HubConfig.HUB_SPAWN))
	sendLobbyReady(player)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	buildHubWorld()
	setHubState(player, true)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				teleportCharacter(player, getArenaSpawnCFrame())
			else
				teleportCharacter(player, CFrame.new(HubConfig.HUB_SPAWN))
			end
		end)
	end)

	sendLobbyReady(player)
end

function HubWorldManager.init()
	if initialized then
		return
	end
	initialized = true

	remotes = RemotesSetup.getRemotes()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not HubWorldManager.isInArena(player) then
			remotes.OpenBeySelect:FireClient(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
