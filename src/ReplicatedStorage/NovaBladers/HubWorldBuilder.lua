local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(HubConfig.ORIGIN)
	part.Color = props.Color or HubConfig.FLOOR_COLOR
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.CanCollide = props.CanCollide ~= false
	part.Anchored = true
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent
	return part
end

local function addNeonStrip(parent, cframe, size, color)
	local strip = makePart({
		Name = "NeonStrip",
		Size = size,
		CFrame = cframe,
		Color = color or HubConfig.ACCENT_COLOR,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	strip.CanCollide = false
	return strip
end

local function addSign(parent, cframe, title, subtitle)
	local board = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 6, 0.4),
		CFrame = cframe,
		Color = HubConfig.SIGN_COLOR,
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = HubConfig.SIGN_COLOR
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0.35, 0)
	titleLabel.Position = UDim2.new(0, 8, 0.08, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = HubConfig.ACCENT_COLOR
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, -16, 0.45, 0)
	subLabel.Position = UDim2.new(0, 8, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.TextScaled = true
	subLabel.TextWrapped = true
	subLabel.Text = subtitle or ""
	subLabel.Parent = frame

	return board
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.build()
	local origin = HubConfig.ORIGIN
	local folder = Instance.new("Folder")
	folder.Name = "NovaHub"
	folder.Parent = workspace

	-- Main plaza floor
	local floor = makePart({
		Name = "PlazaFloor",
		Size = Vector3.new(HubConfig.PLAZA_RADIUS * 2, 1, HubConfig.PLAZA_RADIUS * 2),
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
		Parent = folder,
	})

	-- Inner accent ring
	makePart({
		Name = "CenterPlatform",
		Size = Vector3.new(16, 0.3, 16),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.15, 0)),
		Color = HubConfig.FLOOR_ACCENT,
		Material = Enum.Material.Marble,
		Parent = folder,
	})

	addNeonStrip(
		folder,
		CFrame.new(origin + Vector3.new(0, 0.35, 0)),
		Vector3.new(14, 0.15, 0.4),
		HubConfig.ACCENT_COLOR
	)
	addNeonStrip(
		folder,
		CFrame.new(origin + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(14, 0.15, 0.4),
		HubConfig.ACCENT_COLOR
	)

	-- Spawn marker
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubWorldBuilder.getSpawnCFrame()
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- Arena portal arch
	local portalPos = origin + HubConfig.ARENA_PORTAL_OFFSET
	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "ArenaPortal"
	portalFolder.Parent = folder

	local portalBase = makePart({
		Name = "PortalBase",
		Size = Vector3.new(14, 0.5, 4),
		CFrame = CFrame.new(portalPos + Vector3.new(0, 0.25, 0)),
		Color = HubConfig.FLOOR_ACCENT,
		Parent = portalFolder,
	})

	local leftPillar = makePart({
		Name = "LeftPillar",
		Size = Vector3.new(1.5, 10, 1.5),
		CFrame = CFrame.new(portalPos + Vector3.new(-5, 5.5, 0)),
		Color = HubConfig.SIGN_COLOR,
		Material = Enum.Material.Metal,
		Parent = portalFolder,
	})

	local rightPillar = makePart({
		Name = "RightPillar",
		Size = Vector3.new(1.5, 10, 1.5),
		CFrame = CFrame.new(portalPos + Vector3.new(5, 5.5, 0)),
		Color = HubConfig.SIGN_COLOR,
		Material = Enum.Material.Metal,
		Parent = portalFolder,
	})

	local arch = makePart({
		Name = "PortalArch",
		Size = Vector3.new(12, 1.2, 1.2),
		CFrame = CFrame.new(portalPos + Vector3.new(0, 11, 0)),
		Color = HubConfig.PORTAL_COLOR,
		Material = Enum.Material.Neon,
		Parent = portalFolder,
	})

	local portalGate = makePart({
		Name = "PortalGate",
		Size = Vector3.new(8, 8, 0.6),
		CFrame = CFrame.new(portalPos + Vector3.new(0, 5, 0)),
		Color = HubConfig.PORTAL_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		Parent = portalFolder,
	})
	portalGate:SetAttribute("IsPortal", true)

	addProximityPrompt(portalGate, HubConfig.PORTAL_ACTION, "Arena Portal")

	addSign(
		portalFolder,
		CFrame.new(portalPos + Vector3.new(0, 8, 3.5)),
		"ARENA PORTAL",
		"Betrete die Spin-Arena"
	)

	-- Leaderboard board
	local lbPos = origin + HubConfig.LEADERBOARD_OFFSET
	local lbBoard = addSign(
		folder,
		CFrame.new(lbPos + Vector3.new(0, 4, -3)) * CFrame.Angles(0, math.rad(25), 0),
		"🏆 TOP SPIELER",
		"Lade Rangliste..."
	)
	lbBoard.Name = "LeaderboardBoard"

	local lbPedestal = makePart({
		Name = "LeaderboardPedestal",
		Size = Vector3.new(8, 1, 4),
		CFrame = CFrame.new(lbPos + Vector3.new(0, 0.5, 0)),
		Color = HubConfig.FLOOR_ACCENT,
		Parent = folder,
	})

	-- Bey select kiosk
	local beyPos = origin + HubConfig.BEY_SELECT_OFFSET
	local beyKiosk = makePart({
		Name = "BeySelectKiosk",
		Size = Vector3.new(6, 5, 3),
		CFrame = CFrame.new(beyPos + Vector3.new(0, 2.5, 0)),
		Color = HubConfig.SIGN_COLOR,
		Material = Enum.Material.Metal,
		Parent = folder,
	})

	addSign(
		folder,
		CFrame.new(beyPos + Vector3.new(0, 5.5, 2)) * CFrame.Angles(0, math.rad(-25), 0),
		"BEY GARAGE",
		"Wähle deinen Kämpfer"
	)

	addProximityPrompt(beyKiosk, HubConfig.BEY_SELECT_ACTION, "Bey Garage")

	-- Mode info sign (training / pvp / ffa)
	local modePos = origin + HubConfig.TRAINING_SIGN_OFFSET
	local modeBoard = addSign(
		folder,
		CFrame.new(modePos + Vector3.new(0, 4, 3)) * CFrame.Angles(0, math.rad(180), 0),
		"SPIELMODI",
		"1 Spieler: Training\n2 Spieler: 1v1 PvP\n3+: Free-for-All"
	)
	modeBoard.Name = "ModeBoard"

	-- Decorative corner pillars with lights
	local pillarOffsets = {
		Vector3.new(-30, 0, -30),
		Vector3.new(30, 0, -30),
		Vector3.new(-30, 0, 30),
		Vector3.new(30, 0, 30),
	}
	for i, offset in pillarOffsets do
		local pillar = makePart({
			Name = "CornerPillar" .. i,
			Size = Vector3.new(2, HubConfig.WALL_HEIGHT, 2),
			CFrame = CFrame.new(origin + offset + Vector3.new(0, HubConfig.WALL_HEIGHT / 2, 0)),
			Color = HubConfig.SIGN_COLOR,
			Material = Enum.Material.Metal,
			Parent = folder,
		})

		local light = Instance.new("PointLight")
		light.Color = HubConfig.ACCENT_COLOR
		light.Brightness = 1.2
		light.Range = 18
		light.Parent = pillar

		addNeonStrip(
			folder,
			CFrame.new(origin + offset + Vector3.new(0, HubConfig.WALL_HEIGHT - 0.5, 0)),
			Vector3.new(2.2, 0.2, 2.2),
			HubConfig.ACCENT_COLOR
		)
	end

	-- Low boundary walls (walkable but visible edge)
	for _, side in { -1, 1 } do
		makePart({
			Name = "BoundaryWallX",
			Size = Vector3.new(HubConfig.PLAZA_RADIUS * 2, 3, 1),
			CFrame = CFrame.new(origin + Vector3.new(0, 1.5, side * HubConfig.PLAZA_RADIUS)),
			Color = HubConfig.FLOOR_ACCENT,
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
		makePart({
			Name = "BoundaryWallZ",
			Size = Vector3.new(1, 3, HubConfig.PLAZA_RADIUS * 2),
			CFrame = CFrame.new(origin + Vector3.new(side * HubConfig.PLAZA_RADIUS, 1.5, 0)),
			Color = HubConfig.FLOOR_ACCENT,
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
	end

	-- Ambient hub lighting
	local hubLight = Instance.new("Part")
	hubLight.Name = "HubLightAnchor"
	hubLight.Anchored = true
	hubLight.CanCollide = false
	hubLight.Transparency = 1
	hubLight.Size = Vector3.new(1, 1, 1)
	hubLight.CFrame = CFrame.new(origin + Vector3.new(0, 20, 0))
	hubLight.Parent = folder

	local overhead = Instance.new("PointLight")
	overhead.Color = Color3.fromRGB(180, 200, 255)
	overhead.Brightness = 0.8
	overhead.Range = 80
	overhead.Parent = hubLight

	folder:SetAttribute("Built", true)
	return folder
end

function HubWorldBuilder.updateLeaderboard(folder, entries)
	local board = folder:FindFirstChild("LeaderboardBoard", true)
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return end
	local subtitle = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Subtitle")
	if not subtitle then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		subtitle.Text = "Noch keine Einträge"
	else
		subtitle.Text = table.concat(lines, "\n")
	end
end

function HubWorldBuilder.updateModeBoard(folder, modeLabel)
	local board = folder:FindFirstChild("ModeBoard", true)
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return end
	local subtitle = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Subtitle")
	if not subtitle then return end
	subtitle.Text = modeLabel or subtitle.Text
end

return HubWorldBuilder
