local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local function ensureRemotes()
	local remotes = NovaBladers:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = NovaBladers
	end

	local function remote(name, className)
		local inst = remotes:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = remotes
		end
		return inst
	end

	return {
		LobbyReady = remote("LobbyReady", "RemoteEvent"),
		EnterArena = remote("EnterArena", "RemoteEvent"),
		HubState = remote("HubState", "RemoteEvent"),
	}
end

local Remotes = ensureRemotes()
local hubModel = HubWorldBuilder.build()

local function modeLabelFor(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function rankFor(player, data)
	local points = PlayerDataManager.getRankPoints(data)
	local rank = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherData = PlayerDataManager.get(other)
			if PlayerDataManager.getRankPoints(otherData) > points then
				rank += 1
			end
		end
	end
	return rank + 1
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, points)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankFor(player, data),
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawn = hubModel:FindFirstChild("HubSpawn")
	local target = HubConfig.ORIGIN + HubConfig.SPAWN
	local look = HubConfig.ORIGIN + HubConfig.SPAWN_LOOK
	if spawn and spawn:IsA("BasePart") then
		target = spawn.Position + Vector3.new(0, 3, 0)
	end

	root.CFrame = CFrame.lookAt(target, look)
	player:SetAttribute("InHub", true)
end

local function sendLobbyReady(player)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	Remotes.HubState:FireClient(player, { inHub = true })
end

local function enterArena(player)
	if not player:GetAttribute("InHub") then return end
	player:SetAttribute("InHub", false)
	Remotes.HubState:FireClient(player, { inHub = false })

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(HubConfig.ARENA_SPAWN)
		end
	end
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	if player:GetAttribute("InHub") ~= false then
		player:SetAttribute("InHub", true)
		task.defer(function()
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player:SetAttribute("InHub", true)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Remotes.EnterArena.OnServerEvent:Connect(enterArena)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(function()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InHub") then
			sendLobbyReady(player)
		end
	end
end)
