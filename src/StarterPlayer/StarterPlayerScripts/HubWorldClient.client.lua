local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hub = workspace:WaitForChild(HubConfig.HUB_NAME, 30)
if not hub then
	warn("[HubWorldClient] NovaHub nicht gefunden")
	return
end

local function findPrompt(name)
	local part = hub:FindFirstChild(name, true)
	return part and part:FindFirstChildOfClass("ProximityPrompt")
end

local function updateBoard(partName, guiChildName, text)
	local part = hub:FindFirstChild(partName, true)
	if not part then return end
	local gui = part:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local body = gui:FindFirstChild(guiChildName, true)
	if body then
		body.Text = text
	end
end

Remotes.HubBoardUpdate.OnClientEvent:Connect(function(payload)
	if payload.statsText then
		updateBoard("StatsBoard", "StatsBody", payload.statsText)
	end
	if payload.leaderboardText then
		updateBoard("LeaderboardBoard", "LeaderboardBody", payload.leaderboardText)
	end
end)

local arenaPrompt = findPrompt("ArenaGate")
if arenaPrompt then
	arenaPrompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end
		if not player:GetAttribute("InHub") then return end
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		Remotes.EnterArena:FireServer()
	end)
end

local kioskPrompt = findPrompt("BeyKiosk")
if kioskPrompt then
	kioskPrompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end
		Remotes.OpenBeySelect:FireServer()
	end)
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

player:GetAttributeChangedSignal("InHub"):Connect(function()
	local inHub = player:GetAttribute("InHub")
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby and inHub then
		-- LobbyClient steuert Sichtbarkeit über LobbyReady
	end
end)
