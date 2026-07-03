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

	-- Metal fusion wheel core
	local core = part({
		name = "Core",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.95, 2.5, 2.5),
		color = Color3.fromRGB(180, 195, 220),
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame,
	})
	table.insert(visuals, core)

	-- Storm wheel attack teeth (spin)
	for i = 0, 11 do
		local angle = i * 30
		local toothSize = (i % 2 == 0) and Vector3.new(0.38, 0.42, 0.55) or Vector3.new(0.28, 0.35, 0.38)
		local offset = CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, 1.42)
		local tooth = part({
			name = "WheelTooth_" .. i,
			parent = parent,
			size = toothSize,
			color = Color3.fromRGB(150, 170, 200),
			material = Enum.Material.DiamondPlate,
			canCollide = false,
			cframe = baseCFrame * offset,
		})
		tooth:SetAttribute("SpinMult", 1)
		tooth:SetAttribute("SpinOffset", offset)
		table.insert(spinVisuals, tooth)
	end

	-- Translucent energy ring (Pegasus layer)
	local energy = part({
		name = "EnergyRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.28, 3.15, 3.15),
		color = accent,
		material = Enum.Material.Glass,
		transparency = 0.2,
		canCollide = false,
		cframe = baseCFrame,
	})
	energy:SetAttribute("SpinMult", 1)
	table.insert(spinVisuals, energy)

	-- Three Pegasus attack wings (layered segments)
	for i = 0, 2 do
		local baseAngle = i * 120
		for seg = 0, 3 do
			local angle = baseAngle + (seg - 1.5) * 14
			local reach = 1.05 + seg * 0.28
			local offset = CFrame.Angles(0, math.rad(angle), math.rad(12 + seg * 4)) * CFrame.new(0, 0.05 + seg * 0.03, reach)
			local wing = part({
				name = "PegasusWing_" .. i .. "_" .. seg,
				parent = parent,
				size = Vector3.new(0.32, 0.14 + seg * 0.04, 0.55 + seg * 0.18),
				color = color,
				material = Enum.Material.Metal,
				canCollide = false,
				cframe = baseCFrame * offset,
			})
			wing:SetAttribute("SpinMult", 1)
			wing:SetAttribute("SpinOffset", offset)
			table.insert(spinVisuals, wing)

			if seg == 3 then
				local tip = part({
					name = "WingTip_" .. i,
					parent = parent,
					size = Vector3.new(0.28, 0.12, 0.35),
					color = accent,
					material = Enum.Material.Neon,
					canCollide = false,
					cframe = baseCFrame * offset * CFrame.new(0, 0, 0.42),
				})
				tip:SetAttribute("SpinMult", 1)
				tip:SetAttribute("SpinOffset", offset * CFrame.new(0, 0, 0.42))
				table.insert(spinVisuals, tip)
			end
		end
	end

	-- Face bolt crest (static)
	local faceBolt = part({
		name = "FaceBolt",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 1.1, 1.1),
		color = Color3.fromRGB(240, 245, 255),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		cframe = baseCFrame * CFrame.new(0, 0.08, 0),
	})
	table.insert(visuals, faceBolt)

	for _, wingAngle in ipairs({ 0, 72, 144, 216, 288 }) do
		local crest = part({
			name = "CrestFeather_" .. wingAngle,
			parent = parent,
			size = Vector3.new(0.22, 0.06, 0.45),
			color = Color3.fromRGB(255, 255, 255),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			cframe = baseCFrame * CFrame.Angles(0, math.rad(wingAngle), math.rad(20)) * CFrame.new(0, 0.12, 0.55),
		})
		table.insert(visuals, crest)
	end

	-- 105 track stem
	local track = part({
		name = "Track105",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.85, 0.75, 0.75),
		color = Color3.fromRGB(200, 210, 225),
		material = Enum.Material.Metal,
		canCollide = false,
		cframe = baseCFrame * CFrame.new(0, -0.55, 0),
	})
	table.insert(visuals, track)

	-- Spin ring glow
	local spinRing = part({
		name = "SpinRing",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.14, 3.95, 3.95),
		color = accent,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
		cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1.15)
	spinRing:SetAttribute("SpinOffset", CFrame.new())
	table.insert(spinVisuals, spinRing)

	-- RF flat tip
	local rfTip = part({
		name = "RFTip",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.12, 0.95, 0.95),
		color = Color3.fromRGB(30, 30, 35),
		material = Enum.Material.Rubber,
		canCollide = false,
		cframe = baseCFrame * CFrame.new(0, -1.05, 0),
	})
	table.insert(visuals, rfTip)

	local rfFlat = part({
		name = "RFFlat",
		parent = parent,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.06, 1.05, 1.05),
		color = Color3.fromRGB(20, 20, 24),
		material = Enum.Material.Rubber,
		canCollide = false,
		cframe = baseCFrame * CFrame.new(0, -1.12, 0),
	})
	table.insert(visuals, rfFlat)

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

local BUILDERS = {
	NovaStriker = buildNovaStriker,
	IronShell = buildIronShell,
	VoltDash = buildVoltDash,
	ShadowBite = buildShadowBite,
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
