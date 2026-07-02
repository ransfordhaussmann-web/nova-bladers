local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local mobile = player:WaitForChild("PlayerGui"):WaitForChild("MobileControls")
local inMatch = false
local joystickDir = Vector3.zero

if UserInputService.TouchEnabled then
	mobile.Enabled = false

	local joystickBase = Instance.new("Frame")
	joystickBase.Name = "JoystickBase"
	joystickBase.Size = UDim2.fromOffset(120, 120)
	joystickBase.Position = UDim2.new(0, 24, 1, -144)
	joystickBase.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
	joystickBase.BackgroundTransparency = 0.4
	joystickBase.Parent = mobile

	local baseCorner = Instance.new("UICorner")
	baseCorner.CornerRadius = UDim.new(1, 0)
	baseCorner.Parent = joystickBase

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(48, 48)
	knob.Position = UDim2.new(0.5, -24, 0.5, -24)
	knob.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
	knob.Parent = joystickBase

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local function makeActionButton(name, text, position, color)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.fromOffset(64, 64)
		btn.Position = position
		btn.BackgroundColor3 = color
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = text
		btn.Parent = mobile
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = btn
		return btn
	end

	local chargeBtn = makeActionButton("Charge", "Charge", UDim2.new(1, -200, 1, -80), Color3.fromRGB(255, 180, 60))
	local dodgeBtn = makeActionButton("Dodge", "Dodge", UDim2.new(1, -120, 1, -160), Color3.fromRGB(100, 200, 255))
	local specialBtn = makeActionButton("Special", "Special", UDim2.new(1, -80, 1, -80), Color3.fromRGB(180, 80, 255))

	local touchInput = nil
	local charging = false
	local dodgeQueued = false
	local specialQueued = false

	joystickBase.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchInput = input
		end
	end)

	joystickBase.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and touchInput then
			local center = joystickBase.AbsolutePosition + joystickBase.AbsoluteSize / 2
			local delta = Vector2.new(input.Position.X, input.Position.Y) - center
			local maxDist = 36
			if delta.Magnitude > maxDist then
				delta = delta.Unit * maxDist
			end
			knob.Position = UDim2.new(0.5, delta.X - 24, 0.5, delta.Y - 24)
			joystickDir = Vector3.new(delta.X / maxDist, 0, delta.Y / maxDist)
		end
	end)

	joystickBase.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchInput = nil
			knob.Position = UDim2.new(0.5, -24, 0.5, -24)
			joystickDir = Vector3.zero
		end
	end)

	chargeBtn.MouseButton1Down:Connect(function() charging = true end)
	chargeBtn.MouseButton1Up:Connect(function() charging = false end)
	dodgeBtn.MouseButton1Click:Connect(function() dodgeQueued = true end)
	specialBtn.MouseButton1Click:Connect(function() specialQueued = true end)

	game:GetService("RunService").Heartbeat:Connect(function()
		if not inMatch then return end
		Remotes.BeyInput:FireServer({
			x = joystickDir.X,
			z = joystickDir.Z,
			charging = charging,
			dodge = dodgeQueued,
			special = specialQueued,
		})
		dodgeQueued = false
		specialQueued = false
	end)
end

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	inMatch = payload.phase == "Fighting"
	if UserInputService.TouchEnabled then
		mobile.Enabled = inMatch
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" and UserInputService.TouchEnabled then
		mobile.Enabled = false
		inMatch = false
	end
end)
