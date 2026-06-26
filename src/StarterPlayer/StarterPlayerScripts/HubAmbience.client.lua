local TweenService = game:GetService("TweenService")

local hub = workspace:WaitForChild("NovaBladersHub", 30)
if not hub then
	return
end

local portal = hub:WaitForChild("ArenaPortal", 10)
if not portal then
	return
end

local pad = portal:WaitForChild("Pad", 5)
local ring = portal:FindFirstChild("Ring")
if not pad then
	return
end

local light = pad:FindFirstChildOfClass("PointLight")
if light then
	task.spawn(function()
		while pad.Parent do
			local tween = TweenService:Create(
				light,
				TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Brightness = 3.2 }
			)
			tween:Play()
			tween.Completed:Wait()
			local down = TweenService:Create(
				light,
				TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Brightness = 1.4 }
			)
			down:Play()
			down.Completed:Wait()
		end
	end)
end

if ring then
	task.spawn(function()
		while ring.Parent do
			ring.CFrame = ring.CFrame * CFrame.Angles(0, math.rad(1.5), 0)
			task.wait(0.03)
		end
	end)
end

local particles = Instance.new("ParticleEmitter")
particles.Name = "PortalSparkle"
particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
particles.Rate = 18
particles.Lifetime = NumberRange.new(0.6, 1.1)
particles.Speed = NumberRange.new(2, 5)
particles.SpreadAngle = Vector2.new(180, 180)
particles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
particles.LightEmission = 0.8
particles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(1, 0),
})
particles.Parent = pad
