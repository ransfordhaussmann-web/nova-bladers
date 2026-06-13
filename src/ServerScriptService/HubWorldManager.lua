local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playerState = {}

local function getState(player)
	if not playerState[player] then
		playerState[player] = {
			inArena = false,
			mode = "Training",
			modeLabel = "Modus: Training",
		}
	end
	return playerState[player]
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function makeBillboard(parent, text, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = gui

	return gui
end

local function attachPrompt(part, actionText, objectText, holdDuration)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldManager.buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	local center = HubConfig.HUB_CENTER
	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local platform = makePart({
		Name = "Platform",
		Size = Vector3.new(HubConfig.HUB_PLATFORM_RADIUS * 2, 2, HubConfig.HUB_PLATFORM_RADIUS * 2),
		CFrame = CFrame.new(center + Vector3.new(0, -1, 0)),
		Color = Color3.fromRGB(45, 50, 65),
		Material = Enum.Material.Slate,
		Parent = hubFolder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(center + HubConfig.HUB_SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hubFolder

	local pillarCount = 8
	for i = 1, pillarCount do
		local angle = (i / pillarCount) * math.pi * 2
		local x = math.cos(angle) * (HubConfig.HUB_PLATFORM_RADIUS - 1.5)
		local z = math.sin(angle) * (HubConfig.HUB_PLATFORM_RADIUS - 1.5)
		makePart({
			Name = "Pillar",
			Size = Vector3.new(1.5, 6, 1.5),
			CFrame = CFrame.new(center + Vector3.new(x, 2, z)),
			Color = Color3.fromRGB(55, 60, 75),
			Parent = hubFolder,
		})
	end

	local portalsFolder = Instance.new("Folder")
	portalsFolder.Name = "Portals"
	portalsFolder.Parent = hubFolder

	for portalId, portal in HubConfig.PORTALS do
		local pos = center + portal.offset
		local pad = makePart({
			Name = portalId .. "Portal",
			Size = Vector3.new(6, 1, 6),
			CFrame = CFrame.new(pos),
			Color = portal.color,
			Material = Enum.Material.Neon,
			Parent = portalsFolder,
		})
		pad:SetAttribute("PortalMode", portal.playerMode)
		pad:SetAttribute("ModeLabel", portal.modeLabel)
		makeBillboard(pad, portal.label, 2.5)
		local prompt = attachPrompt(pad, "Betreten", portal.label)
		prompt:SetAttribute("PortalMode", portal.playerMode)
	end

	local beyStation = makePart({
		Name = "BeyStation",
		Size = Vector3.new(5, 3, 5),
		CFrame = CFrame.new(center + HubConfig.BEY_STATION_OFFSET),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Metal,
		Parent = hubFolder,
	})
	makeBillboard(beyStation, "Bey-Auswahl", 2.5)
	attachPrompt(beyStation, "Öffnen", "Bey-Auswahl")

	local statsBoard = makePart({
		Name = "StatsBoard",
		Size = Vector3.new(10, 6, 1),
		CFrame = CFrame.new(center + HubConfig.STATS_BOARD_OFFSET),
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Glass,
		Parent = hubFolder,
	})
	makeBillboard(statsBoard, "Statistiken", 3.5)
	attachPrompt(statsBoard, "Anzeigen", "Statistiken", 0)

	local sign = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(14, 4, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 8, -22)),
		Color = Color3.fromRGB(25, 30, 45),
		Parent = hubFolder,
	})
	makeBillboard(sign, "Nova Bladers Hub", 0)

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)

	return hubFolder
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.HUB_CENTER + Vector3.new(0, 5, -40)
	end

	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end

	local bowl = arena:FindFirstChild("Bowl", true) or arena:FindFirstChild("Floor", true)
	if bowl and bowl:IsA("BasePart") then
		return bowl.Position + Vector3.new(0, bowl.Size.Y * 0.5 + 4, 0)
	end

	return arena:GetPivot().Position + Vector3.new(0, 5, 0)
end

local function getHubSpawnCFrame()
	local center = HubConfig.HUB_CENTER + HubConfig.HUB_SPAWN_OFFSET
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(center)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local state = getState(player)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = state.modeLabel,
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT),
		inHub = not state.inArena,
	}
end

function HubWorldManager.sendLobbyReady(player, showPanel)
	local payload = buildLobbyPayload(player)
	if showPanel then
		payload.showPanel = true
	end
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.isInArena(player)
	return getState(player).inArena
end

function HubWorldManager.returnToHub(player)
	local state = getState(player)
	state.inArena = false

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = getHubSpawnCFrame()
		end
	end

	HubWorldManager.sendLobbyReady(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.sendToArena(player, mode, modeLabel)
	local state = getState(player)
	state.inArena = true
	state.mode = mode or state.mode
	state.modeLabel = modeLabel or state.modeLabel

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(findArenaSpawn())
		end
	end

	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function bindPrompts()
	if not hubFolder then
		return
	end

	for _, descendant in hubFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Triggered:Connect(function(player)
				local parent = descendant.Parent
				if not parent then
					return
				end

				if parent.Name == "BeyStation" then
					remotes.OpenBeySelect:FireClient(player)
					return
				end

				if parent.Name == "StatsBoard" then
					HubWorldManager.sendLobbyReady(player, true)
					return
				end

				local portalMode = descendant:GetAttribute("PortalMode")
					or parent:GetAttribute("PortalMode")
				local modeLabel = parent:GetAttribute("ModeLabel")
				if portalMode then
					HubWorldManager.sendToArena(player, portalMode, modeLabel)
				end
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not getState(player).inArena then
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildHubWorld()
	bindPrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		local state = getState(player)
		HubWorldManager.sendToArena(player, state.mode, state.modeLabel)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
