local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inMatch = false
local inputState = {
	x = 0,
	z = 0,
	charging = false,
	dodge = false,
	special = false,
}

local keys = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
}

local heldKeys = {}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inMatch then return end

	if keys[input.KeyCode] then
		heldKeys[input.KeyCode] = true
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		inputState.charging = true
	end
	if input.KeyCode == Enum.KeyCode.Space then
		inputState.dodge = true
	end
	if input.KeyCode == Enum.KeyCode.E then
		inputState.special = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if keys[input.KeyCode] then
		heldKeys[input.KeyCode] = nil
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		inputState.charging = false
	end
end)

local function getMoveDir()
	local dir = Vector3.zero
	for keyCode, vec in keys do
		if heldKeys[keyCode] then
			dir += vec
		end
	end
	if dir.Magnitude > 0 then
		dir = dir.Unit
	end
	return dir
end

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	inMatch = payload.phase == "Fighting"
	if not inMatch then
		inputState.dodge = false
		inputState.special = false
	end
end)

RunService.Heartbeat:Connect(function()
	if not inMatch then return end

	local dir = getMoveDir()
	inputState.x = dir.X
	inputState.z = dir.Z

	Remotes.BeyInput:FireServer({
		x = inputState.x,
		z = inputState.z,
		charging = inputState.charging,
		dodge = inputState.dodge,
		special = inputState.special,
	})

	inputState.dodge = false
	inputState.special = false
end)

Remotes.PlaySound.OnClientEvent:Connect(function(assetId)
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = 0.6
	sound.Parent = workspace
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end)
