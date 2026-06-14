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

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function makePart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function addPrompt(part, actionText, objectText, keyCode)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = keyCode
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function buildZone(folder, zoneId, zoneConfig)
	local zone = Instance.new("Model")
	zone.Name = zoneId
	zone.Parent = folder

	local base = makePart("Base", zoneConfig.size, zoneConfig.position, zoneConfig.color, zone)
	base:SetAttribute("ZoneId", zoneId)

	local prompt = addPrompt(base, zoneConfig.promptText, zoneId, zoneConfig.promptKey)
	prompt.Name = "ZonePrompt"

	if zoneId == "ArenaGate" then
		local arch = makePart(
			"Arch",
			Vector3.new(zoneConfig.size.X + 2, 2, 1),
			zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2 + 1, 0),
			Color3.fromRGB(40, 60, 100),
			zone
		)
		arch.CanCollide = false
	elseif zoneId == "BeyShop" then
		local sign = makePart(
			"Sign",
			Vector3.new(6, 2, 0.5),
			zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2 + 1.5, -zoneConfig.size.Z / 2),
			Color3.fromRGB(200, 140, 40),
			zone
		)
		sign.CanCollide = false
	elseif zoneId == "StatsBoard" then
		local board = makePart(
			"Board",
			Vector3.new(zoneConfig.size.X - 1, zoneConfig.size.Y - 1, 0.4),
			zoneConfig.position,
			Color3.fromRGB(30, 30, 40),
			zone
		)
		board.CanCollide = false

		local gui = Instance.new("SurfaceGui")
		gui.Name = "StatsSurface"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "StatsLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(230, 230, 240)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = "Nova Bladers\nStats laden..."
		label.Parent = gui
	end

	return zone
end

local function buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		HubConfig.SPAWN_POSITION - Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 2, 0),
		Color3.fromRGB(55, 58, 68),
		hubFolder
	)
	floor.Material = Enum.Material.Slate

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hubFolder

	for zoneId, zoneConfig in HubConfig.ZONES do
		buildZone(hubFolder, zoneId, zoneConfig)
	end

	return hubFolder
end

local function getArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end
	local spawn = arena:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	return arena:FindFirstChildWhichIsA("SpawnLocation", true)
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

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		hubMode = true,
	}
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.sendToArena(player)
	local spawn = getArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Arena-Spawn nicht gefunden — Workspace." .. HubConfig.ARENA_FOLDER_NAME)
		return false
	end

	inArena[player] = true
	local offset = HubConfig.ARENA_SPAWN_OFFSET
	teleportCharacter(player, spawn.Position + offset)
	return true
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	teleportCharacter(player, HubConfig.SPAWN_POSITION)

	local payload = HubWorldManager.buildLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
end

local function onZoneTriggered(player, zoneId)
	if zoneId == "ArenaGate" then
		if HubWorldManager.sendToArena(player) then
			remotes.EnterArena:FireClient(player)
		end
	elseif zoneId == "BeyShop" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "StatsBoard" then
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end
end

local function wireZonePrompts()
	for _, zone in hubFolder:GetChildren() do
		if not zone:IsA("Model") then
			continue
		end
		local base = zone:FindFirstChild("Base")
		local prompt = base and base:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, zone.Name)
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	inArena[player] = nil

	player.CharacterAdded:Connect(function()
		if not HubWorldManager.isInArena(player) then
			task.defer(function()
				teleportCharacter(player, HubConfig.SPAWN_POSITION)
			end)
		end
	end)

	task.defer(function()
		remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	end)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	buildHubWorld()
	wireZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if HubWorldManager.sendToArena(player) then
			remotes.EnterArena:FireClient(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
