local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 4, 10),
	HUB_FLOOR_SIZE = Vector3.new(100, 1, 80),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	FLOOR_COLOR = Color3.fromRGB(35, 38, 48),
	WALL_COLOR = Color3.fromRGB(50, 55, 70),
	ACCENT_COLOR = Color3.fromRGB(100, 180, 255),

	ZONE_CHECK_INTERVAL = 0.25,
	INTERACT_KEY = Enum.KeyCode.E,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 0, -32),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-32, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(70, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Drücke E — Stats & Rangliste",
			position = Vector3.new(32, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "openStats",
		},
	},
}

return HubConfig
