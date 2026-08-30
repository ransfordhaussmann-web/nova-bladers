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

function SpecialVFX.fangSlash(position, facing, color, folder)
	local slash = Instance.new("Part")
	slash.Size = Vector3.new(2.5, 0.3, 1.2)
	slash.Anchored = true
	slash.CanCollide = false
	slash.Material = Enum.Material.Neon
	slash.Color = color
	slash.Transparency = 0.2
	slash.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0), position + facing) * CFrame.Angles(0, 0, math.rad(45))
	slash.Parent = folder
	TweenService:Create(slash, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(3.5, 0.2, 0.8),
	}):Play()
	Debris:AddItem(slash, 0.2)
end

function SpecialVFX.stonePillars(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local pos = controller.part.Position
	for i = 0, 3 do
		local angle = i * 90 + 45
		local offset = Vector3.new(math.cos(math.rad(angle)) * 3, 0, math.sin(math.rad(angle)) * 3)
		local pillar = Instance.new("Part")
		pillar.Size = Vector3.new(1.2, 0.5, 1.2)
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.Material = Enum.Material.Slate
		pillar.Color = color
		pillar.CFrame = CFrame.new(pos + offset - Vector3.new(0, 1.5, 0))
		pillar.Parent = folder
		TweenService:Create(pillar, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.2, 3.5, 1.2),
			CFrame = CFrame.new(pos + offset),
		}):Play()
		task.delay(duration, function()
			if pillar.Parent then pillar:Destroy() end
		end)
	end
	SpecialVFX.wallRing(controller, color, duration)
end

function SpecialVFX.quakeWave(origin, range, color, folder)
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Cylinder
	wave.Size = Vector3.new(0.4, 2, 2)
	wave.Anchored = true
	wave.CanCollide = false
	wave.Material = Enum.Material.Slate
	wave.Color = color
	wave.Transparency = 0.3
	wave.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = folder
	TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, range * 2.2, range * 2.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(wave, 0.55)
end

function SpecialVFX.solarRing(origin, range, color, folder)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 2.5, 2.5)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.15
	ring.CFrame = CFrame.new(origin + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 6
	fire.Color = color
	fire.SecondaryColor = Color3.fromRGB(255, 255, 200)
	fire.Parent = ring
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, range * 2.4, range * 2.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.55)
end

function SpecialVFX.solarFlare(position, color, folder)
	local flare = Instance.new("Part")
	flare.Shape = Enum.PartType.Ball
	flare.Size = Vector3.new(1.5, 1.5, 1.5)
	flare.Anchored = true
	flare.CanCollide = false
	flare.Material = Enum.Material.Neon
	flare.Color = color
	flare.Transparency = 0.25
	flare.CFrame = CFrame.new(position)
	flare.Parent = folder
	TweenService:Create(flare, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(flare, 0.3)
end

function SpecialVFX.mirageFade(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	controller._savedTransparency = controller._savedTransparency or controller.part.Transparency
	TweenService:Create(controller.part, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad), {
		Transparency = 0.7,
	}):Play()
	local ghost = Instance.new("Part")
	ghost.Shape = Enum.PartType.Cylinder
	ghost.Size = Vector3.new(0.5, 3.5, 3.5)
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.Material = Enum.Material.ForceField
	ghost.Color = color
	ghost.Transparency = 0.4
	ghost.CFrame = controller.part.CFrame
	ghost.Parent = folder
	Debris:AddItem(ghost, duration)
end

function SpecialVFX.mirageAfterimage(controller, targetPos, color, folder)
	local start = controller.part.Position
	local dir = (targetPos - start)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		dir = controller.facing
	else
		dir = dir.Unit
	end
	for i = 1, 4 do
		local t = i / 4
		local p = start + dir * (10 * t)
		local ghost = Instance.new("Part")
		ghost.Shape = Enum.PartType.Cylinder
		ghost.Size = Vector3.new(0.3, 3, 3)
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.Material = Enum.Material.ForceField
		ghost.Color = color
		ghost.Transparency = 0.3 + t * 0.5
		ghost.CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.rad(90))
		ghost.Parent = folder
		Debris:AddItem(ghost, 0.3)
	end
end

function SpecialVFX.spectralCut(position, facing, color, folder)
	local cut = Instance.new("Part")
	cut.Size = Vector3.new(0.2, 4, 0.2)
	cut.Anchored = true
	cut.CanCollide = false
	cut.Material = Enum.Material.Neon
	cut.Color = color
	cut.Transparency = 0.1
	cut.CFrame = CFrame.new(position + Vector3.new(0, 1, 0), position + facing + Vector3.new(0, 1, 0))
	cut.Parent = folder
	local cross = cut:Clone()
	cross.CFrame = cut.CFrame * CFrame.Angles(0, math.rad(90), 0)
	cross.Parent = folder
	TweenService:Create(cut, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 8, 0.1),
		Transparency = 1,
	}):Play()
	TweenService:Create(cross, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 8, 0.1),
		Transparency = 1,
	}):Play()
	Debris:AddItem(cut, 0.35)
	Debris:AddItem(cross, 0.35)
end

function SpecialVFX.frostAura(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local aura = Instance.new("Part")
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.new(4, 4, 4)
	aura.Anchored = true
	aura.CanCollide = false
	aura.Material = Enum.Material.Glass
	aura.Color = color
	aura.Transparency = 0.5
	aura.CFrame = CFrame.new(controller.part.Position)
	aura.Parent = folder
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = color
	sparkles.Parent = aura
	TweenService:Create(aura, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(6, 6, 6),
		Transparency = 0.8,
	}):Play()
	Debris:AddItem(aura, duration + 0.1)
end

function SpecialVFX.frostRing(origin, range, color, folder)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, 2, 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Ice
	ring.Color = color
	ring.Transparency = 0.2
	ring.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, range * 2, range * 2),
		Transparency = 0.7,
	}):Play()
	Debris:AddItem(ring, 0.45)
end

function SpecialVFX.frostShatter(position, color, folder)
	for i = 1, 8 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.6, 0.8, 0.3)
		shard.Anchored = true
		shard.CanCollide = false
		shard.Material = Enum.Material.Glass
		shard.Color = color
		shard.Transparency = 0.1
		local angle = (i / 8) * math.pi * 2
		shard.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 2, 0.5, math.sin(angle) * 2))
			* CFrame.Angles(math.random() * 0.5, angle, math.random() * 0.5)
		shard.Parent = folder
		TweenService:Create(shard, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = shard.CFrame + Vector3.new(math.cos(angle) * 4, 3, math.sin(angle) * 4),
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, 0.5)
	end
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(2, 2, 2)
	burst.Anchored = true
	burst.CanCollide = false
	burst.Material = Enum.Material.Neon
	burst.Color = color
	burst.Transparency = 0.3
	burst.CFrame = CFrame.new(position)
	burst.Parent = folder
	TweenService:Create(burst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(9, 9, 9),
		Transparency = 1,
	}):Play()
	Debris:AddItem(burst, 0.4)
end

function SpecialVFX.surgeBoost(controller, color, duration)
	SpecialVFX.chargeAura(controller, color, duration)
	local folder = SpecialVFX.ensureFolder(controller)
	local streak = Instance.new("Part")
	streak.Shape = Enum.PartType.Cylinder
	streak.Size = Vector3.new(0.1, 4, 4)
	streak.Anchored = true
	streak.CanCollide = false
	streak.Material = Enum.Material.Neon
	streak.Color = color
	streak.Transparency = 0.35
	streak.CFrame = controller.part.CFrame
	streak.Parent = folder
	Debris:AddItem(streak, duration + 0.1)
end

function SpecialVFX.surgeTrail(position, color, folder)
	local trail = Instance.new("Part")
	trail.Shape = Enum.PartType.Ball
	trail.Size = Vector3.new(1, 1, 1)
	trail.Anchored = true
	trail.CanCollide = false
	trail.Material = Enum.Material.Neon
	trail.Color = color
	trail.Transparency = 0.4
	trail.CFrame = CFrame.new(position)
	trail.Parent = folder
	Debris:AddItem(trail, 0.2)
end

function SpecialVFX.surgeImpact(position, color, folder)
	local impact = Instance.new("Part")
	impact.Shape = Enum.PartType.Ball
	impact.Size = Vector3.new(2.5, 2.5, 2.5)
	impact.Anchored = true
	impact.CanCollide = false
	impact.Material = Enum.Material.Neon
	impact.Color = color
	impact.Transparency = 0.15
	impact.CFrame = CFrame.new(position)
	impact.Parent = folder
	TweenService:Create(impact, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(8, 8, 8),
		Transparency = 1,
	}):Play()
	Debris:AddItem(impact, 0.4)
end

return SpecialVFX
