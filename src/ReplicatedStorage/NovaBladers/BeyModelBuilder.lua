--[[
	Builds layered 3D Bey models (procedural — no external assets required).
	Optional Creator Store models: set meshId in BeyCatalog.modelAssets.

	Search Roblox Studio Toolbox → Creator Store → "beyblade" / "spinning top"
	Then paste rbxassetid into catalog modelAssets.meshId
]]

local BeyModelBuilder = {}

local function part(props)
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Anchored = props.anchored == true
	p.CanCollide = props.canCollide == true
	p.CastShadow = props.castShadow ~= false
	p.Material = props.material or Enum.Material.Metal
	p.Color = props.color or Color3.fromRGB(200, 200, 200)
	p.Transparency = props.transparency or 0
	if props.shape then
		p.Shape = props.shape
	end
	if props.size then
		p.Size = props.size
	end
	if props.cframe then
		p.CFrame = props.cframe
	end
	p.Parent = props.parent
	return p
end

local function meshPart(props)
	local p = Instance.new("MeshPart")
	p.Name = props.name or "MeshPart"
	p.Anchored = props.anchored == true
	p.CanCollide = props.canCollide == true
	p.Material = props.material or Enum.Material.Metal
	p.Color = props.color or Color3.fromRGB(200, 200, 200)
	p.Transparency = props.transparency or 0
	p.Size = props.size or Vector3.new(2, 2, 2)
	if props.meshId then
		p.MeshId = props.meshId
	end
	if props.textureId then
		p.TextureID = props.textureId
	end
	if props.cframe then
		p.CFrame = props.cframe
	end
	p.Parent = props.parent
	return p
end

local function weld(a, b, parent)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = parent or a
	return w
end

local function ringSegment(parent, innerR, outerR, height, color, material, angleDeg, name)
	local midR = (innerR + outerR) * 0.5
	local width = outerR - innerR
	local seg = part({
		name = name or "RingSeg",
		parent = parent,
		shape = Enum.PartType.Block,
		size = Vector3.new(width, height, outerR * 0.55),
		color = color,
		material = material,
		canCollide = false,
		cframe = CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(midR, 0, 0),
	})
	return seg
end

local function tryCloneStudioModel(beyData, model, visualFolder, baseCFrame, hull)
	local modelsFolder = script.Parent:FindFirstChild("Models")
	if not modelsFolder then
		return nil
	end

	local modelName = (beyData.modelRef and beyData.modelRef.studioModelName) or beyData.id
	local template = modelsFolder:FindFirstChild(modelName)
	if not template or not template:IsA("Model") then
		return nil
	end

	local clone = template:Clone()
	clone.Name = "ImportedMesh"

	-- Fit to arena scale (~3.5 stud diameter)
	local targetSize = (beyData.modelRef and beyData.modelRef.targetSize) or 3.5
	local _, boundSize = clone:GetBoundingBox()
	local maxDim = math.max(boundSize.X, boundSize.Y, boundSize.Z)
	if maxDim > 0.01 then
		local scale = targetSize / maxDim
		if math.abs(scale - 1) > 0.05 then
			pcall(function()
				clone:ScaleTo(scale)
			end)
		end
	end

	-- Lay flat on arena (Sketchfab models often import upright)
	local rot = (beyData.modelRef and beyData.modelRef.importRotation) or CFrame.Angles(math.rad(-90), 0, 0)
	clone:PivotTo(baseCFrame * rot)

	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
		end
	end

	clone.Parent = visualFolder

	-- Weld all mesh parts to physics hull
	local primary = clone.PrimaryPart or clone:FindFirstChild("Hull", true) or clone:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		for _, desc in clone:GetDescendants() do
			if desc:IsA("BasePart") and desc ~= primary then
				weld(primary, desc, desc)
			end
		end
		weld(hull, primary, primary)
	else
		weld(hull, clone:FindFirstChildWhichIsA("BasePart", true), clone)
	end

	local spinRing = part({
		name = "SpinRing",
		parent = visualFolder,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.12, 3.8, 3.8),
		color = beyData.accentColor or beyData.color,
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1)

	return { clone }, { spinRing }, spinRing
end

local function tryExternalMesh(beyData, parent, baseCFrame)
	local assets = beyData.modelAssets
	if not assets or not assets.meshId then
		return nil
	end
	local meshId = assets.meshId
	if not string.find(meshId, "rbxassetid://") then
		meshId = "rbxassetid://" .. tostring(meshId)
	end
	local mp = meshPart({
		name = "ExternalMesh",
		parent = parent,
		meshId = meshId,
		textureId = assets.textureId,
		size = assets.size or Vector3.new(3.6, 1.2, 3.6),
		color = beyData.color,
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame,
	})
	return mp
end

local function buildNovaStriker(parent, color, accent, baseCFrame)
	local visuals = {}
	local spinVisuals = {}

	-- Metal core
	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.0, 2.2, 2.2),
		color = Color3.fromRGB(180, 200, 230),
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	-- Energy layer (spins)
	local energy = part({
		name = "EnergyLayer",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.35, 3.0, 3.0),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.15,
		canCollide = false,
		cframe = baseCFrame,
	})
	energy:SetAttribute("SpinMult", 1)
	table.insert(spinVisuals, energy)

	-- 3 attack blades (spin with ring)
	for i = 0, 2 do
		local angle = i * 120
		local blade = part({
			name = "AttackBlade_" .. i,
			parent = parent,
			size = Vector3.new(0.45, 0.55, 2.4),
			color = color,
			material = Enum.Material.Metal,
			canCollide = false,
			cframe = baseCFrame * CFrame.Angles(0, math.rad(angle), math.rad(18)) * CFrame.new(0, 0, 1.35),
		})
		blade:SetAttribute("SpinMult", 1)
		blade:SetAttribute("SpinOffset", CFrame.Angles(0, math.rad(angle), math.rad(18)) * CFrame.new(0, 0, 1.35))
		local tip = part({
			name = "BladeTip_" .. i,
			parent = parent,
			size = Vector3.new(0.35, 0.35, 0.7),
			color = accent,
			material = Enum.Material.Neon,
			canCollide = false,
			cframe = blade.CFrame * CFrame.new(0, 0, 1.45),
		})
		tip:SetAttribute("SpinMult", 1)
		tip:SetAttribute("SpinOffset", blade:GetAttribute("SpinOffset") * CFrame.new(0, 0, 1.45))
		table.insert(spinVisuals, blade)
		table.insert(spinVisuals, tip)
	end

	-- Spin ring (rotates)
	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.18, 3.8, 3.8),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1)
	spinRing:SetAttribute("SpinOffset", CFrame.new())
	table.insert(spinVisuals, spinRing)

	-- Tip (performance tip)
	local tip = part({
		name = "PerformanceTip",
		parent = parent,
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.7, 0.7, 0.7),
		color = Color3.fromRGB(220, 240, 255),
		material = Enum.Material.Glass,
		canCollide = false,
		cframe = baseCFrame * CFrame.new(0, -0.55, 0),
	})
	table.insert(visuals, tip)

	return visuals, spinVisuals, spinRing
end

local function buildIronShell(parent, color, accent, baseCFrame)
	local visuals = {}
	local spinVisuals = {}

	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.15, 2.6, 2.6),
		color = Color3.fromRGB(90, 100, 95),
		material = Enum.Material.DiamondPlate,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	-- Heavy outer shell segments (spin slowly)
	for i = 0, 5 do
		local seg = ringSegment(parent, 1.15, 1.75, 0.9, color, Enum.Material.Metal, i * 60, "ShellSeg_" .. i)
		seg:SetAttribute("SpinMult", 0.85)
		seg:SetAttribute("SpinOffset", CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(1.45, 0, 0))
		table.insert(spinVisuals, seg)
	end

	local shield = part({
		name = "ShieldRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.5, 3.4, 3.4),
		color = accent,
		material = Enum.Material.Glass,
		transparency = 0.25,
		canCollide = false,
		cframe = baseCFrame,
	})
	shield:SetAttribute("SpinMult", 0.7)
	table.insert(spinVisuals, shield)

	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.22, 4.0, 4.0),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.45,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 0.6)
	table.insert(spinVisuals, spinRing)

	local bumperRing = part({
		name = "BumperRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 4.2, 4.2),
		color = Color3.fromRGB(60, 70, 65),
		material = Enum.Material.CorrodedMetal,
		transparency = 0.1,
		canCollide = false,
		cframe = baseCFrame,
	})
	bumperRing:SetAttribute("SpinMult", -0.35)
	table.insert(spinVisuals, bumperRing)

	return visuals, spinVisuals, spinRing
end

local function buildVoltDash(parent, color, accent, baseCFrame)
	local visuals = {}
	local spinVisuals = {}

	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.75, 1.8, 1.8),
		color = Color3.fromRGB(240, 210, 80),
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	-- Wide flat stamina ring
	local flatRing = part({
		name = "StaminaRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.28, 3.9, 3.9),
		color = color,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		cframe = baseCFrame,
	})
	flatRing:SetAttribute("SpinMult", 1.1)
	table.insert(spinVisuals, flatRing)

	-- Lightning bolt accents (spin)
	for i = 0, 2 do
		local angle = i * 120 + 30
		local offset = CFrame.Angles(0, math.rad(angle), math.rad(35)) * CFrame.new(0, 0.15, 1.05)
		local bolt = part({
			name = "Lightning_" .. i,
			parent = parent,
			size = Vector3.new(0.25, 0.7, 1.1),
			color = accent,
			material = Enum.Material.Neon,
			canCollide = false,
			cframe = baseCFrame * offset,
		})
		bolt:SetAttribute("SpinMult", 1.1)
		bolt:SetAttribute("SpinOffset", offset)
		table.insert(spinVisuals, bolt)
	end

	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.12, 4.3, 4.3),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.3,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1.4)
	table.insert(spinVisuals, spinRing)

	local outerGlow = part({
		name = "OuterGlow",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.08, 4.5, 4.5),
		color = Color3.fromRGB(255, 255, 200),
		material = Enum.Material.Neon,
		transparency = 0.55,
		canCollide = false,
		cframe = baseCFrame,
	})
	outerGlow:SetAttribute("SpinMult", 0.8)
	table.insert(spinVisuals, outerGlow)

	return visuals, spinVisuals, spinRing
end

local function buildShadowBite(parent, color, accent, baseCFrame)
	local visuals = {}
	local spinVisuals = {}

	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.95, 2.3, 2.3),
		color = Color3.fromRGB(45, 25, 70),
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	local aura = part({
		name = "DarkAura",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 3.1, 3.1),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
		cframe = baseCFrame,
	})
	aura:SetAttribute("SpinMult", 0.9)
	table.insert(spinVisuals, aura)

	for i, angle in ipairs({ -35, 50 }) do
		local offset = CFrame.Angles(0, math.rad(angle), math.rad(22)) * CFrame.new(0, 0, 1.2)
		local fang = part({
			name = "Fang_" .. i,
			parent = parent,
			size = Vector3.new(0.5, 0.45, 1.8),
			color = accent,
			material = Enum.Material.Neon,
			canCollide = false,
			cframe = baseCFrame * offset,
		})
		fang:SetAttribute("SpinMult", 0.9)
		fang:SetAttribute("SpinOffset", offset)
		table.insert(spinVisuals, fang)
	end

	local bit = part({
		name = "BitBeast",
		parent = parent,
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.85, 0.85, 0.85),
		color = Color3.fromRGB(180, 60, 220),
		material = Enum.Material.Neon,
		transparency = 0.1,
		canCollide = false,
		cframe = baseCFrame * CFrame.new(0, 0.35, 0),
	})
	table.insert(visuals, bit)

	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.16, 3.7, 3.7),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1)
	table.insert(spinVisuals, spinRing)

	return visuals, spinVisuals, spinRing
end

local function buildCrimsonFang(parent, color, accent, baseCFrame)
	local visuals = {}
	local spinVisuals = {}

	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.85, 2.0, 2.0),
		color = Color3.fromRGB(60, 20, 25),
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	for i = 0, 3 do
		local angle = i * 90 + 15
		local offset = CFrame.Angles(0, math.rad(angle), math.rad(28)) * CFrame.new(0, 0, 1.3)
		local fang = part({
			name = "FangBlade_" .. i,
			parent = parent,
			size = Vector3.new(0.55, 0.4, 2.0),
			color = color,
			material = Enum.Material.Metal,
			canCollide = false,
			cframe = baseCFrame * offset,
		})
		fang:SetAttribute("SpinMult", 1.15)
		fang:SetAttribute("SpinOffset", offset)
		table.insert(spinVisuals, fang)

		local tip = part({
			name = "FangTip_" .. i,
			parent = parent,
			size = Vector3.new(0.35, 0.3, 0.65),
			color = accent,
			material = Enum.Material.Neon,
			canCollide = false,
			cframe = fang.CFrame * CFrame.new(0, 0, 1.25),
		})
		tip:SetAttribute("SpinMult", 1.15)
		tip:SetAttribute("SpinOffset", offset * CFrame.new(0, 0, 1.25))
		table.insert(spinVisuals, tip)
	end

	local rageRing = part({
		name = "RageRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 3.6, 3.6),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.3,
		canCollide = false,
		cframe = baseCFrame,
	})
	rageRing:SetAttribute("SpinMult", 1.2)
	table.insert(spinVisuals, rageRing)

	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.14, 4.1, 4.1),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1.1)
	table.insert(spinVisuals, spinRing)

	return visuals, spinVisuals, spinRing
end

local function buildFrostCrown(parent, color, accent, baseCFrame)
	local visuals = {}
	local spinVisuals = {}

	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.0, 2.4, 2.4),
		color = Color3.fromRGB(200, 230, 250),
		material = Enum.Material.Ice,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	for i = 0, 5 do
		local angle = i * 60
		local offset = CFrame.Angles(0, math.rad(angle), math.rad(12)) * CFrame.new(0, 0.35, 1.15)
		local spike = part({
			name = "CrownSpike_" .. i,
			parent = parent,
			size = Vector3.new(0.35, 0.8, 0.9),
			color = accent,
			material = Enum.Material.Glass,
			transparency = 0.15,
			canCollide = false,
			cframe = baseCFrame * offset,
		})
		spike:SetAttribute("SpinMult", 0.75)
		spike:SetAttribute("SpinOffset", offset)
		table.insert(spinVisuals, spike)
	end

	local frostRing = part({
		name = "FrostRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.25, 3.5, 3.5),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
		cframe = baseCFrame,
	})
	frostRing:SetAttribute("SpinMult", 0.85)
	table.insert(spinVisuals, frostRing)

	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.18, 4.0, 4.0),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.45,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 0.65)
	table.insert(spinVisuals, spinRing)

	local outerIce = part({
		name = "OuterIce",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.1, 4.3, 4.3),
		color = Color3.fromRGB(220, 245, 255),
		material = Enum.Material.Glass,
		transparency = 0.5,
		canCollide = false,
		cframe = baseCFrame,
	})
	outerIce:SetAttribute("SpinMult", -0.3)
	table.insert(spinVisuals, outerIce)

	return visuals, spinVisuals, spinRing
end

local BUILDERS = {
	NovaStriker = buildNovaStriker,
	IronShell = buildIronShell,
	VoltDash = buildVoltDash,
	ShadowBite = buildShadowBite,
	CrimsonFang = buildCrimsonFang,
	FrostCrown = buildFrostCrown,
}

function BeyModelBuilder.build(beyData, spawnCFrame)
	local model = Instance.new("Model")
	model.Name = "BeyModel_" .. beyData.id

	local baseCFrame = spawnCFrame * CFrame.Angles(0, 0, math.rad(90))

	-- Physics hull (flat cylinder collider)
	local hull = part({
		name = "Hull",
		parent = model,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.1, 3.5, 3.5),
		color = beyData.color,
		material = Enum.Material.Metal,
		transparency = 1,
		canCollide = true,
		cframe = baseCFrame,
	})
	model.PrimaryPart = hull

	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "Visuals"
	visualFolder.Parent = model

	local visuals, spinVisuals, spinRing
	local importedVisuals, importedSpin, importedRing = tryCloneStudioModel(beyData, model, visualFolder, baseCFrame, hull)
	local imported = importedVisuals ~= nil

	if imported then
		visuals, spinVisuals, spinRing = importedVisuals, importedSpin, importedRing
	else
		local external = tryExternalMesh(beyData, visualFolder, baseCFrame)

		if external then
			visuals = { external }
			spinRing = part({
				name = "SpinRing",
				parent = visualFolder,
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.15, 4.0, 4.0),
				color = beyData.accentColor or beyData.color,
				material = Enum.Material.Neon,
				transparency = 0.35,
				canCollide = false,
				cframe = baseCFrame,
			})
			spinRing:SetAttribute("SpinMult", 1)
			spinVisuals = { spinRing }
		else
			local builder = BUILDERS[beyData.id] or buildNovaStriker
			local accent = beyData.accentColor or beyData.color
			visuals, spinVisuals, spinRing = builder(visualFolder, beyData.color, accent, baseCFrame)
		end
	end

	-- Weld static visuals to hull (skip imported mesh — already welded)
	if not imported then
		for _, v in visuals do
			if v ~= hull then
				weld(hull, v, v)
			end
		end
	end

	-- Spin layers: NOT welded — BeyController rotates them each frame
	for _, s in spinVisuals do
		s.Anchored = false
		s.CanCollide = false
	end

	return {
		model = model,
		part = hull,
		spinRing = spinRing,
		spinVisuals = spinVisuals,
		visuals = visuals,
		baseCFrame = baseCFrame,
	}
end

return BeyModelBuilder
