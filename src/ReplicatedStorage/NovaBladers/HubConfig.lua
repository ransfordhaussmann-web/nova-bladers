local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 4, 25),

	FLOOR = {
		size = Vector3.new(120, 1, 120),
		position = Vector3.new(0, 0, 0),
		color = Color3.fromRGB(28, 32, 48),
		material = Enum.Material.Slate,
	},

	PLAZA_RING = {
		innerRadius = 18,
		outerRadius = 22,
		height = 0.2,
		color = Color3.fromRGB(60, 120, 255),
		material = Enum.Material.Neon,
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			position = Vector3.new(0, 0.5, -38),
			size = Vector3.new(16, 1, 12),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Arena betreten",
			promptAction = "EnterArena",
			maxDistance = 14,
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			position = Vector3.new(-34, 0.5, 8),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(140, 80, 220),
			promptText = "Bey wählen",
			promptAction = "OpenBeySelect",
			maxDistance = 12,
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			position = Vector3.new(34, 0.5, 8),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 200, 60),
			promptText = "Rangliste ansehen",
			promptAction = "ShowLeaderboard",
			maxDistance = 12,
		},
	},

	ARENA_GATE_ARCH = {
		position = Vector3.new(0, 8, -44),
		width = 18,
		height = 14,
		depth = 2,
		color = Color3.fromRGB(50, 90, 180),
		glowColor = Color3.fromRGB(100, 180, 255),
	},

	PILLARS = {
		count = 8,
		radius = 48,
		height = 10,
		color = Color3.fromRGB(40, 44, 60),
	},

	BILLBOARD_HEIGHT = 8,
}

return HubConfig
