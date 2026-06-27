local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local nearestInteract = nil
local lastPayload = nil

local promptGui = Instance.new("ScreenGui")
promptGui.Name = "HubPrompt"
promptGui.ResetOnSpawn = false
promptGui.Enabled = false
promptGui.Parent = player:WaitForChild("PlayerGui")

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "Prompt"
promptLabel.AnchorPoint = Vector2.new(0.5, 1)
promptLabel.Position = UDim2.new(0.5, 0, 0.85, 0)
promptLabel.Size = UDim2.fromOffset(320, 40)
promptLabel.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
promptLabel.BackgroundTransparency = 0.2
promptLabel.Font = Enum.Font.GothamBold
promptLabel.TextColor3 = Color3.new(1, 1, 1)
promptLabel.TextSize = 16
promptLabel.Parent = promptGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = promptLabel

local infoGui = Instance.new("ScreenGui")
infoGui.Name = "HubInfo"
infoGui.ResetOnSpawn = false
infoGui.Enabled = false
infoGui.Parent = player.PlayerGui

local infoFrame = Instance.new("Frame")
infoFrame.Name = "Panel"
infoFrame.AnchorPoint = Vector2.new(0.5, 0.5)
infoFrame.Position = UDim2.fromScale(0.5, 0.5)
infoFrame.Size = UDim2.fromOffset(280, 200)
infoFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
infoFrame.BackgroundTransparency = 0.1
infoFrame.Parent = infoGui

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 10)
infoCorner.Parent = infoFrame

local infoText = Instance.new("TextLabel")
infoText.Name = "Text"
infoText.Size = UDim2.new(1, -20, 1, -20)
infoText.Position = UDim2.fromOffset(10, 10)
infoText.BackgroundTransparency = 1
infoText.Font = Enum.Font.Gotham
infoText.TextColor3 = Color3.new(1, 1, 1)
infoText.TextSize = 14
infoText.TextWrapped = true
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.Parent = infoFrame

local INTERACT_LABELS = {
	EnterArena = "[E] Arena betreten",
	OpenBeySelect = "[E] Bey wählen",
	ShowStats = "[E] Statistiken anzeigen",
	ShowLeaderboard = "[E] Leaderboard anzeigen",
}

local function getHubFolder()
	return workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
end

local function findNearestStation(rootPos)
	local hub = getHubFolder()
	if not hub then return nil end

	local best, bestDist = nil, HubConfig.INTERACT_RANGE
	for _, child in hub:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Interact") then
			local dist = (child.Position - rootPos).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = child
			end
		end
	end
	return best
end

local function formatStats(payload)
	if not payload then return "Keine Daten" end
	return string.format(
		"Wins: %d\nLosses: %d\nRank: %d\n\n%s",
		payload.wins, payload.losses, payload.rank,
		payload.modeLabel or ""
	)
end

local function formatLeaderboard(payload)
	if not payload or not payload.leaderboard then return "Keine Daten" end
	local lines = { "🏆 Top Spieler:" }
	for _, entry in payload.leaderboard do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function hideInfo()
	infoGui.Enabled = false
end

local function doInteract(interactType)
	if interactType == "EnterArena" then
		hideInfo()
		promptGui.Enabled = false
		Remotes.EnterArena:FireServer()
	elseif interactType == "OpenBeySelect" then
		Remotes.OpenBeySelect:FireServer()
	elseif interactType == "ShowStats" then
		infoText.Text = formatStats(lastPayload)
		infoGui.Enabled = true
	elseif interactType == "ShowLeaderboard" then
		infoText.Text = formatLeaderboard(lastPayload)
		infoGui.Enabled = true
	end
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	inHub = state.inHub == true
	promptGui.Enabled = inHub
	if not inHub then
		hideInfo()
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	lastPayload = payload
	if payload.inHub and infoGui.Enabled then
		local interact = nearestInteract and nearestInteract:GetAttribute("Interact")
		if interact == "ShowStats" then
			infoText.Text = formatStats(payload)
		elseif interact == "ShowLeaderboard" then
			infoText.Text = formatLeaderboard(payload)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not inHub then
		promptGui.Enabled = false
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		promptGui.Enabled = false
		return
	end

	nearestInteract = findNearestStation(root.Position)
	if nearestInteract then
		local interactType = nearestInteract:GetAttribute("Interact")
		promptLabel.Text = INTERACT_LABELS[interactType] or "[E] Interagieren"
		promptGui.Enabled = true
	else
		promptGui.Enabled = false
		if infoGui.Enabled and nearestInteract == nil then
			hideInfo()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode == Enum.KeyCode.E and nearestInteract then
		doInteract(nearestInteract:GetAttribute("Interact"))
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
		hideInfo()
	end
end)
