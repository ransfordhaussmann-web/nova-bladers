local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	SPAWN_OFFSET = Vector3.new(0, 4, -28),
	FLOOR_SIZE = Vector3.new(128, 1, 128),
	FLOOR_COLOR = Color3.fromRGB(42, 46, 58),
	ACCENT_COLOR = Color3.fromRGB(90, 160, 255),

	ZONES = {
		SpawnPlaza = {
			center = Vector3.new(0, 0, -18),
			size = Vector3.new(36, 1, 28),
			label = "Nova Plaza",
		},
		ArenaGate = {
			center = Vector3.new(0, 0, 42),
			size = Vector3.new(22, 14, 6),
			label = "Arena-Tor",
			promptAction = "Arena betreten",
		},
		BeyBay = {
			center = Vector3.new(-34, 0, 4),
			size = Vector3.new(28, 1, 36),
			label = "Bey-Bucht",
			promptAction = "Bey wählen",
		},
		Leaderboard = {
			center = Vector3.new(34, 0, 4),
			size = Vector3.new(20, 18, 8),
			label = "Rangliste",
		},
	},

	PEDESTAL_RADIUS = 5,
	PEDESTAL_HEIGHT = 3,
}

return HubConfig
