local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function findHubZones()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return {}
	end

	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return {}
	end

	local anchors = {}
	for _, zoneFolder in zones:GetChildren() do
		local anchor = zoneFolder:FindFirstChild("PromptAnchor")
		if anchor then
			table.insert(anchors, anchor)
		end
	end
	return anchors
end

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then
			gui.Enabled = false
		end
	end
end

local function bindZone(anchor)
	local prompt = anchor:FindFirstChild("ZonePrompt")
	if not prompt then
		return
	end

	local action = anchor:GetAttribute("ZoneAction")
	prompt.Triggered:Connect(function()
		if action == "enterArena" then
			hideBattleUi()
			remotes.EnterArena:FireServer()
		elseif action == "openBeySelect" then
			remotes.OpenBeySelect:FireServer()
		elseif action == "viewLeaderboard" then
			remotes.HubZoneHint:FireServer("leaderboard")
		end
	end)
end

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

remotes.HubZoneHint.OnClientEvent:Connect(function(message)
	if message == "leaderboard" then
		local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
		local board = hub and hub:FindFirstChild("LeaderboardBoard")
		if board then
			local highlight = Instance.new("Highlight")
			highlight.Name = "LeaderboardPulse"
			highlight.FillTransparency = 0.7
			highlight.OutlineColor = Color3.fromRGB(255, 220, 90)
			highlight.Parent = board
			task.delay(1.2, function()
				if highlight.Parent then
					highlight:Destroy()
				end
			end)
		end
	end
end)

remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		hideBattleUi()
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
	end
end)

for _, anchor in findHubZones() do
	bindZone(anchor)
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == HubConfig.HUB_FOLDER_NAME then
		task.defer(function()
			for _, anchor in findHubZones() do
				bindZone(anchor)
			end
		end)
	end
end)
