local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function showHubHint()
	local gui = playerGui:FindFirstChild("HubHint")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "HubHint"
		gui.ResetOnSpawn = false
		gui.Parent = playerGui

		local label = Instance.new("TextLabel")
		label.Name = "Hint"
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 12)
		label.Size = UDim2.fromOffset(460, 36)
		label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		label.BackgroundTransparency = 0.25
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamMedium
		label.TextColor3 = Color3.fromRGB(230, 235, 245)
		label.TextSize = 16
		label.Text = "Laufe zu einer Zone: Arena-Tor · Bey-Labor · Ruhmeshalle"
		label.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end
	gui.Enabled = true
end

local function hideHubHint()
	local gui = playerGui:FindFirstChild("HubHint")
	if gui then gui.Enabled = false end
end

local function bindPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	local remoteName = prompt:GetAttribute("RemoteName")
	if typeof(remoteName) ~= "string" then return end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then return end

	prompt.Triggered:Connect(function()
		if remoteName == "EnterArena" then
			hideHubHint()
			local lobby = playerGui:FindFirstChild("Lobby")
			if lobby then lobby.Enabled = false end
			hideBattleUi()
		elseif remoteName == "OpenBeySelect" then
			hideBattleUi()
			local select = playerGui:FindFirstChild("BeySelect")
			if select then select.Enabled = true end
		end
		remote:FireServer()
	end)
end

local function bindHub(hub)
	local zones = hub:WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		local pad = zone:FindFirstChild("Pad")
		if pad then
			local prompt = pad:FindFirstChild("ZonePrompt")
			if prompt then
				bindPrompt(prompt)
			end
		end
	end
end

remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		hideBattleUi()
		showHubHint()
	end
end)

remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	showHubHint()
end)

local existingHub = workspace:FindFirstChild("NovaHub")
if existingHub then
	bindHub(existingHub)
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "NovaHub" then
			bindHub(child)
		end
	end)
end
