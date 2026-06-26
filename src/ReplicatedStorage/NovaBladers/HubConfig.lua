local HubConfig = {
	ORIGIN = Vector3.new(0, 50, 0),
	SPAWN_OFFSET = Vector3.new(0, 4, 12),

	PLATFORM = {
		size = Vector3.new(72, 2, 72),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	},

	RIM = {
		height = 1.2,
		thickness = 2,
		color = Color3.fromRGB(60, 120, 255),
		material = Enum.Material.Neon,
	},

	ZONES = {
		arenaPortal = {
			position = Vector3.new(0, 2, -28),
			promptText = "Arena betreten",
			promptKey = Enum.KeyCode.E,
			maxDistance = 10,
		},
		beySelect = {
			position = Vector3.new(-22, 2, 0),
			promptText = "Bey wählen",
			promptKey = Enum.KeyCode.E,
			maxDistance = 8,
		},
		statsBoard = {
			position = Vector3.new(22, 2, 0),
			promptText = "Stats anzeigen",
			promptKey = Enum.KeyCode.E,
			maxDistance = 8,
		},
		leaderboard = {
			position = Vector3.new(0, 2, 22),
			promptText = "Leaderboard",
			promptKey = Enum.KeyCode.E,
			maxDistance = 8,
		},
	},

	ARENA_PORTAL = {
		ringRadius = 6,
		ringHeight = 0.4,
		color = Color3.fromRGB(80, 160, 255),
		glowColor = Color3.fromRGB(120, 200, 255),
	},

	LABELS = {
		hubTitle = "Nova Bladers Hub",
		arenaSubtitle = "Betrete die Spin-Arena",
	},

	TELEPORT = {
		arenaOffset = Vector3.new(0, 5, 0),
		hubRespawnDelay = 0.5,
	},
}

return HubConfig
