local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local zoneHint = Instance.new("ScreenGui")
zoneHint.Name = "HubZoneHint"
zoneHint.ResetOnSpawn = false
zoneHint.DisplayOrder = 5
zoneHint.Parent = playerGui

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 0)
hintLabel.Position = UDim2.new(0.5, 0, 0, 12)
hintLabel.Size = UDim2.fromOffset(360, 36)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.fromRGB(230, 236, 255)
hintLabel.TextSize = 16
hintLabel.Text = ""
hintLabel.Visible = false
hintLabel.Parent = zoneHint

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local CHECK_INTERVAL = 0.25
local HINT_RANGE = 18

local function getNearestZone(rootPosition)
	local nearestLabel
	local nearestDist = HINT_RANGE
	for _, zone in CollectionService:GetTagged("HubZone") do
		if zone:IsA("BasePart") then
			local label = zone:GetAttribute("ZoneLabel")
			if label then
				local dist = (zone.Position - rootPosition).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestLabel = label
				end
			end
		end
	end
	return nearestLabel
end

local function zoneHintLoop()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and workspace:FindFirstChild("NovaHub") then
			local label = getNearestZone(root.Position)
			if label then
				hintLabel.Text = label
				hintLabel.Visible = true
			else
				hintLabel.Visible = false
			end
		else
			hintLabel.Visible = false
		end
		task.wait(CHECK_INTERVAL)
	end
end

task.spawn(zoneHintLoop)

local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not payload.inHub then
		return
	end
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then
		return
	end
	local screen = hub:FindFirstChild("Leaderboard", true)
	if not screen then
		return
	end
	local gui = screen:FindFirstChild("HubLeaderboardGui")
	local body = gui and gui:FindFirstChild("Body")
	if body and payload.leaderboard then
		local lines = {}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		body.Text = if #lines > 0 then table.concat(lines, "\n") else "Noch keine Einträge"
	end
end)
