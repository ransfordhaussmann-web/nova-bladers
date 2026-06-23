local HubConfig = {
	ROOT_NAME = "NovaBladersHub",
	CENTER = Vector3.new(0, 0, 120),

	PLATFORM_RADIUS = 42,
	PLATFORM_HEIGHT = 1.2,

	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaPortal = {
			id = "ArenaPortal",
			label = "Arena-Tor",
			hint = "Drücke E — Match starten",
			offset = Vector3.new(0, 0, -28),
			color = Color3.fromRGB(90, 180, 255),
			action = "enterArena",
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			offset = Vector3.new(28, 0, 0),
			color = Color3.fromRGB(255, 190, 70),
			action = "openBeySelect",
		},
		StatsKiosk = {
			id = "StatsKiosk",
			label = "Rang-Monolith",
			hint = "Drücke E — Stats anzeigen",
			offset = Vector3.new(0, 0, 28),
			color = Color3.fromRGB(140, 90, 255),
			action = "showStats",
		},
		TrainingPad = {
			id = "TrainingPad",
			label = "Trainings-Plattform",
			hint = "Solo-Training — Arena-Tor nutzen",
			offset = Vector3.new(-28, 0, 0),
			color = Color3.fromRGB(80, 220, 140),
			action = "none",
		},
	},

	THEME = {
		floor = Color3.fromRGB(22, 26, 36),
		floorAccent = Color3.fromRGB(35, 42, 58),
		ring = Color3.fromRGB(70, 130, 255),
		ambient = Color3.fromRGB(120, 140, 200),
	},
}

return HubConfig
