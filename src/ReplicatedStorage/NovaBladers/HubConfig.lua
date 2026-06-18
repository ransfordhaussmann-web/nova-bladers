local HubConfig = {
	-- Hub liegt neben der Arena, damit beide gleichzeitig existieren können
	HUB_ORIGIN = Vector3.new(0, 0, 200),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	SPAWN_OFFSET = Vector3.new(0, 4, 185),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betreten zum Kämpfen",
			offset = Vector3.new(0, 1, 248),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			remote = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Bey auswählen",
			offset = Vector3.new(-42, 1, 210),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 160, 255),
			remote = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler & Stats",
			offset = Vector3.new(42, 1, 210),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
			remote = "ShowHallOfFame",
		},
	},

	-- Abstand zum Zonen-Pad, ab dem Touch zählt
	ZONE_TOUCH_DEBOUNCE = 1.2,
}

return HubConfig
