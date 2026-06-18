local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = NovaBladers

local function ensureRemote(name: string): RemoteEvent
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local LobbyReady = ensureRemote("LobbyReady")
local EnterArena = ensureRemote("EnterArena")
local HubZoneAction = ensureRemote("HubZoneAction")

local inArena: { [Player]: boolean } = {}

local function getModeLabel(playerCount: number): string
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player: Player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not inArena[player],
	}
end

local function sendLobbyReady(player: Player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function teleportToHub(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame() + Vector3.new(0, 3, 0)
	inArena[player] = false
	player:SetAttribute("InArena", false)
	player:SetAttribute("InHub", true)
end

local function teleportToArena(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.ARENA_SPAWN)
	inArena[player] = true
	player:SetAttribute("InArena", true)
	player:SetAttribute("InHub", false)
end

local function onPlayerAdded(player: Player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	inArena[player] = false
	player:SetAttribute("InHub", true)
	player:SetAttribute("InArena", false)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then
				teleportToArena(player)
			else
				teleportToHub(player)
				sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end
	sendLobbyReady(player)
end

local function onPlayerRemoving(player: Player)
	PlayerDataManager.save(player)
	inArena[player] = nil
end

EnterArena.OnServerEvent:Connect(function(player: Player)
	if inArena[player] then
		return
	end
	teleportToArena(player)
end)

HubZoneAction.OnServerEvent:Connect(function(player: Player, action: string)
	if typeof(action) ~= "string" or inArena[player] then
		return
	end

	if action == "enterArena" then
		teleportToArena(player)
	elseif action == "openStats" then
		sendLobbyReady(player)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

HubWorldBuilder.build()

return {
	sendLobbyReady = sendLobbyReady,
	teleportToHub = teleportToHub,
	teleportToArena = teleportToArena,
}
