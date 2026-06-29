local HubWorldConfig = {
	ROOT_NAME = "HubWorld",
	SPAWN_POSITION = Vector3.new(0, 4, 18),

	THEME = {
		FLOOR = Color3.fromRGB(22, 26, 38),
		FLOOR_ACCENT = Color3.fromRGB(35, 42, 62),
		WALL = Color3.fromRGB(40, 45, 65),
		NEON = Color3.fromRGB(100, 180, 255),
		NEON_WARM = Color3.fromRGB(255, 190, 80),
		GLOW = Color3.fromRGB(70, 130, 220),
	},

	PLAZA = {
		RADIUS = 26,
		HEIGHT = 1.2,
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Spin-Arena",
			hint = "Arena betreten",
			position = Vector3.new(0, 2, -38),
			size = Vector3.new(16, 12, 10),
			remote = "EnterArena",
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey-Auswahl",
			hint = "Bey wählen",
			position = Vector3.new(-30, 2, 0),
			size = Vector3.new(12, 10, 12),
			remote = "OpenBeySelect",
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Rangliste",
			hint = "Stats ansehen",
			position = Vector3.new(30, 2, 0),
			size = Vector3.new(10, 10, 6),
			remote = "ShowLobbyStats",
		},
	},
}

return HubWorldConfig
