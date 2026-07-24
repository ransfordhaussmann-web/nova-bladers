--[[
	Builds layered 3D Bey models (procedural fallback).
	Optional Creator Store models: place under Models/ or set modelAssets.meshId in BeyCatalog.
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
	return part({
		name = name or "RingSeg",
		parent = parent,
		shape = Enum.PartType.Block,
		size = Vector3.new(width, height, outerR * 0.55),
		color = color,
		material = material,
		canCollide = false,
		cframe = CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(midR, 0, 0),
	})
end

local function tryCloneStudioModel(beyData, visualFolder, baseCFrame, hull)
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

	local rot = (beyData.modelRef and beyData.modelRef.importRotation) or CFrame.Angles(math.rad(-90), 0, 0)
	clone:PivotTo(baseCFrame * rot)

	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
		end
	end

	clone.Parent = visualFolder

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
	return meshPart({
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
end

local function buildNovaStriker(parent, color, accent, baseCFrame)
	local visuals, spinVisuals = {}, {}
	local core = part({
		name = "Core", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.0, 2.2, 2.2), color = Color3.fromRGB(180, 200, 230),
		canCollide = false, cframe = baseCFrame,
	})
	table.insert(visuals, core)
	for i = 0, 2 do
		local angle = i * 120
		local blade = part({
			name = "AttackBlade_" .. i, parent = parent,
			size = Vector3.new(0.45, 0.55, 2.4), color = color,
			canCollide = false,
			cframe = baseCFrame * CFrame.Angles(0, math.rad(angle), math.rad(18)) * CFrame.new(0, 0, 1.35),
		})
		blade:SetAttribute("SpinMult", 1)
		table.insert(spinVisuals, blade)
	end
	local spinRing = part({
		name = "SpinRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.18, 3.8, 3.8), color = accent, material = Enum.Material.Neon,
		transparency = 0.35, canCollide = false, cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1)
	table.insert(spinVisuals, spinRing)
	return visuals, spinVisuals, spinRing
end

local function buildIronShell(parent, color, accent, baseCFrame)
	local visuals, spinVisuals = {}, {}
	local core = part({
		name = "Core", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.15, 2.6, 2.6), color = Color3.fromRGB(90, 100, 95),
		material = Enum.Material.DiamondPlate, canCollide = false, cframe = baseCFrame,
	})
	table.insert(visuals, core)
	for i = 0, 5 do
		local seg = ringSegment(parent, 1.15, 1.75, 0.9, color, Enum.Material.Metal, i * 60, "ShellSeg_" .. i)
		seg:SetAttribute("SpinMult", 0.85)
		table.insert(spinVisuals, seg)
	end
	local spinRing = part({
		name = "SpinRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.22, 4.0, 4.0), color = accent, material = Enum.Material.Neon,
		transparency = 0.45, canCollide = false, cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 0.6)
	table.insert(spinVisuals, spinRing)
	return visuals, spinVisuals, spinRing
end

local function buildVoltDash(parent, color, accent, baseCFrame)
	local visuals, spinVisuals = {}, {}
	local flatRing = part({
		name = "StaminaRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.28, 3.9, 3.9), color = color, material = Enum.Material.SmoothPlastic,
		canCollide = false, cframe = baseCFrame,
	})
	flatRing:SetAttribute("SpinMult", 1.1)
	table.insert(spinVisuals, flatRing)
	local spinRing = part({
		name = "SpinRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.12, 4.3, 4.3), color = accent, material = Enum.Material.Neon,
		transparency = 0.3, canCollide = false, cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1.4)
	table.insert(spinVisuals, spinRing)
	return visuals, spinVisuals, spinRing
end

local function buildShadowBite(parent, color, accent, baseCFrame)
	local visuals, spinVisuals = {}, {}
	local aura = part({
		name = "DarkAura", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 3.1, 3.1), color = color, material = Enum.Material.Neon,
		transparency = 0.35, canCollide = false, cframe = baseCFrame,
	})
	aura:SetAttribute("SpinMult", 0.9)
	table.insert(spinVisuals, aura)
	local spinRing = part({
		name = "SpinRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.16, 3.7, 3.7), color = color, material = Enum.Material.Neon,
		transparency = 0.4, canCollide = false, cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1)
	table.insert(spinVisuals, spinRing)
	return visuals, spinVisuals, spinRing
end

local function buildCrimsonBlaze(parent, color, accent, baseCFrame)
	local visuals, spinVisuals = {}, {}
	for i = 0, 3 do
		local angle = i * 90
		local petal = part({
			name = "FlamePetal_" .. i, parent = parent,
			size = Vector3.new(0.5, 0.4, 1.9), color = color, material = Enum.Material.Neon,
			canCollide = false,
			cframe = baseCFrame * CFrame.Angles(0, math.rad(angle), math.rad(12)) * CFrame.new(0, 0, 1.25),
		})
		petal:SetAttribute("SpinMult", 1.15)
		table.insert(spinVisuals, petal)
	end
	local spinRing = part({
		name = "SpinRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.18, 3.9, 3.9), color = accent, material = Enum.Material.Neon,
		transparency = 0.3, canCollide = false, cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 1.3)
	table.insert(spinVisuals, spinRing)
	return visuals, spinVisuals, spinRing
end

local function buildFrostCrown(parent, color, accent, baseCFrame)
	local visuals, spinVisuals = {}, {}
	for i = 0, 5 do
		local seg = ringSegment(parent, 1.0, 1.6, 0.85, accent, Enum.Material.Ice, i * 60, "CrownSpike_" .. i)
		seg:SetAttribute("SpinMult", 0.75)
		table.insert(spinVisuals, seg)
	end
	local spinRing = part({
		name = "SpinRing", parent = parent, shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 4.1, 4.1), color = accent, material = Enum.Material.Neon,
		transparency = 0.4, canCollide = false, cframe = baseCFrame,
	})
	spinRing:SetAttribute("SpinMult", 0.55)
	table.insert(spinVisuals, spinRing)
	return visuals, spinVisuals, spinRing
end

local BUILDERS = {
	NovaStriker = buildNovaStriker,
	IronShell = buildIronShell,
	VoltDash = buildVoltDash,
	ShadowBite = buildShadowBite,
	CrimsonBlaze = buildCrimsonBlaze,
	FrostCrown = buildFrostCrown,
}

function BeyModelBuilder.build(beyData, spawnCFrame)
	local model = Instance.new("Model")
	model.Name = "BeyModel_" .. beyData.id

	local baseCFrame = spawnCFrame * CFrame.Angles(0, 0, math.rad(90))

	local hull = part({
		name = "Hull", parent = model, shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.1, 3.5, 3.5), color = beyData.color,
		transparency = 1, canCollide = true, cframe = baseCFrame,
	})
	model.PrimaryPart = hull

	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "Visuals"
	visualFolder.Parent = model

	local visuals, spinVisuals, spinRing
	local importedVisuals, importedSpin, importedRing = tryCloneStudioModel(beyData, visualFolder, baseCFrame, hull)
	local imported = importedVisuals ~= nil

	if imported then
		visuals, spinVisuals, spinRing = importedVisuals, importedSpin, importedRing
	else
		local external = tryExternalMesh(beyData, visualFolder, baseCFrame)
		if external then
			visuals = { external }
			spinRing = part({
				name = "SpinRing", parent = visualFolder, shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.15, 4.0, 4.0), color = beyData.accentColor or beyData.color,
				material = Enum.Material.Neon, transparency = 0.35, canCollide = false, cframe = baseCFrame,
			})
			spinRing:SetAttribute("SpinMult", 1)
			spinVisuals = { spinRing }
		else
			local builder = BUILDERS[beyData.id] or buildNovaStriker
			visuals, spinVisuals, spinRing = builder(visualFolder, beyData.color, beyData.accentColor or beyData.color, baseCFrame)
		end
	end

	if not imported then
		for _, v in visuals do
			if v ~= hull then
				weld(hull, v, v)
			end
		end
	end

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
