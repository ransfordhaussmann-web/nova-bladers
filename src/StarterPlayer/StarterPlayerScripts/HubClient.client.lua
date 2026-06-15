local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hubRoot = workspace:WaitForChild(HubConfig.ROOT_NAME, 30)
local zonesFolder = hubRoot and hubRoot:WaitForChild("Zones", 10)

local function findZonePart(zoneId)
	if not zonesFolder then return nil end
	return zonesFolder:FindFirstChild(zoneId)
end

local function setSurfaceBody(zoneId, text)
	local part = findZonePart(zoneId)
	if not part then return end
	local gui = part:FindFirstChild("HubDisplay")
	if not gui then return end
	local body = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Body")
	if body then
		body.Text = text
	end
end

local function formatStats(payload)
	return string.format(
		"Wins: %d\nLosses: %d\nRang: %d\n\n%s",
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or ""
	)
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateWorldDisplays(payload)
	setSurfaceBody("StatsTerminal", formatStats(payload))
	setSurfaceBody("Leaderboard", formatLeaderboard(payload.leaderboard or {}))
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubEnabled then
		updateWorldDisplays(payload)
	end
end)

-- Context hint when player uses a terminal prompt
Remotes.HubZoneHint.OnClientEvent:Connect(function(data)
	local part = findZonePart(data.zoneId)
	if not part then return end
	local billboard = part:FindFirstChild("HubLabel")
	if not billboard then return end
	local label = billboard:FindFirstChildOfClass("TextLabel")
	if not label then return end
	local original = label.Text
	label.Text = "✓ " .. original
	task.delay(1.2, function()
		if label.Parent then
			label.Text = original
		end
	end)
end)

-- Subtle floor marker pulse at training pad
local trainingPad = findZonePart("TrainingPad")
if trainingPad then
	local baseColor = trainingPad.Color
	RunService.Heartbeat:Connect(function()
		if not trainingPad.Parent then return end
		local t = os.clock() * 2
		local blend = (math.sin(t) + 1) * 0.5
		trainingPad.Color = baseColor:Lerp(Color3.fromRGB(180, 180, 255), blend * 0.35)
	end)
end

return {}
