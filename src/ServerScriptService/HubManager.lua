local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubBuilder = require(script.Parent.HubBuilder)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubManager = {}

local hubModel
local remotes

local function getRemotes()
	if remotes then
		return remotes
	end
	local folder = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	remotes = {
		LobbyReady = folder:WaitForChild("LobbyReady"),
		EnterArena = folder:WaitForChild("EnterArena"),
		OpenBeySelect = folder:FindFirstChild("OpenBeySelect"),
		HubZoneAction = folder:FindFirstChild("HubZoneAction"),
	}
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

local function getSpawnCFrame()
	local spawn = hubModel and hubModel:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

function HubManager.getHub()
	return hubModel
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	hrp.CFrame = getSpawnCFrame()
end

function HubManager.sendLobbyState(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local remoteList = getRemotes()

	remoteList.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	})
end

function HubManager.enterLobby(player)
	HubManager.teleportToHub(player)
	HubManager.sendLobbyState(player)
end

local function onCharacterAdded(player, character)
	task.defer(function()
		if player:GetAttribute("InMatch") then
			return
		end
		HubManager.enterLobby(player)
	end)
end

function HubManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function HubManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
end

function HubManager.handleZoneAction(player, action)
	if action == "enterArena" then
		player:SetAttribute("InMatch", true)
		getRemotes().EnterArena:FireClient(player)
	elseif action == "openBeySelect" then
		local remoteList = getRemotes()
		if remoteList.OpenBeySelect then
			remoteList.OpenBeySelect:FireClient(player)
		end
	elseif action == "showStats" then
		HubManager.sendLobbyState(player)
	end
end

function HubManager.init()
	getRemotes()
	hubModel = HubBuilder.build()

	for _, player in Players:GetPlayers() do
		HubManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubManager.onPlayerRemoving)
end

return HubManager
