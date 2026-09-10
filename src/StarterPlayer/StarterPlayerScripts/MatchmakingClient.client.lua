local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:FindFirstChild("QueueStatus")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "QueueStatus"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(300, 120)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Warteschlange"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -16, 0, 52)
	status.Position = UDim2.fromOffset(8, 32)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 13
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.Text = ""
	status.Parent = panel

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveButton"
	leaveBtn.Size = UDim2.fromOffset(110, 28)
	leaveBtn.Position = UDim2.new(1, -118, 1, -36)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 13
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Text = "Verlassen"
	leaveBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveBtn

	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

local panel = gui.Panel

local function formatPlayerList(names)
	if #names == 0 then
		return "—"
	end
	return table.concat(names, ", ")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	panel.Title.Text = "Warteschlange: " .. (payload.modeLabel or payload.modeId or "?")

	local lines = {
		string.format("%d / %d Spieler", payload.position or 0, payload.maxPlayers or 0),
		"Wartend: " .. formatPlayerList(payload.players or {}),
	}

	if payload.pending or payload.arenaBusy then
		table.insert(lines, "⏳ Arena belegt — warte...")
	elseif (payload.position or 0) < (payload.minPlayers or 1) then
		table.insert(lines, string.format("Noch %d Spieler nötig", (payload.minPlayers or 1) - (payload.position or 0)))
	else
		table.insert(lines, "Match startet bald!")
	end

	panel.Status.Text = table.concat(lines, "\n")
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)
