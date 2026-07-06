--[[
	Anime-inspired special move VFX for Nova Bladers (original IP names).
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SpecialVFX = {}

local function arenaParent()
	return workspace:FindFirstChild("Arena") or workspace
end

function SpecialVFX.ensureFolder(controller)
	if controller.vfxFolder and controller.vfxFolder.Parent then
		return controller.vfxFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpecialVFX_" .. controller.part.Name
	folder.Parent = arenaParent()
	controller.vfxFolder = folder
	return folder
end

function SpecialVFX.cleanup(controller)
	if controller.vfxFolder then
		controller.vfxFolder:Destroy()
		controller.vfxFolder = nil
	end
	if controller.part then
		controller.part.Transparency = controller._savedTransparency or 0
		controller.spinRing.Transparency = controller._savedRingTransparency or 0.4
	end
end

function SpecialVFX.spawnCallout(controller, moveName, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 48)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = controller.part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = moveName
	label.Parent = bb

	Debris:AddItem(bb, 2)
end

function SpecialVFX.chargeAura(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local pos = controller.part.Position

	for i = 1, 8 do
		local spark = Instance.new("Part")
		spark.Size = Vector3.new(0.4, 0.4, 0.4)
		spark.Shape = Enum.PartType.Ball
		spark.Anchored = true
		spark.CanCollide = false
		spark.Material = Enum.Material.Neon
		spark.Color = color
		spark.CFrame = CFrame.new(pos + Vector3.new(math.random(-3, 3), 0.5, math.random(-3, 3)))
		spark.Parent = folder

		local tween = TweenService:Create(spark, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)),
			Transparency = 1,
		})
		tween:Play()
		Debris:AddItem(spark, duration + 0.1)
	end

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.4
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 8, 8),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, duration + 0.1)
end

function SpecialVFX.meteorTrail(fromPos, toPos, color, folder)
	local mid = (fromPos + toPos) / 2
	local trail = Instance.new("Part")
	trail.Size = Vector3.new(1.2, 1.2, 1.2)
	trail.Shape = Enum.PartType.Ball
	trail.Anchored = true
	trail.CanCollide = false
	trail.Material = Enum.Material.Neon
	trail.Color = color
	trail.CFrame = CFrame.new(mid)
	trail.Parent = folder

	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 8
	fire.Color = color
	fire.SecondaryColor = Color3.fromRGB(200, 230, 255)
	fire.Parent = trail

	local spark = Instance.new("Sparkles")
	spark.SparkleColor = color
	spark.Parent = trail

	Debris:AddItem(trail, 0.45)
end

function SpecialVFX.meteorImpact(position, color, folder)
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(2, 2, 2)
	burst.Anchored = true
	burst.CanCollide = false
	burst.Material = Enum.Material.Neon
	burst.Color = color
	burst.Transparency = 0.2
	burst.CFrame = CFrame.new(position)
	burst.Parent = folder

	TweenService:Create(burst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(7, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(burst, 0.4)
end

function SpecialVFX.burrowCloud(controller, color)
	local folder = SpecialVFX.ensureFolder(controller)
	local dust = Instance.new("Part")
	dust.Shape = Enum.PartType.Ball
	dust.Size = Vector3.new(6, 2, 6)
	dust.Anchored = true
	dust.CanCollide = false
	dust.Material = Enum.Material.SmoothPlastic
	dust.Color = Color3.fromRGB(60, 55, 50)
	dust.Transparency = 0.35
	dust.CFrame = CFrame.new(controller.part.Position - Vector3.new(0, 1, 0))
	dust.Parent = folder

	TweenService:Create(dust, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(10, 3, 10),
		Transparency = 1,
	}):Play()
	Debris:AddItem(dust, 0.55)

	local wallHint = Instance.new("Part")
	wallHint.Shape = Enum.PartType.Cylinder
	wallHint.Size = Vector3.new(0.3, 3, 3)
	wallHint.Anchored = true
	wallHint.CanCollide = false
	wallHint.Material = Enum.Material.Neon
	wallHint.Color = color
	wallHint.Transparency = 0.5
	wallHint.CFrame = CFrame.new(controller.part.Position - Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	wallHint.Parent = folder
	Debris:AddItem(wallHint, 0.6)
end

function SpecialVFX.wallRing(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local ring = Instance.new("Part")
	ring.Name = "WallRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1.5, 6, 6)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.CFrame = CFrame.new(controller.part.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	local inner = Instance.new("Part")
	inner.Shape = Enum.PartType.Cylinder
	inner.Size = Vector3.new(1.2, 4.5, 4.5)
	inner.Anchored = true
	inner.CanCollide = false
	inner.Material = Enum.Material.Glass
	inner.Color = Color3.fromRGB(180, 255, 200)
	inner.Transparency = 0.6
	inner.CFrame = ring.CFrame
	inner.Parent = folder

	task.delay(duration, function()
		if ring.Parent then ring:Destroy() end
		if inner.Parent then inner:Destroy() end
	end)

	return ring
end

function SpecialVFX.pulseWave(origin, range, color, folder)
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Cylinder
	wave.Size = Vector3.new(0.3, 2, 2)
	wave.Anchored = true
	wave.CanCollide = false
	wave.Material = Enum.Material.Neon
	wave.Color = color
	wave.Transparency = 0.35
	wave.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = folder

	TweenService:Create(wave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, range * 2, range * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(wave, 0.5)
end

function SpecialVFX.sonicRing(origin, range, color, folder)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 3, 3)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, range * 2.2, range * 2.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.6)
end

function SpecialVFX.darkAura(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local aura = Instance.new("Part")
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.new(5, 5, 5)
	aura.Anchored = true
	aura.CanCollide = false
	aura.Material = Enum.Material.Neon
	aura.Color = color
	aura.Transparency = 0.55
	aura.CFrame = CFrame.new(controller.part.Position)
	aura.Parent = folder

	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40, 20, 60)
	smoke.Opacity = 0.4
	smoke.Size = 2
	smoke.RiseVelocity = 4
	smoke.Parent = aura

	TweenService:Create(aura, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(7, 7, 7),
		Transparency = 0.85,
	}):Play()
	Debris:AddItem(aura, duration + 0.1)
end

function SpecialVFX.diveTrail(controller, targetPos, color, folder)
	local start = controller.part.Position
	local dir = (targetPos - start).Unit
	for i = 1, 5 do
		local t = i / 5
		local p = start + dir * (12 * t) + Vector3.new(0, 3 * (1 - t), 0)
		local mark = Instance.new("Part")
		mark.Size = Vector3.new(0.8, 0.8, 0.8)
		mark.Shape = Enum.PartType.Ball
		mark.Anchored = true
		mark.CanCollide = false
		mark.Material = Enum.Material.Neon
		mark.Color = color
		mark.Transparency = 0.3 + t * 0.4
		mark.CFrame = CFrame.new(p)
		mark.Parent = folder
		Debris:AddItem(mark, 0.35)
	end
end

function SpecialVFX.venomBurst(position, color, folder)
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(3, 3, 3)
	core.Anchored = true
	core.CanCollide = false
	core.Material = Enum.Material.Neon
	core.Color = color
	core.Transparency = 0.15
	core.CFrame = CFrame.new(position)
	core.Parent = folder

	local spikes = Instance.new("Part")
	spikes.Shape = Enum.PartType.Ball
	spikes.Size = Vector3.new(1, 1, 1)
	spikes.Anchored = true
	spikes.CanCollide = false
	spikes.Material = Enum.Material.Neon
	spikes.Color = Color3.fromRGB(80, 255, 120)
	spikes.Transparency = 0.3
	spikes.CFrame = CFrame.new(position)
	spikes.Parent = folder

	TweenService:Create(core, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(10, 10, 10),
		Transparency = 1,
	}):Play()
	TweenService:Create(spikes, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(12, 12, 12),
		Transparency = 1,
	}):Play()
	Debris:AddItem(core, 0.45)
	Debris:AddItem(spikes, 0.45)
end

function SpecialVFX.setUnderground(controller, underground)
	controller._savedTransparency = controller._savedTransparency or controller.part.Transparency
	controller._savedRingTransparency = controller._savedRingTransparency or controller.spinRing.Transparency

	if underground then
		controller.part.Transparency = 0.85
		controller.spinRing.Transparency = 0.95
		controller.part.CanCollide = false
	else
		controller.part.Transparency = controller._savedTransparency
		controller.spinRing.Transparency = controller._savedRingTransparency
		controller.part.CanCollide = true
	end
	controller.underground = underground
end

function SpecialVFX.flameSpiral(position, color, folder)
	local spark = Instance.new("Part")
	spark.Size = Vector3.new(0.9, 0.9, 0.9)
	spark.Shape = Enum.PartType.Ball
	spark.Anchored = true
	spark.CanCollide = false
	spark.Material = Enum.Material.Neon
	spark.Color = color
	spark.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0))
	spark.Parent = folder

	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = color
	fire.SecondaryColor = Color3.fromRGB(255, 220, 100)
	fire.Parent = spark

	TweenService:Create(spark, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(2.5, 2.5, 2.5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(spark, 0.35)
end

function SpecialVFX.flameBurst(position, color, folder)
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(3, 3, 3)
	core.Anchored = true
	core.CanCollide = false
	core.Material = Enum.Material.Neon
	core.Color = color
	core.Transparency = 0.1
	core.CFrame = CFrame.new(position)
	core.Parent = folder

	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 10
	fire.Color = color
	fire.SecondaryColor = Color3.fromRGB(255, 200, 80)
	fire.Parent = core

	TweenService:Create(core, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(12, 12, 12),
		Transparency = 1,
	}):Play()
	Debris:AddItem(core, 0.5)
end

function SpecialVFX.frostAura(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local aura = Instance.new("Part")
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.new(4.5, 4.5, 4.5)
	aura.Anchored = true
	aura.CanCollide = false
	aura.Material = Enum.Material.Glass
	aura.Color = color
	aura.Transparency = 0.5
	aura.CFrame = CFrame.new(controller.part.Position)
	aura.Parent = folder

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(220, 245, 255)
	sparkles.Parent = aura

	TweenService:Create(aura, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(7, 7, 7),
		Transparency = 0.9,
	}):Play()
	Debris:AddItem(aura, duration + 0.1)
end

function SpecialVFX.iceBarrier(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local ring = Instance.new("Part")
	ring.Name = "IceBarrier"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1.8, 6.5, 6.5)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Ice
	ring.Color = color
	ring.Transparency = 0.2
	ring.CFrame = CFrame.new(controller.part.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	local inner = Instance.new("Part")
	inner.Shape = Enum.PartType.Cylinder
	inner.Size = Vector3.new(1.4, 5, 5)
	inner.Anchored = true
	inner.CanCollide = false
	inner.Material = Enum.Material.Glass
	inner.Color = Color3.fromRGB(230, 250, 255)
	inner.Transparency = 0.45
	inner.CFrame = ring.CFrame
	inner.Parent = folder

	task.delay(duration, function()
		if ring.Parent then ring:Destroy() end
		if inner.Parent then inner:Destroy() end
	end)

	return ring
end

function SpecialVFX.iceShatter(origin, range, color, folder)
	local shard = Instance.new("Part")
	shard.Shape = Enum.PartType.Cylinder
	shard.Size = Vector3.new(0.25, 2.5, 2.5)
	shard.Anchored = true
	shard.CanCollide = false
	shard.Material = Enum.Material.Ice
	shard.Color = color
	shard.Transparency = 0.15
	shard.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	shard.Parent = folder

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 255, 255)
	sparkles.Parent = shard

	TweenService:Create(shard, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, range * 2.2, range * 2.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(shard, 0.55)
end

return SpecialVFX
